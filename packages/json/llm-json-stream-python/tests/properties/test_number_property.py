"""Number property tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestNumberProperty:
    """Number property test suite."""

    @pytest.mark.asyncio
    async def test_simple_integer(self):
        """Test simple integer property."""
        json_text = '{"age":30}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        age_stream = parser.get_number_property("age")
        emitted = [value async for value in age_stream]
        final_value = await age_stream

        assert emitted == [30]
        assert final_value == 30
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_simple_float(self):
        """Test simple float property."""
        json_text = '{"price":19.99}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        price_stream = parser.get_number_property("price")
        emitted = [value async for value in price_stream]
        final_value = await price_stream

        assert emitted == [19.99]
        assert final_value == 19.99
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_negative_number(self):
        """Test negative number."""
        json_text = '{"temperature":-5}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        temp_stream = parser.get_number_property("temperature")
        emitted = [value async for value in temp_stream]
        final_value = await temp_stream

        assert emitted == [-5]
        assert final_value == -5
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_zero(self):
        """Test zero."""
        json_text = '{"count":0}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        count_stream = parser.get_number_property("count")
        emitted = [value async for value in count_stream]
        final_value = await count_stream

        assert emitted == [0]
        assert final_value == 0
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_scientific_notation(self):
        """Test scientific notation."""
        json_text = '{"large":1.23e10}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        large_stream = parser.get_number_property("large")
        emitted = [value async for value in large_stream]
        final_value = await large_stream

        assert emitted == [1.23e10]
        assert final_value == 1.23e10
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_very_large_number(self):
        """Test very large number."""
        json_text = '{"big":9223372036854775807}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        big_stream = parser.get_number_property("big")
        emitted = [value async for value in big_stream]
        final_value = await big_stream

        assert emitted == [9223372036854775807]
        assert final_value == 9223372036854775807
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_very_small_number(self):
        """Test very small number."""
        json_text = '{"tiny":0.000000001}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=10)
        parser = JsonStreamParser(stream)

        tiny_stream = parser.get_number_property("tiny")
        emitted = [value async for value in tiny_stream]
        final_value = await tiny_stream

        assert emitted == [0.000000001]
        assert final_value == 0.000000001
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_number_split_across_chunks(self):
        """Test number split across chunks."""
        json_text = '{"num":123456789}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        num_stream = parser.get_number_property("num")
        final_value = await num_stream

        assert final_value == 123456789
        await parser.dispose()
