"""Type mismatch debug tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestTypeMismatchDebug:
    """Type mismatch debugging test suite."""

    @pytest.mark.asyncio
    async def test_debug_string_as_number_mismatch(self):
        """Debug string accessed as number."""
        json_text = '{"test": "value"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_number_property("test")
        with pytest.raises(ValueError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_number_as_string_mismatch(self):
        """Debug number accessed as string."""
        json_text = '{"test": 123}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_string_property("test")
        with pytest.raises(ValueError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_array_as_object_mismatch(self):
        """Debug array accessed as object."""
        json_text = '{"test": [1, 2]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_map_property("test")
        with pytest.raises(ValueError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_object_as_array_mismatch(self):
        """Debug object accessed as array."""
        json_text = '{"test": {"a": 1}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_list_property("test")
        with pytest.raises(ValueError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_null_type_mismatch(self):
        """Debug null type mismatch."""
        json_text = '{"test": null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_string_property("test")
        with pytest.raises(ValueError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_debug_boolean_type_coercion(self):
        """Debug boolean type coercion."""
        json_text = '{"test": true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_number_property("test")
        with pytest.raises(ValueError):
            await value_stream
        await parser.dispose()
