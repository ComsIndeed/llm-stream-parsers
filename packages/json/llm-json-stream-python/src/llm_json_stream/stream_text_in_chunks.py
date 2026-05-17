"""Utility for streaming text in chunks (testing helper)."""

from __future__ import annotations

import asyncio
from typing import AsyncIterator


async def stream_text_in_chunks(
    text: str, chunk_size: int = 10, interval: int = 0
) -> AsyncIterator[str]:
    for i in range(0, len(text), chunk_size):
        chunk = text[i : i + chunk_size]
        if interval > 0 and i > 0:
            await asyncio.sleep(interval / 1000.0)
        yield chunk
