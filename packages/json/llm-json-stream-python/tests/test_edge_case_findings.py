"""Edge case findings tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestEdgeCaseFindings:
    """Edge case findings test suite."""

    @pytest.mark.asyncio
    async def test_empty_json_object(self):
        """Test with empty JSON object."""
        json_text = "{}"
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream)

        root = await parser.get_map_property("")
        assert root == {}
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_empty_json_array(self):
        """Test with empty JSON array."""
        json_text = "[]"
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream)

        root = await parser.get_list_property("")
        assert root == []
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_deeply_nested_structures(self):
        """Test deeply nested structures."""
        json_text = '{"a":{"b":{"c":{"d":"value"}}}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.get_string_property("a.b.c.d")
        assert value == "value"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_special_characters_in_strings(self):
        """Test special characters in strings."""
        json_text = r'{"text":"Hello \"World\"\nNew line\tTab"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        text = await parser.get_string_property("text")
        assert text == 'Hello "World"\nNew line\tTab'
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_unicode_characters(self):
        """Test unicode characters."""
        json_text = '{"text":"Hello 世界","emoji":"✨"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=5)
        parser = JsonStreamParser(stream)

        text = await parser.get_string_property("text")
        emoji = await parser.get_string_property("emoji")

        assert text == "Hello 世界"
        assert emoji == "✨"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_very_large_numbers(self):
        """Test very large numbers."""
        json_text = '{"big":9223372036854775807}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.get_number_property("big")
        assert value == 9223372036854775807
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_very_small_numbers(self):
        """Test very small numbers."""
        json_text = '{"tiny":0.000000001}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.get_number_property("tiny")
        assert value == 0.000000001
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_scientific_notation_numbers(self):
        """Test scientific notation numbers."""
        json_text = '{"value":1.5e10}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.get_number_property("value")
        assert value == 1.5e10
        await parser.dispose()
