"""Delegate for parsing JSON number values."""

from __future__ import annotations

from ..property_delegate import PropertyDelegate


from typing import Callable, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from ..json_stream_parser import JsonStreamParserController


class NumberPropertyDelegate(PropertyDelegate):
    def __init__(
        self,
        property_path: str,
        parser_controller: JsonStreamParserController,
        on_complete: Optional[Callable[[], None]] = None,
    ) -> None:
        super().__init__(property_path, parser_controller, on_complete)
        self._buffer = ""

    def add_character(self, character: str) -> None:
        if character in {",", "}", "]", " ", "\n", "\r", "\t"}:
            if self._buffer and not self._is_done:
                self._is_done = True
                self._complete_number()
                if self._on_complete:
                    self._on_complete()
            return

        if self._is_valid_number_character(character):
            self._buffer += character

    def _is_valid_number_character(self, character: str) -> bool:
        return character in {"-", "+", ".", "e", "E"} or character.isdigit()

    def _complete_number(self) -> None:
        if not self._buffer:
            return
        try:
            if "." in self._buffer or "e" in self._buffer or "E" in self._buffer:
                number: float | int = float(self._buffer)
            else:
                number = int(self._buffer)
        except ValueError:
            number = float(self._buffer)
        self._parser_controller.complete_property(self._property_path, number)
        self._buffer = ""
