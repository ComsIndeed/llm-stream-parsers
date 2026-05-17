"""Parse event types and structures for observability."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any


class ParseEventType(str, Enum):
    """Types of parsing events emitted by the parser."""

    PROPERTY_START = "property_start"
    PROPERTY_COMPLETE = "property_complete"
    STRING_CHUNK = "string_chunk"
    LIST_ELEMENT_START = "list_element_start"
    MAP_KEY_DISCOVERED = "map_key_discovered"
    ROOT_START = "root_start"
    ROOT_COMPLETE = "root_complete"
    ERROR = "error"
    DISPOSED = "disposed"
    YAP_FILTERED = "yap_filtered"
    THINKING_TAG_START = "thinking_tag_start"
    THINKING_TAG_END = "thinking_tag_end"


@dataclass(frozen=True)
class ParseEvent:
    """A log event emitted during parsing."""

    type: ParseEventType
    property_path: str
    message: str
    data: Any | None = None
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def __str__(self) -> str:
        path = self.property_path or "root"
        return f"[{self.type}] {path}: {self.message}"
