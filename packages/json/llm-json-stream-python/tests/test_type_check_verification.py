"""Type check verification tests."""

import pytest
from llm_json_stream import (
    BooleanPropertyStream,
    JsonStreamParser,
    ListPropertyStream,
    MapPropertyStream,
    NullPropertyStream,
    NumberPropertyStream,
    StringPropertyStream,
)
from tests.utils.stream_utils import stream_text_in_chunks


class TestTypeCheckVerification:
    """Type check verification test suite."""

    @pytest.mark.asyncio
    async def test_string_type_verification(self):
        """Test string type verification."""
        stream = stream_text_in_chunks(text='{"strProp": "value"}', chunk_size=5, interval=0)
        parser = JsonStreamParser(stream)

        result = parser.str("strProp")
        assert isinstance(result, StringPropertyStream)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_number_type_verification(self):
        """Test number type verification."""
        stream = stream_text_in_chunks(text='{"numProp": 123}', chunk_size=5, interval=0)
        parser = JsonStreamParser(stream)

        result = parser.number("numProp")
        assert isinstance(result, NumberPropertyStream)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_boolean_type_verification(self):
        """Test boolean type verification."""
        stream = stream_text_in_chunks(text='{"boolProp": true}', chunk_size=5, interval=0)
        parser = JsonStreamParser(stream)

        result = parser.boolean("boolProp")
        assert isinstance(result, BooleanPropertyStream)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_type_verification(self):
        """Test null type verification."""
        stream = stream_text_in_chunks(text='{"nilProp": null}', chunk_size=5, interval=0)
        parser = JsonStreamParser(stream)

        result = parser.nil("nilProp")
        assert isinstance(result, NullPropertyStream)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_type_verification(self):
        """Test array type verification."""
        stream = stream_text_in_chunks(text='{"listProp": [1,2]}', chunk_size=5, interval=0)
        parser = JsonStreamParser(stream)

        result = parser.list("listProp")
        assert isinstance(result, ListPropertyStream)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_type_verification(self):
        """Test object type verification."""
        stream = stream_text_in_chunks(text='{"mapProp": {"name": "A"}}', chunk_size=5, interval=0)
        parser = JsonStreamParser(stream)

        result = parser.map("mapProp")
        assert isinstance(result, MapPropertyStream)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_type_consistency_across_chunks(self):
        """Test type consistency across chunks."""
        json_text = '{"value": 123}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1, interval=5)
        parser = JsonStreamParser(stream)

        value_stream = parser.number("value")
        value = await value_stream

        assert value == 123
        assert isinstance(value, (int, float))
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_type_coercion_behaviors(self):
        """Test type coercion behaviors."""
        json_text = '{"value": "123"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream)

        value_stream = parser.number("value")
        with pytest.raises(ValueError):
            await value_stream
        await parser.dispose()
