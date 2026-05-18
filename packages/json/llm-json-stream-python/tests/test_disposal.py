"""Disposal tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestDisposal:
    """Disposal and resource cleanup test suite."""

    @pytest.mark.asyncio
    async def test_dispose_clears_resources(self):
        """Test that dispose clears resources."""
        json_text = '{"title": "Test", "age": 25}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        title_stream = parser.get_string_property("title")
        age_stream = parser.get_number_property("age")

        await asyncio.gather(title_stream, age_stream)
        await parser.dispose()

        assert True

    @pytest.mark.asyncio
    async def test_dispose_stops_listening(self):
        """Test that dispose stops listening."""
        json_text = '{"name": "Alice", "age": 30}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1, interval=50)
        parser = JsonStreamParser(stream)
        name_stream = parser.get_string_property("name")

        async def dispose_soon() -> None:
            await asyncio.sleep(0.02)
            await parser.dispose()

        asyncio.create_task(dispose_soon())

        with pytest.raises(ValueError):
            await name_stream

    @pytest.mark.asyncio
    async def test_multiple_dispose_calls(self):
        """Test multiple dispose calls are safe."""
        json_text = '{"value": 42}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=10)
        parser = JsonStreamParser(stream)

        await parser.dispose()
        await parser.dispose()
        await parser.dispose()

        assert True

    @pytest.mark.asyncio
    async def test_no_errors_after_dispose(self):
        """Test no errors occur after dispose."""
        json_text = '{"value": 42}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_number_property("value")
        await value_stream
        await parser.dispose()

        assert True
