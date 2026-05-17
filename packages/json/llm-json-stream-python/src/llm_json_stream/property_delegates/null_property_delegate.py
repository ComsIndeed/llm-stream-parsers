"""Delegate for parsing JSON null values."""

from __future__ import annotations

from ..property_delegate import PropertyDelegate


class NullPropertyDelegate(PropertyDelegate):
    def __init__(self, property_path: str, parser_controller, on_complete=None) -> None:
        super().__init__(property_path, parser_controller, on_complete)
        self._buffer = ""

    def add_character(self, character: str) -> None:
        if character in {",", "}", "]"}:
            if not self._is_done and self._buffer == "null":
                self._is_done = True
                self._parser_controller.complete_property(self._property_path, None)
                if self._on_complete:
                    self._on_complete()
            return

        self._buffer += character
        if self._buffer == "null":
            self._is_done = True
            self._parser_controller.complete_property(self._property_path, None)
            if self._on_complete:
                self._on_complete()
