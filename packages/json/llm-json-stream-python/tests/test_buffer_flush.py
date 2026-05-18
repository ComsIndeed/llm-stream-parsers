"""Tests for buffer flushing behavior.

Combines tests from both buffer_flush_test.dart and buffer_flush.test.ts.
Dart has 10 tests, TypeScript has 8 tests. Using all unique tests from both.
"""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import AsyncStreamController, stream_text_in_chunks


class TestBufferFlushingBugReproduction:
    """Test buffer flushing bug scenarios."""

    @pytest.mark.asyncio
    async def test_string_ending_without_chunk_boundary(self):
        """POTENTIAL BUG: string ending without chunk boundary."""
        # Create a scenario where the string ends but there's still data in the buffer
        # This happens when the closing quote comes in but onChunkEnd was never called
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        name_stream = parser.get_string_property("name")

        await controller.add('{"name":"Alic')
        await asyncio.sleep(0.01)
        await controller.add('e"}')
        await controller.close()

        result = await asyncio.wait_for(name_stream, timeout=5)
        assert result == "Alice"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_number_at_end_of_stream_without_delimiter(self):
        """Numbers rely on delimiters or stream end to complete."""
        # Numbers rely on delimiters or stream end to complete
        # If the stream ends without a delimiter, the number might not be parsed
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        count_stream = parser.get_number_property("count")

        await controller.add('{"count":4')
        await asyncio.sleep(0.01)
        await controller.add('2}')
        await controller.close()

        result = await asyncio.wait_for(count_stream, timeout=5)
        assert result == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_values_where_last_one_has_buffered_data(self):
        """Multiple values where last one has buffered data."""
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        a_stream = parser.get_string_property("a")
        b_stream = parser.get_string_property("b")

        await controller.add('{"a":"x","b":"')
        await asyncio.sleep(0.01)
        await controller.add('y"}')
        await controller.close()

        results = await asyncio.wait_for(asyncio.gather(a_stream, b_stream), timeout=5)
        assert results[0] == "x"
        assert results[1] == "y"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_nested_property_at_end_with_buffered_data(self):
        """Nested property at end with buffered data."""
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        name_stream = parser.get_string_property("user.name")

        await controller.add('{"user":{"name":"Bo')
        await asyncio.sleep(0.01)
        await controller.add('b"}}')
        await controller.close()

        result = await asyncio.wait_for(name_stream, timeout=5)
        assert result == "Bob"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_stream_closes_while_string_buffer_has_content(self):
        """Stream closes while string buffer has content - core bug."""
        # This is the core bug: if we have buffered string content
        # and the stream closes, that buffer needs to be flushed
        
        test_json = '{"msg":"test"}'
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        msg_stream = parser.get_string_property("msg")

        chunks: list[str] = []

        async def collect():
            async for chunk in msg_stream:
                chunks.append(chunk)

        collect_task = asyncio.create_task(collect())

        for char in test_json[:-2]:
            await controller.add(char)
            await asyncio.sleep(0.005)

        await controller.add('"')
        await controller.add('}')
        await controller.close()

        await collect_task
        result = await asyncio.wait_for(msg_stream, timeout=5)

        assert result == "test"
        assert "".join(chunks) == "test"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_verify_on_chunk_end_called_on_stream_completion(self):
        """Verify onChunkEnd is called on stream completion."""
        # This test verifies that onChunkEnd is actually called
        # when the stream completes
        
        test_json = '{"data":"value"}'
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        data_stream = parser.get_string_property("data")

        chunks: list[str] = []

        async def collect():
            async for chunk in data_stream:
                chunks.append(chunk)

        collect_task = asyncio.create_task(collect())

        await controller.add(test_json)
        await controller.close()

        await collect_task
        result = await asyncio.wait_for(data_stream, timeout=5)

        assert result == "value"
        assert chunks
        await parser.dispose()


