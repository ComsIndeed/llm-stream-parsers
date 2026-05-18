"""Debug nested list tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestDebugNestedList:
    """Debug nested list test suite."""

    @pytest.mark.asyncio
    async def test_debug_nested_list_scenario_1(self):
        """Test debug nested list scenario 1."""
        json_text = '{"tags":["a","b"]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        result = await map_stream

        assert result["tags"] == ["a", "b"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_nested_list_scenario_2(self):
        """Test debug nested list scenario 2."""
        json_text = '{"tags":["a","b"]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        tags_stream = parser.get_list_property("tags")

        map_value, tags_value = await asyncio.gather(map_stream, tags_stream)

        assert tags_value == ["a", "b"]
        assert map_value["tags"] == ["a", "b"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_nested_list_scenario_3(self):
        """Test debug nested list scenario 3."""
        json_text = '{"list":[[1,2],[3,4]]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=10)
        parser = JsonStreamParser(stream)

        list_stream = parser.get_list_property("list")
        result = await list_stream

        assert result == [[1, 2], [3, 4]]
        await parser.dispose()
