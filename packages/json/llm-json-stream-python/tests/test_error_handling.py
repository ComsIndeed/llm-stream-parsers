"""Error handling tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import AsyncStreamController, stream_text_in_chunks


class TestErrorHandling:
    """Error handling test suite."""

    @pytest.mark.asyncio
    async def test_malformed_json_handling(self):
        """Test malformed JSON handling."""
        json_text = '{"name":"Alice'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        with pytest.raises(RuntimeError):
            await name_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_invalid_property_path(self):
        """Test invalid property path."""
        json_text = '{"name":"Alice"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        age_stream = parser.get_number_property("age")
        with pytest.raises(RuntimeError):
            await age_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_stream_error_propagation(self):
        """Test stream error propagation."""
        async def faulty_stream():
            yield '{"value":'
            raise RuntimeError("boom")

        parser = JsonStreamParser(faulty_stream())
        value_stream = parser.get_number_property("value")

        with pytest.raises(RuntimeError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_timeout_handling(self):
        """Test timeout handling."""
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        value_stream = parser.get_string_property("value")

        with pytest.raises(asyncio.TimeoutError):
            await asyncio.wait_for(value_stream, timeout=0.1)

        await parser.dispose()
        await controller.close()

    @pytest.mark.asyncio
    async def test_type_mismatch_errors(self):
        """Test type mismatch errors."""
        json_text = '{"data":{"a":1}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("data")
        with pytest.raises(ValueError):
            parser.get_list_property("data")

        await map_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_premature_stream_closure(self):
        """Test premature stream closure."""
        json_text = '{"name":"Alice'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        with pytest.raises(RuntimeError):
            await name_stream
        await parser.dispose()
