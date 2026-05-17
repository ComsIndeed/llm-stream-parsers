"""Delegate for parsing JSON string values."""

from __future__ import annotations

from ..property_delegate import PropertyDelegate


class StringPropertyDelegate(PropertyDelegate):
    def __init__(self, property_path: str, parser_controller, on_complete=None) -> None:
        super().__init__(property_path, parser_controller, on_complete)
        self._buffer = ""
        self._is_escaping = False
        self._first_character = True

    def add_character(self, character: str) -> None:
        if self._first_character and character == '"':
            self._first_character = False
            return
        if self._first_character:
            raise ValueError(
                f"StringPropertyDelegate expected opening quote, got: {character}"
            )

        if self._is_escaping:
            escape_map = {
                '"': '"',
                "\\": "\\",
                "/": "/",
                "b": "\b",
                "f": "\f",
                "n": "\n",
                "r": "\r",
                "t": "\t",
            }
            self._buffer += escape_map.get(character, f"\\{character}")
            self._is_escaping = False
            return

        if character == "\\":
            self._is_escaping = True
            return

        if character == '"':
            self._is_done = True
            if self._buffer:
                self.add_property_chunk(self._buffer)
                self._buffer = ""
            self._parser_controller.complete_property(self._property_path, "")
            if self._on_complete:
                self._on_complete()
            return

        self._buffer += character

    def on_chunk_end(self) -> None:
        if not self._buffer or self._is_done:
            return
        self.add_property_chunk(self._buffer)
        self._buffer = ""
