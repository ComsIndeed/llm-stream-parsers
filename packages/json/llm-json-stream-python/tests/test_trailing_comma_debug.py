"""Trailing comma debug tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestTrailingCommaDebug:
    """Trailing comma debugging test suite."""

    @pytest.mark.asyncio
    async def test_debug_trailing_comma_parsing(self):
        """Debug trailing comma parsing."""
        json_text = '{"test":[1,2,]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream)

        result = await parser.get_list_property("test")
        assert result == [1, 2]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_trailing_comma_in_nested_array(self):
        """Debug trailing comma in nested array."""
        json_text = '{"matrix":[[1,2,],[3,4,],]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        matrix = await parser.get_list_property("matrix")
        assert matrix == [[1, 2], [3, 4]]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_trailing_comma_in_nested_object(self):
        """Debug trailing comma in nested object."""
        json_text = '{"item":{"value":1,},}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.get_number_property("item.value")
        assert value == 1
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_trailing_comma_chunk_boundaries(self):
        """Debug trailing comma at chunk boundaries."""
        json_text = '{"test":[1,2,]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1, interval=1)
        parser = JsonStreamParser(stream)

        result = await parser.get_list_property("test")
        assert result == [1, 2]
        await parser.dispose()
