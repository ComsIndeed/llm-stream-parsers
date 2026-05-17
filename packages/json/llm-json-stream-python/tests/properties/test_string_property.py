"""String property tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestStringProperty:
    """String property test suite."""

    @pytest.mark.asyncio
    async def test_simple_string(self):
        """Test simple string property."""
        json_text = '{"name":"Alice"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        chunks = [chunk async for chunk in name_stream]
        final_value = await name_stream

        assert "".join(chunks) == "Alice"
        assert final_value == "Alice"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_empty_string(self):
        """Test empty string property."""
        json_text = '{"empty":""}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        empty_stream = parser.get_string_property("empty")
        chunks = [chunk async for chunk in empty_stream]
        final_value = await empty_stream

        assert "".join(chunks) == ""
        assert final_value == ""
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_string_with_escaped_characters(self):
        """Test string with escaped characters."""
        json_text = r'{"text":"Hello \"World\"\nNew line\tTab"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=10)
        parser = JsonStreamParser(stream)

        text_stream = parser.get_string_property("text")
        chunks = [chunk async for chunk in text_stream]
        final_value = await text_stream

        assert "".join(chunks) == 'Hello "World"\nNew line\tTab'
        assert final_value == 'Hello "World"\nNew line\tTab'
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_string_with_unicode(self):
        """Test string with unicode characters."""
        json_text = '{"emoji":"👋🌍"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        emoji_stream = parser.get_string_property("emoji")
        chunks = [chunk async for chunk in emoji_stream]
        final_value = await emoji_stream

        assert "".join(chunks) == "👋🌍"
        assert final_value == "👋🌍"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_string_split_across_chunks(self):
        """Test string split across chunks."""
        json_text = '{"user":{"name":"Bob"}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("user.name")
        chunks = [chunk async for chunk in name_stream]
        final_value = await name_stream

        assert "".join(chunks) == "Bob"
        assert final_value == "Bob"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_very_long_string(self):
        """Test very long string."""
        long_value = "a" * 1000
        json_text = f'{{"long":"{long_value}"}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=25, interval=1)
        parser = JsonStreamParser(stream)

        long_stream = parser.get_string_property("long")
        final_value = await long_stream

        assert final_value == long_value
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_string_with_special_characters(self):
        """Test string with special characters."""
        json_text = '{"auth":{"user":{"profile":{"name":"Charlie"}}}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("auth.user.profile.name")
        chunks = [chunk async for chunk in name_stream]
        final_value = await name_stream

        assert "".join(chunks) == "Charlie"
        assert final_value == "Charlie"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_string_streaming_incremental_chunks(self):
        """Test string streaming with incremental chunks."""
        json_text = '{"long":"This is a long string that will be split across chunks."}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10, interval=1)
        parser = JsonStreamParser(stream)

        long_stream = parser.get_string_property("long")
        chunks = [chunk async for chunk in long_stream]
        final_value = await long_stream

        assert "".join(chunks) == "This is a long string that will be split across chunks."
        assert final_value == "This is a long string that will be split across chunks."
        await parser.dispose()
