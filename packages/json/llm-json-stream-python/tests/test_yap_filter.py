"""YAP filter tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestYAPFilter:
    """YAP (Yet Another Pattern) filter test suite."""

    @pytest.mark.asyncio
    async def test_yap_filter_basic(self):
        """Test YAP filter basic functionality."""
        json_text = '{"name": "Valid"} Extra text here'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=5)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("name")
        assert name == "Valid"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_yap_filter_with_nested_patterns(self):
        """Test YAP filter with nested patterns."""
        json_text = '{"user": {"name": "Alice", "age": 30}} trailing'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10, interval=5)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("user.name")
        age = await parser.get_number_property("user.age")

        assert name == "Alice"
        assert age == 30
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_yap_filter_with_special_characters(self):
        """Test YAP filter with special characters."""
        json_text = '{"message": "Hello"} ### $$$ ???'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        message = await parser.get_string_property("message")
        assert message == "Hello"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_yap_filter_performance(self):
        """Test YAP filter performance."""
        yap_text = "x" * 2000
        json_text = '{"value": 42}' + yap_text
        stream = stream_text_in_chunks(text=json_text, chunk_size=50, interval=1)
        parser = JsonStreamParser(stream)

        value = await parser.get_number_property("value")
        assert value == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_yap_filter_edge_cases(self):
        """Test YAP filter edge cases."""
        json_text = '[1, 2, 3] trailing text'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream)

        result = await parser.get_list_property("")
        assert result == [1, 2, 3]
        await parser.dispose()
