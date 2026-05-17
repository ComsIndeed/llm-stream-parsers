"""Streaming JSON parser optimized for LLM responses."""

from __future__ import annotations

import asyncio
from typing import Any, AsyncIterable, Callable, Dict, Optional, Tuple

from .parse_event import ParseEvent, ParseEventType
from .property_delegate import PropertyDelegate
from .property_delegates import ArrayPropertyDelegate, ObjectPropertyDelegate
from .property_stream import (
    PropertyGetterMixin,
    PropertyStream,
    StringPropertyStream,
    NumberPropertyStream,
    BooleanPropertyStream,
    NullPropertyStream,
    MapPropertyStream,
    ListPropertyStream,
)
from .property_stream_controller import (
    PropertyStreamController,
    StringPropertyStreamController,
    NumberPropertyStreamController,
    BooleanPropertyStreamController,
    NullPropertyStreamController,
    MapPropertyStreamController,
    ListPropertyStreamController,
)


class JsonStreamParserController:
    def __init__(
        self,
        add_property_chunk: Callable[[str, Any], None],
        get_property_stream_controller: Callable[
            [str], Optional[PropertyStreamController[Any]]
        ],
        get_property_stream: Callable[[str, str], PropertyStream[Any]],
        complete_property: Callable[[str, Any], None],
        emit_log: Callable[[ParseEvent], None],
    ) -> None:
        self._add_property_chunk = add_property_chunk
        self._get_property_stream_controller = get_property_stream_controller
        self._get_property_stream = get_property_stream
        self._complete_property = complete_property
        self._emit_log = emit_log

    def add_property_chunk(self, property_path: str, chunk: Any) -> None:
        self._add_property_chunk(property_path, chunk)

    def get_property_stream_controller(
        self, property_path: str
    ) -> Optional[PropertyStreamController[Any]]:
        return self._get_property_stream_controller(property_path)

    def get_property_stream(self, property_path: str, stream_type: str) -> PropertyStream[Any]:
        return self._get_property_stream(property_path, stream_type)

    def complete_property(self, property_path: str, value: Any) -> None:
        self._complete_property(property_path, value)

    def emit_log(self, event: ParseEvent) -> None:
        self._emit_log(event)


