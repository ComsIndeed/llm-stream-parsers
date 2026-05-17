"""Property streams exposing parsed JSON values."""

from __future__ import annotations

import asyncio
from typing import Any, AsyncIterator, Awaitable, Callable, Generic, List, Optional, Protocol, TypeVar

if False:  # pragma: no cover - for typing only
    from .json_stream_parser import JsonStreamParserController


T = TypeVar("T")


class _ParserControllerProtocol(Protocol):
    def get_property_stream(self, property_path: str, stream_type: str) -> "PropertyStream[Any]": ...


class PropertyStream(Generic[T]):
    """Base class for all property streams.

    Property streams are both AsyncIterables (for streaming chunks/snapshots)
    and Awaitables (for the final value).
    """

    _COMPLETE_SENTINEL = object()

    def __init__(
        self,
        future: asyncio.Future[T],
        parser_controller: _ParserControllerProtocol,
        property_path: str,
    ) -> None:
        self._future = future
        self._parser_controller = parser_controller
        self._property_path = property_path
        self._buffer: List[T] = []
        self._subscribers: List[asyncio.Queue[object]] = []
        self._is_complete = False
        self._error: Exception | None = None
        self._on_value_callbacks: List[Callable[[T], None]] = []

    @property
    def property_path(self) -> str:
        return self._property_path

    def __await__(self):  # type: ignore[override]
        return self._future.__await__()

    def __aiter__(self) -> AsyncIterator[T]:
        return self._create_iterator(buffered=True)

    def unbuffered(self) -> AsyncIterator[T]:
        """Return an iterator that only receives new values."""
        return self._create_iterator(buffered=False)

    def on_value(self, callback: Callable[[T], None]) -> None:
        """Register a callback for when the final value is available."""
        if self._future.done() and not self._future.cancelled():
            if self._future.exception() is None:
                callback(self._future.result())
            return
        self._on_value_callbacks.append(callback)

    def _push_value(self, value: T) -> None:
        if self._is_complete:
            return
        self._buffer.append(value)
        for queue in list(self._subscribers):
            queue.put_nowait(value)

    def _complete(self) -> None:
        if self._is_complete:
            return
        self._is_complete = True
        for queue in list(self._subscribers):
            queue.put_nowait(self._COMPLETE_SENTINEL)

    def _error_out(self, error: Exception) -> None:
        if self._is_complete:
            return
        self._error = error
        self._is_complete = True
        for queue in list(self._subscribers):
            queue.put_nowait(self._COMPLETE_SENTINEL)

    async def _iterator_loop(self, queue: asyncio.Queue[object]) -> AsyncIterator[T]:
        try:
            while True:
                item = await queue.get()
                if item is self._COMPLETE_SENTINEL:
                    if self._error is not None:
                        raise self._error
                    return
                yield item  # type: ignore[misc]
        finally:
            if queue in self._subscribers:
                self._subscribers.remove(queue)

    def _create_iterator(self, buffered: bool) -> AsyncIterator[T]:
        queue: asyncio.Queue[object] = asyncio.Queue()
        if buffered:
            for value in self._buffer:
                queue.put_nowait(value)
        self._subscribers.append(queue)
        if self._is_complete:
            queue.put_nowait(self._COMPLETE_SENTINEL)
        return self._iterator_loop(queue)

    def _notify_final_value(self, value: T) -> None:
        for callback in self._on_value_callbacks:
            callback(value)
        self._on_value_callbacks.clear()


class StringPropertyStream(PropertyStream[str]):
    pass


class NumberPropertyStream(PropertyStream[float]):
    pass


class BooleanPropertyStream(PropertyStream[bool]):
    pass


class NullPropertyStream(PropertyStream[None]):
    pass


class PropertyGetterMixin:
    """Mixin to expose path-based property access methods."""

    def build_property_path(self, key: str) -> str:  # pragma: no cover - interface
        raise NotImplementedError

    @property
    def parser_controller(self) -> _ParserControllerProtocol:  # pragma: no cover - interface
        raise NotImplementedError

    def get_string_property(self, key: str) -> StringPropertyStream:
        return self.parser_controller.get_property_stream(
            self.build_property_path(key), "string"
        )  # type: ignore[return-value]

    def get_number_property(self, key: str) -> NumberPropertyStream:
        return self.parser_controller.get_property_stream(
            self.build_property_path(key), "number"
        )  # type: ignore[return-value]

    def get_boolean_property(self, key: str) -> BooleanPropertyStream:
        return self.parser_controller.get_property_stream(
            self.build_property_path(key), "boolean"
        )  # type: ignore[return-value]

    def get_null_property(self, key: str) -> NullPropertyStream:
        return self.parser_controller.get_property_stream(
            self.build_property_path(key), "null"
        )  # type: ignore[return-value]

    def get_map_property(self, key: str) -> "MapPropertyStream":
        return self.parser_controller.get_property_stream(
            self.build_property_path(key), "object"
        )  # type: ignore[return-value]

    def get_list_property(self, key: str) -> "ListPropertyStream":
        return self.parser_controller.get_property_stream(
            self.build_property_path(key), "array"
        )  # type: ignore[return-value]

    def str(self, key: str) -> StringPropertyStream:
        return self.get_string_property(key)

    def number(self, key: str) -> NumberPropertyStream:
        return self.get_number_property(key)

    def boolean(self, key: str) -> BooleanPropertyStream:
        return self.get_boolean_property(key)

    def nil(self, key: str) -> NullPropertyStream:
        return self.get_null_property(key)

    def map(self, key: str) -> "MapPropertyStream":
        return self.get_map_property(key)

    def list(self, key: str) -> "ListPropertyStream":
        return self.get_list_property(key)


class MapPropertyStream(PropertyStream[dict[str, Any]], PropertyGetterMixin):
    def __init__(
        self,
        future: asyncio.Future[dict[str, Any]],
        parser_controller: _ParserControllerProtocol,
        property_path: str,
    ) -> None:
        super().__init__(future, parser_controller, property_path)
        self._on_property_callbacks: List[
            Callable[[PropertyStream[Any], str], None]
        ] = []

    def on_property(self, callback: Callable[[PropertyStream[Any], str], None]) -> None:
        self._on_property_callbacks.append(callback)

    def _notify_property(self, stream: PropertyStream[Any], key: str) -> None:
        for callback in self._on_property_callbacks:
            callback(stream, key)

    @property
    def parser_controller(self) -> _ParserControllerProtocol:
        return self._parser_controller

    def build_property_path(self, key: str) -> str:
        if not self._property_path:
            return key
        if key.startswith("["):
            return f"{self._property_path}{key}"
        return f"{self._property_path}.{key}"


class ListPropertyStream(PropertyStream[list[Any]], PropertyGetterMixin):
    def __init__(
        self,
        future: asyncio.Future[list[Any]],
        parser_controller: _ParserControllerProtocol,
        property_path: str,
    ) -> None:
        super().__init__(future, parser_controller, property_path)
        self._on_element_callbacks: List[
            Callable[[PropertyStream[Any], int], None]
        ] = []

    def on_element(
        self, callback: Callable[[PropertyStream[Any], int], None]
    ) -> None:
        self._on_element_callbacks.append(callback)

    def _notify_element(self, stream: PropertyStream[Any], index: int) -> None:
        for callback in self._on_element_callbacks:
            callback(stream, index)

    @property
    def parser_controller(self) -> _ParserControllerProtocol:
        return self._parser_controller

    def build_property_path(self, key: str) -> str:
        if not self._property_path:
            return key
        if key.startswith("["):
            return f"{self._property_path}{key}"
        return f"{self._property_path}.{key}"
