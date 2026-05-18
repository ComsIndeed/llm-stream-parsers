"""Delegate for parsing JSON array values."""

from __future__ import annotations

from enum import Enum
from typing import Any, Callable, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from ..json_stream_parser import JsonStreamParserController

from ..property_delegate import PropertyDelegate
from ..parse_event import ParseEvent, ParseEventType
from ..property_stream_controller import ListPropertyStreamController
from .boolean_property_delegate import BooleanPropertyDelegate
from .null_property_delegate import NullPropertyDelegate
from .number_property_delegate import NumberPropertyDelegate
from .string_property_delegate import StringPropertyDelegate


class _ArrayParserState(Enum):
    WAITING_FOR_VALUE = "waiting_for_value"
    READING_VALUE = "reading_value"
    WAITING_FOR_COMMA_OR_END = "waiting_for_comma_or_end"


class ArrayPropertyDelegate(PropertyDelegate):
    VALUE_FIRST_CHARACTERS = set(
        [
            '"',
            "{",
            "[",
            "t",
            "f",
            "n",
            "-",
            "0",
            "1",
            "2",
            "3",
            "4",
            "5",
            "6",
            "7",
            "8",
            "9",
        ]
    )

    def __init__(
        self,
        property_path: str,
        parser_controller: JsonStreamParserController,
        on_complete: Optional[Callable[[], None]] = None,
    ) -> None:
        super().__init__(property_path, parser_controller, on_complete)
        self._state = _ArrayParserState.WAITING_FOR_VALUE
        self._index = 0
        self._is_first_character = True
        self._active_child_delegate: PropertyDelegate | None = None
        self._current_array: list[Any] = []
        self._element_paths: list[str] = []

    @property
    def _current_element_path(self) -> str:
        return f"{self._property_path}[{self._index}]"

    def on_chunk_end(self) -> None:
        if self._active_child_delegate and not self._active_child_delegate.done:
            self._active_child_delegate.on_chunk_end()

        controller = self._parser_controller.get_property_stream_controller(
            self._property_path
        )
        if controller:
            self._parser_controller.add_property_chunk(
                property_path=self._property_path,
                chunk=list(self._current_array),
            )

    def add_character(self, character: str) -> None:
        if self._is_first_character and character == "[":
            self._is_first_character = False
            self._state = _ArrayParserState.WAITING_FOR_VALUE
            return

        if self._state != _ArrayParserState.READING_VALUE and character.isspace():
            return

        if self._state == _ArrayParserState.READING_VALUE:
            child_delegate = self._active_child_delegate
            if child_delegate:
                child_delegate.add_character(character)

            if child_delegate and child_delegate.done:
                completed_path = self._element_paths[self._index]
                child_controller = self._parser_controller.get_property_stream_controller(
                    completed_path
                )
                if child_controller and child_controller.has_final_value:
                    self._current_array[self._index] = child_controller.final_value

                self._active_child_delegate = None
                self._index += 1
                self._state = _ArrayParserState.WAITING_FOR_COMMA_OR_END

                from .object_property_delegate import ObjectPropertyDelegate

                if isinstance(child_delegate, (ArrayPropertyDelegate, ObjectPropertyDelegate)):
                    return
            else:
                return

        if self._state == _ArrayParserState.WAITING_FOR_VALUE:
            if character in self.VALUE_FIRST_CHARACTERS:
                stream_type = self._determine_stream_type(character)
                element_path = self._current_element_path
                self._element_paths.append(element_path)
                element_stream = self._parser_controller.get_property_stream(
                    element_path, stream_type
                )
                self._current_array.append(None)

                self._parser_controller.emit_log(
                    ParseEvent(
                        type=ParseEventType.LIST_ELEMENT_START,
                        property_path=self._property_path,
                        message=f"Element {self._index} started",
                        data=self._index,
                    )
                )
                self._parser_controller.emit_log(
                    ParseEvent(
                        type=ParseEventType.PROPERTY_START,
                        property_path=element_path,
                        message="Property parsing started",
                    )
                )

                array_controller = self._parser_controller.get_property_stream_controller(
                    self._property_path
                )
                if isinstance(array_controller, ListPropertyStreamController):
                    array_controller.notify_element(element_stream, self._index)

                delegate = self._create_delegate(character, element_path)
                self._active_child_delegate = delegate
                delegate.add_character(character)
                self._state = _ArrayParserState.READING_VALUE
                return

            if character == "]":
                self._complete_array()
                return

        if self._state == _ArrayParserState.WAITING_FOR_COMMA_OR_END:
            if character == ",":
                self._state = _ArrayParserState.WAITING_FOR_VALUE
                return
            if character == "]":
                self._complete_array()
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
            from .object_property_delegate import ObjectPropertyDelegate

            return ObjectPropertyDelegate(child_path, self._parser_controller)
        if character == "[":
            return ArrayPropertyDelegate(child_path, self._parser_controller)
        if character in {"t", "f"}:
            return BooleanPropertyDelegate(child_path, self._parser_controller)
        if character == "n":
            return NullPropertyDelegate(child_path, self._parser_controller)
        return NumberPropertyDelegate(child_path, self._parser_controller)

    def _complete_array(self) -> None:
        self._is_done = True
        self._parser_controller.complete_property(
            self._property_path, list(self._current_array)
        )
        if self._on_complete:
            self._on_complete()
