"""Comprehensive value retrieval tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestComprehensiveValueRetrieval:
    """Comprehensive value retrieval test suite."""

    @pytest.mark.asyncio
    async def test_retrieve_string_property(self):
        """Test retrieving string property."""
        json_text = '{"name":"Alice"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        assert await name_stream == "Alice"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_retrieve_number_property(self):
        """Test retrieving number property."""
        json_text = '{"age":30}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        age_stream = parser.get_number_property("age")
        assert await age_stream == 30
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_retrieve_boolean_property(self):
        """Test retrieving boolean property."""
        json_text = '{"active":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        active_stream = parser.get_boolean_property("active")
        assert await active_stream is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_retrieve_null_property(self):
        """Test retrieving null property."""
        json_text = '{"value":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_null_property("value")
        assert await value_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_retrieve_list_property(self):
        """Test retrieving list property."""
        json_text = '{"numbers":[1,2,3]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        list_stream = parser.get_list_property("numbers")
        assert await list_stream == [1, 2, 3]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_retrieve_map_property(self):
        """Test retrieving map property."""
        json_text = '{"user":{"name":"Bob","age":25}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        user_stream = parser.get_map_property("user")
        assert await user_stream == {"name": "Bob", "age": 25}
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_retrieve_nested_property(self):
        """Test retrieving nested property."""
        json_text = '{"user":{"address":{"city":"NYC"}}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        city_stream = parser.get_string_property("user.address.city")
        assert await city_stream == "NYC"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_retrieve_multiple_properties_concurrently(self):
        """Test retrieving multiple properties concurrently."""
        json_text = '{"name":"Alice","age":30,"active":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        age_stream = parser.get_number_property("age")
        active_stream = parser.get_boolean_property("active")

        results = await asyncio.gather(name_stream, age_stream, active_stream)
        assert results == ["Alice", 30, True]
        await parser.dispose()
