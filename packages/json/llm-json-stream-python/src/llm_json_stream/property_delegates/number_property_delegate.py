"""Delegate for parsing JSON number values."""

from __future__ import annotations

from ..property_delegate import PropertyDelegate


class NumberPropertyDelegate(PropertyDelegate):
    def __init__(self, property_path: str, parser_controller, on_complete=None) -> None:
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
        number = float(self._buffer)
        self._parser_controller.complete_property(self._property_path, number)
        self._buffer = ""
