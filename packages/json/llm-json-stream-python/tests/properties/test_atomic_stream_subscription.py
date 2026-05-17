"""Atomic stream subscription tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestAtomicStreamSubscription:
    """Atomic stream subscription test suite."""

    @pytest.mark.asyncio
    async def test_atomic_subscription_single_value(self):
        """Test atomic subscription with single value."""
        json_text = '{"isActive":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        bool_stream = parser.get_boolean_property("isActive")
        emitted = [value async for value in bool_stream]
        final_value = await bool_stream

        assert emitted == [True]
        assert final_value is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_atomic_subscription_multiple_properties(self):
        """Test atomic subscription with multiple properties."""
        json_text = '{"active":false,"count":99,"data":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=7, interval=10)
        parser = JsonStreamParser(stream)

        bool_stream = parser.get_boolean_property("active")
        number_stream = parser.get_number_property("count")
        null_stream = parser.get_null_property("data")

        assert await bool_stream is False
        assert await number_stream == 99
        assert await null_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_atomic_subscription_timing(self):
        """Test atomic subscription timing."""
        json_text = '{"value":123}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=10)
        parser = JsonStreamParser(stream)

        number_stream = parser.get_number_property("value")
        emitted = [value async for value in number_stream]
        final_value = await number_stream

        assert emitted == [123]
        assert final_value == 123
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_atomic_vs_streaming_behavior(self):
        """Test atomic vs streaming behavior."""
        json_text = '{"value":42}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1, interval=1)
        parser = JsonStreamParser(stream)

        number_stream = parser.get_number_property("value")
        emitted = [value async for value in number_stream]
        final_value = await number_stream

        assert emitted == [42]
        assert final_value == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_subscription_after_completion(self):
        """Test subscription after completion."""
        json_text = '{"count":7}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        number_stream = parser.get_number_property("count")
        assert await number_stream == 7

        emitted = [value async for value in number_stream]
        assert emitted == [7]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_concurrent_subscriptions(self):
        """Test multiple concurrent subscriptions."""
        json_text = '{"flag":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        flag_stream = parser.get_boolean_property("flag")

        async def collect_values():
            return [value async for value in flag_stream]

        results = await asyncio.gather(collect_values(), collect_values())
        assert results[0] == [True]
        assert results[1] == [True]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_subscription_cancellation(self):
        """Test subscription cancellation."""
        json_text = '{"count":42}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream)

        count_stream = parser.get_number_property("count")

        async def collect():
            async for _ in count_stream:
                await asyncio.sleep(0)

        task = asyncio.create_task(collect())
        await asyncio.sleep(0.01)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

        assert await count_stream == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_subscription_lifecycle(self):
        """Test subscription lifecycle."""
        json_text = '{"config":{"enabled":true,"timeout":30}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=10)
        parser = JsonStreamParser(stream)

        enabled_stream = parser.get_boolean_property("config.enabled")
        timeout_stream = parser.get_number_property("config.timeout")

        assert await enabled_stream is True
        assert await timeout_stream == 30
        await parser.dispose()
