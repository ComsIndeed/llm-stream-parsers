"""Utility functions for streaming JSON data in tests."""

import asyncio
from typing import AsyncIterator


class AsyncStreamController:
    """Queue-backed async stream for manual chunk control."""

    def __init__(self) -> None:
        self._queue: asyncio.Queue[str | None] = asyncio.Queue()

    async def add(self, chunk: str) -> None:
        await self._queue.put(chunk)

    async def close(self) -> None:
        await self._queue.put(None)

    async def stream(self) -> AsyncIterator[str]:
        while True:
            item = await self._queue.get()
            if item is None:
                break
            yield item


async def stream_text_in_chunks(
    text: str,
    chunk_size: int = 10,
    interval: int = 10,
) -> AsyncIterator[str]:
    """
    Stream text as chunks with optional delay between chunks.
    
    Args:
        text: The text to stream
        chunk_size: Size of each chunk
        interval: Delay in milliseconds between chunks
    
    Yields:
        Text chunks
    """
    for i in range(0, len(text), chunk_size):
        chunk = text[i : i + chunk_size]
        yield chunk
        if i + chunk_size < len(text):
            await asyncio.sleep(interval / 1000.0)
