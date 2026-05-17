"""Property stream controllers for managing stream state."""

from __future__ import annotations

import asyncio
from typing import Any, Generic, List, Optional, TypeVar, TYPE_CHECKING

from .property_stream import (
    BooleanPropertyStream,
    ListPropertyStream,
    MapPropertyStream,
    NullPropertyStream,
    NumberPropertyStream,
    PropertyStream,
    StringPropertyStream,
)

if TYPE_CHECKING:  # pragma: no cover - typing only
    from .json_stream_parser import JsonStreamParserController


T = TypeVar("T")


class PropertyStreamController(Generic[T]):
    property_stream: PropertyStream[T]

    def __init__(self, parser_controller: "JsonStreamParserController", property_path: str) -> None:
        self._is_closed = False
        self._final_value: Optional[T] = None
        self._has_final_value = False
        self._parser_controller = parser_controller
        self._property_path = property_path
        loop = asyncio.get_event_loop()
        self._future: asyncio.Future[T] = loop.create_future()

    @property
    def is_closed(self) -> bool:
        return self._is_closed

    @property
    def has_final_value(self) -> bool:
        return self._has_final_value

    @property
    def final_value(self) -> Optional[T]:
        return self._final_value

    def complete(self, value: T) -> None:
        if self._is_closed:
            return
        self._final_value = value
        self._has_final_value = True
        self.property_stream._complete()
        if not self._future.done():
            self._future.set_result(value)
        self.property_stream._notify_final_value(value)
        self._is_closed = True

    def complete_error(self, error: Exception) -> None:
        if self._is_closed:
            return
        self.property_stream._error_out(error)
        if not self._future.done():
            self._future.set_exception(error)
        self._is_closed = True


class StringPropertyStreamController(PropertyStreamController[str]):
    def __init__(self, parser_controller: "JsonStreamParserController", property_path: str) -> None:
        super().__init__(parser_controller, property_path)
        self._buffer = ""
        self.property_stream = StringPropertyStream(
            self._future,
            parser_controller,
            property_path,
        )

    def add_chunk(self, chunk: str) -> None:
        if self._is_closed:
            return
        self._buffer += chunk
        self.property_stream._push_value(chunk)

    def complete(self, value: str | None = None) -> None:  # type: ignore[override]
        if self._is_closed:
            return
        self._final_value = self._buffer
        self._has_final_value = True
        self.property_stream._complete()
        if not self._future.done():
            self._future.set_result(self._buffer)
        self.property_stream._notify_final_value(self._buffer)
        self._is_closed = True


class NumberPropertyStreamController(PropertyStreamController[float]):
    def __init__(self, parser_controller: "JsonStreamParserController", property_path: str) -> None:
        super().__init__(parser_controller, property_path)
        self.property_stream = NumberPropertyStream(
            self._future,
            parser_controller,
            property_path,
        )

    def complete(self, value: float) -> None:  # type: ignore[override]
        if self._is_closed:
            return
        self._final_value = value
        self._has_final_value = True
        self.property_stream._push_value(value)
        self.property_stream._complete()
        if not self._future.done():
            self._future.set_result(value)
        self.property_stream._notify_final_value(value)
        self._is_closed = True


class BooleanPropertyStreamController(PropertyStreamController[bool]):
    def __init__(self, parser_controller: "JsonStreamParserController", property_path: str) -> None:
        super().__init__(parser_controller, property_path)
        self.property_stream = BooleanPropertyStream(
            self._future,
            parser_controller,
            property_path,
        )

    def complete(self, value: bool) -> None:  # type: ignore[override]
        if self._is_closed:
            return
        self._final_value = value
        self._has_final_value = True
        self.property_stream._push_value(value)
        self.property_stream._complete()
        if not self._future.done():
            self._future.set_result(value)
        self.property_stream._notify_final_value(value)
        self._is_closed = True


class NullPropertyStreamController(PropertyStreamController[None]):
    def __init__(self, parser_controller: "JsonStreamParserController", property_path: str) -> None:
        super().__init__(parser_controller, property_path)
        self.property_stream = NullPropertyStream(
            self._future,
            parser_controller,
            property_path,
        )

    def complete(self, value: None) -> None:  # type: ignore[override]
        if self._is_closed:
            return
        self._final_value = value
        self._has_final_value = True
        self.property_stream._push_value(value)
        self.property_stream._complete()
        if not self._future.done():
            self._future.set_result(value)
        self.property_stream._notify_final_value(value)
        self._is_closed = True


class MapPropertyStreamController(PropertyStreamController[dict[str, Any]]):
    def __init__(self, parser_controller: "JsonStreamParserController", property_path: str) -> None:
        super().__init__(parser_controller, property_path)
        self._current_value: dict[str, Any] = {}
        self.property_stream = MapPropertyStream(
            self._future,
            parser_controller,
            property_path,
        )

    def notify_property(self, stream: PropertyStream[Any], key: str) -> None:
        self.property_stream._notify_property(stream, key)

    def add_snapshot(self, snapshot: dict[str, Any]) -> None:
        if self._is_closed:
            return
        self._current_value = snapshot
        self.property_stream._push_value(dict(snapshot))

    def add_property(self, key: str, value: Any) -> None:
        if self._is_closed:
            return
        self._current_value[key] = value
        self.property_stream._push_value(dict(self._current_value))

    def complete(self, value: Optional[dict[str, Any]] = None) -> None:  # type: ignore[override]
        if self._is_closed:
            return
        final_value = value if value is not None else dict(self._current_value)
        self._final_value = final_value
        self._has_final_value = True
        self.property_stream._push_value(dict(final_value))
        self.property_stream._complete()
        if not self._future.done():
            self._future.set_result(final_value)
        self.property_stream._notify_final_value(final_value)
        self._is_closed = True


class ListPropertyStreamController(PropertyStreamController[list[Any]]):
    def __init__(self, parser_controller: "JsonStreamParserController", property_path: str) -> None:
        super().__init__(parser_controller, property_path)
        self._current_value: list[Any] = []
        self.property_stream = ListPropertyStream(
            self._future,
            parser_controller,
            property_path,
        )

    def notify_element(self, stream: PropertyStream[Any], index: int) -> None:
        self.property_stream._notify_element(stream, index)

    def add_snapshot(self, snapshot: list[Any]) -> None:
        if self._is_closed:
            return
        self._current_value = snapshot
        self.property_stream._push_value(list(snapshot))

    def add_element(self, value: Any) -> None:
        if self._is_closed:
            return
        self._current_value.append(value)
        self.property_stream._push_value(list(self._current_value))

    def complete(self, value: Optional[list[Any]] = None) -> None:  # type: ignore[override]
        if self._is_closed:
            return
        final_value = value if value is not None else list(self._current_value)
        self._final_value = final_value
        self._has_final_value = True
        self.property_stream._push_value(list(final_value))
        self.property_stream._complete()
        if not self._future.done():
            self._future.set_result(final_value)
        self.property_stream._notify_final_value(final_value)
        self._is_closed = True
