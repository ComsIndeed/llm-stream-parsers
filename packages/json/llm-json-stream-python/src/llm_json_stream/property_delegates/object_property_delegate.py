"""Delegate for parsing JSON object values."""

from __future__ import annotations

from enum import Enum
from typing import Any

from ..property_delegate import PropertyDelegate
from ..parse_event import ParseEvent, ParseEventType
from ..property_stream_controller import MapPropertyStreamController
from .boolean_property_delegate import BooleanPropertyDelegate
from .null_property_delegate import NullPropertyDelegate
from .number_property_delegate import NumberPropertyDelegate
from .string_property_delegate import StringPropertyDelegate


class _ObjectParserState(Enum):
    WAITING_FOR_KEY = "waiting_for_key"
    READING_KEY = "reading_key"
    WAITING_FOR_VALUE = "waiting_for_value"
    READING_VALUE = "reading_value"
    WAITING_FOR_COMMA_OR_END = "waiting_for_comma_or_end"


from typing import Callable, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from ..json_stream_parser import JsonStreamParserController


class ObjectPropertyDelegate(PropertyDelegate):
    def __init__(
        self,
        property_path: str,
        parser_controller: JsonStreamParserController,
        on_complete: Optional[Callable[[], None]] = None,
    ) -> None:
        super().__init__(property_path, parser_controller, on_complete)
        self._state = _ObjectParserState.WAITING_FOR_KEY
        self._first_character = True
        self._key_buffer = ""
        self._active_child_delegate: PropertyDelegate | None = None
        self._active_child_key: str | None = None
        self._current_object: dict[str, Any] = {}

    def on_chunk_end(self) -> None:
        if self._active_child_delegate and not self._active_child_delegate.done:
            self._active_child_delegate.on_chunk_end()

        controller = self._parser_controller.get_property_stream_controller(
            self._property_path
        )
        if controller:
            self._parser_controller.add_property_chunk(
                property_path=self._property_path,
                chunk=dict(self._current_object),
            )

    def add_character(self, character: str) -> None:
        if self._state == _ObjectParserState.READING_KEY:
            if character == '"':
                self._state = _ObjectParserState.WAITING_FOR_VALUE
                return
            self._key_buffer += character
            return

        if self._state == _ObjectParserState.READING_VALUE:
            child_delegate = self._active_child_delegate
            if child_delegate:
                child_delegate.add_character(character)

            if child_delegate and child_delegate.done:
                completed_key = self._active_child_key
                if completed_key:
                    child_path = self.new_path(completed_key)
                    child_controller = (
                        self._parser_controller.get_property_stream_controller(
                            child_path
                        )
                    )
                    if child_controller and child_controller.has_final_value:
                        self._current_object[completed_key] = child_controller.final_value

                self._state = _ObjectParserState.WAITING_FOR_COMMA_OR_END
                self._active_child_delegate = None
                self._active_child_key = None

                from .array_property_delegate import ArrayPropertyDelegate

                if isinstance(child_delegate, (ArrayPropertyDelegate, ObjectPropertyDelegate)):
                    return
            else:
                return

        if self._state == _ObjectParserState.WAITING_FOR_VALUE:
            if character in {" ", ":"}:
                return

            current_key = self._key_buffer
            self._active_child_key = current_key
            child_path = self.new_path(current_key)

            stream_type = self._determine_stream_type(character)
            child_stream = self._parser_controller.get_property_stream(
                child_path, stream_type
            )
            self._current_object[current_key] = None

            self._parser_controller.emit_log(
                ParseEvent(
                    type=ParseEventType.MAP_KEY_DISCOVERED,
                    property_path=self._property_path,
                    message=f"Discovered key: {current_key}",
                    data=current_key,
                )
            )
            self._parser_controller.emit_log(
                ParseEvent(
                    type=ParseEventType.PROPERTY_START,
                    property_path=child_path,
                    message="Property parsing started",
                )
            )

            object_controller = self._parser_controller.get_property_stream_controller(
                self._property_path
            )
            if isinstance(object_controller, MapPropertyStreamController):
                object_controller.notify_property(child_stream, current_key)

            child_delegate = self._create_delegate(character, child_path)
            self._active_child_delegate = child_delegate
            child_delegate.add_character(character)
            self._state = _ObjectParserState.READING_VALUE
            return

        if self._first_character and character == "{":
            self._first_character = False
            return

        if self._state == _ObjectParserState.WAITING_FOR_COMMA_OR_END:
            if character.isspace():
                return
            if character == ",":
                self._state = _ObjectParserState.WAITING_FOR_KEY
                self._key_buffer = ""
                return
            if character == "}":
                self._complete_object()
                return

        if self._state == _ObjectParserState.WAITING_FOR_KEY:
            if character.isspace():
                return
            if character == '"':
                self._state = _ObjectParserState.READING_KEY
                return
            if character == "}":
                self._complete_object()
                return

    def _determine_stream_type(self, character: str) -> str:
        if character == '"':
            return "string"
        if character == "{":
            return "object"
        if character == "[":
            return "array"
        if character in {"t", "f"}:
            return "boolean"
        if character == "n":
            return "null"
        return "number"

    def _create_delegate(self, character: str, child_path: str) -> PropertyDelegate:
        if character == '"':
            return StringPropertyDelegate(child_path, self._parser_controller)
        if character == "{":
            return ObjectPropertyDelegate(child_path, self._parser_controller)
        if character == "[":
            from .array_property_delegate import ArrayPropertyDelegate

            return ArrayPropertyDelegate(child_path, self._parser_controller)
        if character in {"t", "f"}:
            return BooleanPropertyDelegate(child_path, self._parser_controller)
        if character == "n":
            return NullPropertyDelegate(child_path, self._parser_controller)
        return NumberPropertyDelegate(child_path, self._parser_controller)

    def _complete_object(self) -> None:
        self._is_done = True
        self._parser_controller.complete_property(
            self._property_path, dict(self._current_object)
        )
        if self._on_complete:
            self._on_complete()
