"""Null property tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestNullProperty:
    """Null property test suite."""

    @pytest.mark.asyncio
    async def test_null_value(self):
        """Test null value."""
        json_text = '{"value":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_null_property("value")
        emitted = [value async for value in value_stream]
        final_value = await value_stream

        assert emitted == [None]
        assert final_value is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_split_across_chunks(self):
        """Test null value split across chunks."""
        json_text = '{"value":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_null_property("value")
        final_value = await value_stream

        assert final_value is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_null_properties(self):
        """Test multiple null properties."""
        json_text = '{"field1":null,"field2":null,"field3":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        field1_stream = parser.get_null_property("field1")
        field2_stream = parser.get_null_property("field2")
        field3_stream = parser.get_null_property("field3")

        assert await field1_stream is None
        assert await field2_stream is None
        assert await field3_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_in_nested_object(self):
        """Test null in nested object."""
        json_text = '{"user":{"middle_name":null}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        middle_name_stream = parser.get_null_property("user.middle_name")
        emitted = [value async for value in middle_name_stream]
        final_value = await middle_name_stream

        assert emitted == [None]
        assert final_value is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_in_array(self):
        """Test null in array."""
        json_text = '{"values":[1,null,3]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        null_stream = parser.get_null_property("values[1]")
        assert await null_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_mixed_with_other_values(self):
        """Test null mixed with other values."""
        json_text = '{"name":"Alice","age":30,"nickname":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        age_stream = parser.get_number_property("age")
        nickname_stream = parser.get_null_property("nickname")

        assert await name_stream == "Alice"
        assert await age_stream == 30
        assert await nickname_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_vs_undefined(self):
        """Test null vs undefined."""
        json_text = '{"value":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_null_property("value")
        assert await value_stream is None

        missing_stream = parser.get_null_property("missing")
        with pytest.raises(asyncio.TimeoutError):
            await asyncio.wait_for(missing_stream, timeout=0.3)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_type_checking(self):
        """Test null type checking."""
        json_text = '{"value":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        null_stream = parser.get_null_property("value")
        assert await null_stream is None

        with pytest.raises(ValueError):
            parser.get_string_property("value")
        await parser.dispose()
