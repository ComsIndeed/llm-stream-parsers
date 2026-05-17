"""Base property delegate for JSON parsing."""

from __future__ import annotations

from typing import Any, Callable, Optional, TYPE_CHECKING

if TYPE_CHECKING:  # pragma: no cover
    from .json_stream_parser import JsonStreamParserController


class PropertyDelegate:
    def __init__(
        self,
        property_path: str,
        parser_controller: "JsonStreamParserController",
        on_complete: Optional[Callable[[], None]] = None,
    ) -> None:
        self._property_path = property_path
        self._parser_controller = parser_controller
        self._on_complete = on_complete
        self._is_done = False

    @property
    def done(self) -> bool:
        return self._is_done

    def new_path(self, path: str) -> str:
        return path if not self._property_path else f"{self._property_path}.{path}"

    def add_property_chunk(self, value: Any, inner_path: Optional[str] = None) -> None:
        self._parser_controller.add_property_chunk(
            property_path=inner_path or self._property_path,
            chunk=value,
        )

    def add_character(self, character: str) -> None:  # pragma: no cover - interface
        raise NotImplementedError

    def on_chunk_end(self) -> None:
        return
