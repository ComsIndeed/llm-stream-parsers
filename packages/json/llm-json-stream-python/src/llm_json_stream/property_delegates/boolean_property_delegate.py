"""Delegate for parsing JSON boolean values."""

from __future__ import annotations

from ..property_delegate import PropertyDelegate


class BooleanPropertyDelegate(PropertyDelegate):
    def __init__(self, property_path: str, parser_controller, on_complete=None) -> None:
        super().__init__(property_path, parser_controller, on_complete)
        self._buffer = ""
        self._expected_value: bool | None = None

    def add_character(self, character: str) -> None:
        if character in {",", "}", "]"}:
            if not self._is_done and self._expected_value is not None:
                self._is_done = True
                self._parser_controller.complete_property(
                    self._property_path, self._expected_value
                )
                if self._on_complete:
                    self._on_complete()
            return

        if not self._buffer:
            if character == "t":
                self._expected_value = True
                self._buffer = "t"
            elif character == "f":
                self._expected_value = False
                self._buffer = "f"
            return

        self._buffer += character
        if self._expected_value is True and self._buffer == "true":
            self._is_done = True
            self._parser_controller.complete_property(self._property_path, True)
            if self._on_complete:
                self._on_complete()
        elif self._expected_value is False and self._buffer == "false":
            self._is_done = True
            self._parser_controller.complete_property(self._property_path, False)
            if self._on_complete:
                self._on_complete()