class JsonStreamParser(PropertyGetterMixin):
    """Main streaming JSON parser."""

    def __init__(
        self,
        stream: AsyncIterable[str],
        *,
        close_on_root_complete: bool = True,
        skip_thoughts: bool = False,
        thinking_tags: Tuple[str, str] = ("<think>", "</think>"),
        on_log: Optional[Callable[[ParseEvent], None]] = None,
    ) -> None:
        self.close_on_root_complete = close_on_root_complete
        self.skip_thoughts = skip_thoughts
        self.thinking_tags = thinking_tags
        self._on_log = on_log
        self._stream = stream
        self._property_controllers: Dict[str, PropertyStreamController[Any]] = {}
        self._root_delegate: Optional[PropertyDelegate] = None
        self._disposed = False
        self._abort_stream = False

        self._inside_thinking_tags = False
        self._tag_buffer = ""
        self._potential_tag_buffer = ""
        self._saw_potential_thinking_tags = False

        self._controller = JsonStreamParserController(
            self._add_property_chunk,
            self._get_controller_for_path,
            self._get_property_stream,
            self._complete_property,
            self._emit_log,
        )

        self._consume_task: asyncio.Task[None] = asyncio.create_task(
            self._consume_stream()
        )

    @property
    def parser_controller(self) -> JsonStreamParserController:
        return self._controller

    def build_property_path(self, key: str) -> str:
        return key

    async def _consume_stream(self) -> None:
        try:
            async for chunk in self._stream:
                if self._disposed or self._abort_stream:
                    break
                self._parse_chunk(chunk)

                if (
                    self.close_on_root_complete
                    and self._root_delegate
                    and self._root_delegate.done
                ):
                    self._abort_stream = True
                    break

            self._handle_stream_end()
        except Exception as exc:  # pragma: no cover - defensive
            for controller in self._property_controllers.values():
                controller.complete_error(
                    exc if isinstance(exc, Exception) else Exception(str(exc))
                )

    def get_string_property(self, property_path: str) -> StringPropertyStream:
        self._ensure_not_disposed()
        existing = self._property_controllers.get(property_path)
        if existing and not isinstance(existing, StringPropertyStreamController):
            raise ValueError(
                f"Property at path {property_path} is not a StringPropertyStream"
            )
        controller = self._property_controllers.setdefault(
            property_path,
            StringPropertyStreamController(self._controller, property_path),
        )
        return controller.property_stream  # type: ignore[return-value]

    def get_number_property(self, property_path: str) -> NumberPropertyStream:
        self._ensure_not_disposed()
        existing = self._property_controllers.get(property_path)
        if existing and not isinstance(existing, NumberPropertyStreamController):
            raise ValueError(
                f"Property at path {property_path} is not a NumberPropertyStream"
            )
        controller = self._property_controllers.setdefault(
            property_path,
            NumberPropertyStreamController(self._controller, property_path),
        )
        return controller.property_stream  # type: ignore[return-value]

    def get_boolean_property(self, property_path: str) -> BooleanPropertyStream:
        self._ensure_not_disposed()
        existing = self._property_controllers.get(property_path)
        if existing and not isinstance(existing, BooleanPropertyStreamController):
            raise ValueError(
                f"Property at path {property_path} is not a BooleanPropertyStream"
            )
        controller = self._property_controllers.setdefault(
            property_path,
            BooleanPropertyStreamController(self._controller, property_path),
        )
        return controller.property_stream  # type: ignore[return-value]

    def get_null_property(self, property_path: str) -> NullPropertyStream:
        self._ensure_not_disposed()
        existing = self._property_controllers.get(property_path)
        if existing and not isinstance(existing, NullPropertyStreamController):
            raise ValueError(
                f"Property at path {property_path} is not a NullPropertyStream"
            )
        controller = self._property_controllers.setdefault(
            property_path,
            NullPropertyStreamController(self._controller, property_path),
        )
        return controller.property_stream  # type: ignore[return-value]

    def get_map_property(self, property_path: str) -> MapPropertyStream:
        self._ensure_not_disposed()
        existing = self._property_controllers.get(property_path)
        if existing and not isinstance(existing, MapPropertyStreamController):
            raise ValueError(
                f"Property at path {property_path} is not a MapPropertyStream"
            )
        controller = self._property_controllers.setdefault(
            property_path,
            MapPropertyStreamController(self._controller, property_path),
        )
        return controller.property_stream  # type: ignore[return-value]

    def get_list_property(self, property_path: str) -> ListPropertyStream:
        self._ensure_not_disposed()
        existing = self._property_controllers.get(property_path)
        if existing and not isinstance(existing, ListPropertyStreamController):
            raise ValueError(
                f"Property at path {property_path} is not a ListPropertyStream"
            )
        controller = self._property_controllers.setdefault(
            property_path,
            ListPropertyStreamController(self._controller, property_path),
        )
        return controller.property_stream  # type: ignore[return-value]

    async def dispose(self) -> None:
        if self._disposed:
            return
        self._disposed = True
        self._abort_stream = True
        if not self._consume_task.done():
            self._consume_task.cancel()
            try:
                await self._consume_task
            except asyncio.CancelledError:
                pass
        for controller in self._property_controllers.values():
            if not controller.is_closed:
                controller.complete_error(ValueError("Parser disposed"))
        self._emit_log(
            ParseEvent(
                type=ParseEventType.DISPOSED,
                property_path="",
                message="Parser disposed",
            )
        )

    def _ensure_not_disposed(self) -> None:
        if self._disposed:
            raise RuntimeError("Parser has been disposed")

    def _add_property_chunk(self, property_path: str, chunk: Any) -> None:
        controller = self._property_controllers.get(property_path)
        if not controller:
            return

        if isinstance(controller, StringPropertyStreamController):
            controller.add_chunk(str(chunk))
            self._emit_log(
                ParseEvent(
                    type=ParseEventType.STRING_CHUNK,
                    property_path=property_path,
                    message="String chunk received",
                    data=chunk,
                )
            )
        elif isinstance(controller, MapPropertyStreamController):
            controller.add_snapshot(chunk)
        elif isinstance(controller, ListPropertyStreamController):
            controller.add_snapshot(chunk)

    def _get_controller_for_path(
        self, property_path: str
    ) -> Optional[PropertyStreamController[Any]]:
        return self._property_controllers.get(property_path)

    def _get_property_stream(self, property_path: str, stream_type: str) -> PropertyStream[Any]:
        existing = self._property_controllers.get(property_path)
        if existing:
            if self._is_compatible(existing, stream_type):
                return existing.property_stream
            requested = existing.__class__.__name__.replace("PropertyStreamController", "")
            error_message = (
                f"Type mismatch at path \"{property_path}\": requested {requested} "
                f"but found {stream_type} in JSON"
            )
            if self._saw_potential_thinking_tags and not self.skip_thoughts:
                error_message += (
                    "\n\nHint: The input may contain thinking tags. "
                    "Try setting skip_thoughts=True."
                )
            error = ValueError(error_message)
            existing.complete_error(error)
            self._emit_log(
                ParseEvent(
                    type=ParseEventType.ERROR,
                    property_path=property_path,
                    message="Type mismatch",
                    data=error,
                )
            )
            raise error

        if stream_type == "string":
            return self.get_string_property(property_path)
        if stream_type == "number":
            return self.get_number_property(property_path)
        if stream_type == "boolean":
            return self.get_boolean_property(property_path)
        if stream_type == "null":
            return self.get_null_property(property_path)
        if stream_type == "object":
            return self.get_map_property(property_path)
        if stream_type == "array":
            return self.get_list_property(property_path)
        raise ValueError(f"Unknown stream type: {stream_type}")

    def _complete_property(self, property_path: str, value: Any) -> None:
        controller = self._property_controllers.get(property_path)
        if controller:
            controller.complete(value)
            self._emit_log(
                ParseEvent(
                    type=ParseEventType.PROPERTY_COMPLETE,
                    property_path=property_path,
                    message="Property completed",
                )
            )
        if property_path == "":
            self._emit_log(
                ParseEvent(
                    type=ParseEventType.ROOT_COMPLETE,
                    property_path="",
                    message="Root JSON complete",
                )
            )

    def _is_compatible(self, controller: PropertyStreamController[Any], stream_type: str) -> bool:
        return (
            (stream_type == "string" and isinstance(controller, StringPropertyStreamController))
            or (stream_type == "number" and isinstance(controller, NumberPropertyStreamController))
            or (stream_type == "boolean" and isinstance(controller, BooleanPropertyStreamController))
            or (stream_type == "null" and isinstance(controller, NullPropertyStreamController))
            or (stream_type == "object" and isinstance(controller, MapPropertyStreamController))
            or (stream_type == "array" and isinstance(controller, ListPropertyStreamController))
        )

    def _parse_chunk(self, chunk: str) -> None:
        if self._disposed:
            return
        if self.close_on_root_complete and self._root_delegate and self._root_delegate.done:
            self._emit_log(
                ParseEvent(
                    type=ParseEventType.YAP_FILTERED,
                    property_path="",
                    message="Yap filter triggered - ignoring text after root JSON",
                )
            )
            self._abort_stream = True
            return

        try:
            for character in chunk:
                if (
                    self.close_on_root_complete
                    and self._root_delegate
                    and self._root_delegate.done
                ):
                    self._emit_log(
                        ParseEvent(
                            type=ParseEventType.YAP_FILTERED,
                            property_path="",
                            message="Yap filter triggered - ignoring text after root JSON",
                        )
                    )
                    self._abort_stream = True
                    return

                if self.skip_thoughts:
                    processed = self._process_character_for_thinking_tags(character)
                    if processed is None:
                        continue
                    character = processed
                else:
                    self._detect_potential_thinking_tags(character)

                if self._root_delegate:
                    self._root_delegate.add_character(character)
                    continue

                if character.isspace():
                    continue

                if character == "{":
                    self._emit_log(
                        ParseEvent(
                            type=ParseEventType.ROOT_START,
                            property_path="",
                            message="Started parsing root object",
                        )
                    )
                    self._root_delegate = ObjectPropertyDelegate(
                        "", self._controller
                    )
                    self._root_delegate.add_character(character)
                    continue

                if character == "[":
                    self._emit_log(
                        ParseEvent(
                            type=ParseEventType.ROOT_START,
                            property_path="",
                            message="Started parsing root array",
                        )
                    )
                    self._root_delegate = ArrayPropertyDelegate(
                        "", self._controller
                    )
                    self._root_delegate.add_character(character)
                    continue

            if self._root_delegate:
                self._root_delegate.on_chunk_end()

            if self.close_on_root_complete and self._root_delegate and self._root_delegate.done:
                self._emit_log(
                    ParseEvent(
                        type=ParseEventType.YAP_FILTERED,
                        property_path="",
                        message="Yap filter triggered - root JSON complete",
                    )
                )
                self._abort_stream = True
        except Exception as exc:  # pragma: no cover - defensive
            self._emit_log(
                ParseEvent(
                    type=ParseEventType.ERROR,
                    property_path="",
                    message=f"Parsing error: {exc}",
                    data=exc,
                )
            )

    def _handle_stream_end(self) -> None:
        for controller in self._property_controllers.values():
            if not controller.is_closed:
                controller.complete_error(
                    RuntimeError("Stream ended before property completed")
                )

    def _emit_log(self, event: ParseEvent) -> None:
        if self._on_log:
            self._on_log(event)

    def _process_character_for_thinking_tags(self, character: str) -> Optional[str]:
        start_tag, end_tag = self.thinking_tags

        if self._inside_thinking_tags:
            self._tag_buffer += character
            if self._tag_buffer.endswith(end_tag):
                self._inside_thinking_tags = False
                self._tag_buffer = ""
                self._emit_log(
                    ParseEvent(
                        type=ParseEventType.THINKING_TAG_END,
                        property_path="",
                        message="Exited thinking tags",
                    )
                )
                return None

            if len(self._tag_buffer) > len(end_tag) * 2:
                self._tag_buffer = self._tag_buffer[-len(end_tag) :]
            return None

        self._tag_buffer += character
        if self._tag_buffer.endswith(start_tag):
            self._inside_thinking_tags = True
            self._tag_buffer = ""
            self._emit_log(
                ParseEvent(
                    type=ParseEventType.THINKING_TAG_START,
                    property_path="",
                    message="Entered thinking tags",
                )
            )
            return None

        if len(self._tag_buffer) > len(start_tag):
            self._tag_buffer = self._tag_buffer[-len(start_tag) :]
            return character

        if start_tag.startswith(self._tag_buffer):
            return None

        self._tag_buffer = ""
        return character

    def _detect_potential_thinking_tags(self, character: str) -> None:
        if self._root_delegate:
            return

        start_tag, _ = self.thinking_tags
        self._potential_tag_buffer += character
        if self._potential_tag_buffer.endswith(start_tag):
            self._saw_potential_thinking_tags = True
            self._potential_tag_buffer = ""
            return

        if len(self._potential_tag_buffer) > len(start_tag):
            self._potential_tag_buffer = self._potential_tag_buffer[-len(start_tag) :]
