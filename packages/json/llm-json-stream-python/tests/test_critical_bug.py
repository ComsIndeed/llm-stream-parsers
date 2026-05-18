"""Critical bug tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestCriticalBug:
    """Critical bug test suite."""

    @pytest.mark.asyncio
    async def test_critical_issue_scenario_1(self):
        """Test critical issue scenario 1."""
        json_text = '{"x":"a"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)
        x_stream = parser.get_string_property("x")

        result = await asyncio.wait_for(x_stream, timeout=5)
        assert result == "a"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_critical_issue_scenario_2(self):
        """Test critical issue scenario 2."""
        json_text = '{"xy":"ab"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=500, interval=10)
        parser = JsonStreamParser(stream)
        xy_stream = parser.get_string_property("xy")

        result = await asyncio.wait_for(xy_stream, timeout=5)
        assert result == "ab"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_critical_issue_scenario_3(self):
        """Test critical issue scenario 3."""
        json_text = '{"empty":""}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)
        empty_stream = parser.get_string_property("empty")

        result = await asyncio.wait_for(empty_stream, timeout=5)
        assert result == ""
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_single_digit_number_huge_chunk(self):
        json_text = '{"n":5}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)
        n_stream = parser.get_number_property("n")

        result = await asyncio.wait_for(n_stream, timeout=5)
        assert result == 5
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_boolean_value_huge_chunk(self):
        json_text = '{"flag":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)
        flag_stream = parser.get_boolean_property("flag")

        result = await asyncio.wait_for(flag_stream, timeout=5)
        assert result is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_null_value_huge_chunk(self):
        json_text = '{"nothing":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)
        null_stream = parser.get_null_property("nothing")

        result = await asyncio.wait_for(null_stream, timeout=5)
        assert result is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_compare_small_value_small_vs_large_chunk(self):
        json_text = '{"val":"hi"}'
        small_stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        large_stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=5)

        parser1 = JsonStreamParser(small_stream)
        parser2 = JsonStreamParser(large_stream)

        result1 = await asyncio.wait_for(parser1.get_string_property("val"), timeout=5)
        result2 = await asyncio.wait_for(parser2.get_string_property("val"), timeout=5)

        assert result1 == "hi"
        assert result2 == "hi"
        await parser1.dispose()
        await parser2.dispose()

    @pytest.mark.asyncio
    async def test_very_small_value_very_large_chunk(self):
        json_text = '{"k":"v"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10000, interval=10)
        parser = JsonStreamParser(stream)
        k_stream = parser.get_string_property("k")

        result = await asyncio.wait_for(k_stream, timeout=5)
        assert result == "v"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_tiny_values_single_massive_chunk(self):
        json_text = '{"a":"1","b":"2","c":"3","d":"4","e":"5"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10000, interval=10)
        parser = JsonStreamParser(stream)

        results = await asyncio.wait_for(
            asyncio.gather(
                parser.get_string_property("a"),
                parser.get_string_property("b"),
                parser.get_string_property("c"),
                parser.get_string_property("d"),
                parser.get_string_property("e"),
            ),
            timeout=5,
        )

        assert list(results) == ["1", "2", "3", "4", "5"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_on_chunk_end_matter_when_chunk_greater(self):
        json_text = '{"msg":"x"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)
        msg_stream = parser.get_string_property("msg")

        chunk_count = 0

        async def collect():
            nonlocal chunk_count
            async for _ in msg_stream:
                chunk_count += 1

        task = asyncio.create_task(collect())
        result = await asyncio.wait_for(msg_stream, timeout=5)
        await task

        assert result == "x"
        assert chunk_count > 0
        await parser.dispose()


class TestStressExtremeChunkRatios:
    """Stress tests for extreme chunk size ratios."""

    @pytest.mark.asyncio
    async def test_chunk_size_1000x_larger_than_value(self):
        json_text = '{"tiny":"ab"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2000, interval=10)
        parser = JsonStreamParser(stream)
        tiny_stream = parser.get_string_property("tiny")

        result = await asyncio.wait_for(tiny_stream, timeout=5)
        assert result == "ab"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_chunk_size_10000x_larger_than_value(self):
        json_text = '{"nano":"a"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10000, interval=10)
        parser = JsonStreamParser(stream)
        nano_stream = parser.get_string_property("nano")

        result = await asyncio.wait_for(nano_stream, timeout=5)
        assert result == "a"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_instant_delivery_massive_chunk(self):
        json_text = '{"fast":"go"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=99999, interval=0)
        parser = JsonStreamParser(stream)
        fast_stream = parser.get_string_property("fast")

        result = await asyncio.wait_for(fast_stream, timeout=5)
        assert result == "go"
        await parser.dispose()
