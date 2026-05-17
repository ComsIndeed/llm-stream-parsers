"""Utility functions for streaming JSON data in tests."""

import asyncio
from typing import AsyncIterator


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