class TestVerifyCurrentBehavior:
    """Verify current behavior tests."""

    @pytest.mark.asyncio
    async def test_how_many_stream_chunks_emitted_with_large_input_chunk(self):
        """How many stream chunks are emitted with large input chunk?"""
        test_json = '{"text":"hello world"}'
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())
        text_stream = parser.get_string_property("text")

        stream_chunks: list[str] = []

        async def collect():
            async for chunk in text_stream:
                stream_chunks.append(chunk)

        collect_task = asyncio.create_task(collect())

        await controller.add(test_json)
        await controller.close()

        await collect_task
        await text_stream

        assert "".join(stream_chunks) == "hello world"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_track_when_on_chunk_end_called(self):
        """Track when onChunkEnd is called."""
        controller = AsyncStreamController()
        parser = JsonStreamParser(controller.stream())

        a_stream = parser.get_string_property("a")
        b_stream = parser.get_string_property("b")
        c_stream = parser.get_string_property("c")

        a_chunks: list[str] = []
        b_chunks: list[str] = []
        c_chunks: list[str] = []

        async def collect(stream, target):
            async for chunk in stream:
                target.append(chunk)

        tasks = [
            asyncio.create_task(collect(a_stream, a_chunks)),
            asyncio.create_task(collect(b_stream, b_chunks)),
            asyncio.create_task(collect(c_stream, c_chunks)),
        ]

        await controller.add('{"a":"1"')
        await asyncio.sleep(0.01)
        await controller.add(',"b":"2"')
        await asyncio.sleep(0.01)
        await controller.add(',"c":"3"}')
        await controller.close()

        await asyncio.gather(*tasks)
        await asyncio.gather(a_stream, b_stream, c_stream)

        assert "".join(a_chunks) == "1"
        assert "".join(b_chunks) == "2"
        assert "".join(c_chunks) == "3"
        await parser.dispose()


class TestBufferFlushFromTypeScript:
    """Additional buffer flush tests from TypeScript (not in Dart)."""

    @pytest.mark.asyncio
    async def test_string_buffer_flushes_on_chunk_boundary(self):
        """String buffer flushes on chunk boundary."""
        json_text = '{"text":"HelloWorld"}'
        # Chunk size of 3 will split the string value
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=3,
            interval=10,
        )
        parser = JsonStreamParser(stream)
        text_stream = parser.get_string_property("text")

        chunks = [chunk async for chunk in text_stream]
        final_value = await text_stream

        assert "".join(chunks) == "HelloWorld"
        assert final_value == "HelloWorld"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_incomplete_value_at_chunk_end_is_buffered(self):
        """Incomplete value at chunk end is buffered."""
        json_text = '{"value":"test"}'
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=5,
            interval=10,
        )
        parser = JsonStreamParser(stream)
        value_stream = parser.get_string_property("value")

        chunks = [chunk async for chunk in value_stream]
        final_value = await value_stream

        assert "".join(chunks) == "test"
        assert final_value == "test"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_escape_sequence_split_across_chunks(self):
        """Escape sequence split across chunks."""
        json_text = '{"text":"Hello\\nWorld"}'
        # Make sure \\n gets split across chunks
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=12,  # This should split at the escape sequence
            interval=10,
        )
        parser = JsonStreamParser(stream)
        text_stream = parser.get_string_property("text")

        chunks = [chunk async for chunk in text_stream]
        final_value = await text_stream

        assert "".join(chunks) == "Hello\nWorld"
        assert final_value == "Hello\nWorld"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_number_split_across_chunks(self):
        """Number split across chunks."""
        json_text = '{"number":12345}'
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=5,
            interval=10,
        )
        parser = JsonStreamParser(stream)
        number_stream = parser.get_number_property("number")
        assert await number_stream == 12345
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_keyword_split_across_chunks(self):
        """Keyword (true/false/null) split across chunks."""
        json_text = '{"a":true,"b":false,"c":null}'
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=4,
            interval=10,
        )
        parser = JsonStreamParser(stream)
        a_stream = parser.get_boolean_property("a")
        b_stream = parser.get_boolean_property("b")
        c_stream = parser.get_null_property("c")

        assert await a_stream is True
        assert await b_stream is False
        assert await c_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_property_name_split_across_chunks(self):
        """Property name split across chunks."""
        json_text = '{"longPropertyName":"value"}'
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=6,
            interval=10,
        )
        parser = JsonStreamParser(stream)
        prop_stream = parser.get_string_property("longPropertyName")
        assert await prop_stream == "value"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_incomplete_values_buffered(self):
        """Multiple incomplete values buffered."""
        json_text = '{"a":"test1","b":"test2","c":"test3"}'
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=7,
            interval=10,
        )
        parser = JsonStreamParser(stream)
        a_stream = parser.get_string_property("a")
        b_stream = parser.get_string_property("b")
        c_stream = parser.get_string_property("c")

        results = await asyncio.gather(a_stream, b_stream, c_stream)
        assert list(results) == ["test1", "test2", "test3"]
        await parser.dispose()
