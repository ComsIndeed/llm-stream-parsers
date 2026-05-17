"""Incremental updates tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestIncrementalUpdates:
    """Incremental updates test suite for properties."""

    async def _queue_stream(self, queue: asyncio.Queue[str | None]):
        while True:
            item = await queue.get()
            if item is None:
                break
            yield item

    @pytest.mark.asyncio
    async def test_string_emits_on_each_chunk(self):
        """Test string emits on each chunk."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        string_stream = parser.get_string_property("name")
        emitted = []

        async def collect():
            async for value in string_stream:
                emitted.append(value)

        collect_task = asyncio.create_task(collect())

        await queue.put('{"name":"Al')
        await asyncio.sleep(0.01)
        await queue.put('ice"}')
        await asyncio.sleep(0.01)
        await queue.put(None)

        await collect_task
        final_value = await string_stream

        assert emitted == ["Al", "ice"]
        assert final_value == "Alice"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_string_emits_buffered_chunks(self):
        """Test string emits buffered chunks."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"title":"This i')
        await queue.put('s a co')

        string_stream = parser.get_string_property("title")
        emitted = []

        async def collect():
            async for value in string_stream:
                emitted.append(value)

        collect_task = asyncio.create_task(collect())

        await asyncio.sleep(0.01)
        await queue.put('ol parser!')
        await queue.put(' Whatt!"}')
        await queue.put(None)

        await collect_task
        assert "".join(emitted) == "This is a cool parser! Whatt!"
        assert emitted[:1] == ["This is a co"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_string_does_not_emit_unbuffered(self):
        """Test string does not emit unbuffered."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"title":"This i')
        await queue.put('s a co')

        string_stream = parser.get_string_property("title")
        emitted = []

        async def collect():
            async for value in string_stream.unbuffered():
                emitted.append(value)

        collect_task = asyncio.create_task(collect())

        await asyncio.sleep(0.01)
        await queue.put('ol parser!')
        await queue.put(' Whatt!"}')
        await queue.put(None)

        await collect_task
        assert "".join(emitted) == "ol parser! Whatt!"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_maps_emit_buffered_latest_value_only(self):
        """Test maps emit buffered (latest value only)."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"name": "Al')
        await queue.put('ice", "age": 30')

        map_stream = parser.get_map_property("")
        emitted = []

        async def collect():
            async for value in map_stream:
                emitted.append(dict(value))

        collect_task = asyncio.create_task(collect())

        await asyncio.sleep(0.01)
        await queue.put(', "active": true}')
        await queue.put(None)

        await collect_task
        final_map = await map_stream

        assert emitted
        assert final_map["name"] == "Alice"
        assert final_map["age"] == 30
        assert final_map["active"] is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_maps_unbuffered_does_not_replay(self):
        """Test maps unbuffered does not replay."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"name": "Al')
        await queue.put('ice", "age": 30')

        map_stream = parser.get_map_property("")
        emitted = []

        async def collect():
            async for value in map_stream.unbuffered():
                emitted.append(dict(value))

        collect_task = asyncio.create_task(collect())

        await asyncio.sleep(0.01)
        await queue.put(', "active": true}')
        await queue.put(None)

        await collect_task
        assert emitted
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_lists_emit_buffered_latest_value_only(self):
        """Test lists emit buffered (latest value only)."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"items": [1, 2')
        await queue.put(', 3')

        list_stream = parser.get_list_property("items")
        emitted = []

        async def collect():
            async for value in list_stream:
                emitted.append(list(value))

        collect_task = asyncio.create_task(collect())

        await asyncio.sleep(0.01)
        await queue.put(', 4, 5]}')
        await queue.put(None)

        await collect_task
        assert emitted
        assert emitted[-1] == [1, 2, 3, 4, 5]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_lists_unbuffered_does_not_replay(self):
        """Test lists unbuffered does not replay."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"items": [1, 2')
        await queue.put(', 3')

        list_stream = parser.get_list_property("items")
        emitted = []

        async def collect():
            async for value in list_stream.unbuffered():
                emitted.append(list(value))

        collect_task = asyncio.create_task(collect())

        await asyncio.sleep(0.01)
        await queue.put(', 4, 5]}')
        await queue.put(None)

        await collect_task
        assert emitted
        assert emitted[-1] == [1, 2, 3, 4, 5]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_incremental_stream_updates(self):
        """Test incremental stream updates."""
        json_chunks = [
            '{"tags":["firs',
            't tag for te',
            'sting the pa',
            'rser with mo',
            're character',
            's","second t',
            'ag that is a',
            ' bit longer"',
            ',"third tag"]',
            '}'
        ]
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))
        list_stream = parser.get_list_property("tags")

        emitted = []

        async def collect():
            async for value in list_stream:
                emitted.append(list(value))

        collect_task = asyncio.create_task(collect())

        for chunk in json_chunks:
            await queue.put(chunk)
            await asyncio.sleep(0.01)
        await queue.put(None)

        await collect_task
        final_list = await list_stream

        assert final_list[0].startswith("first tag")
        assert final_list[2] == "third tag"
        assert emitted
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_buffered_vs_unbuffered_behavior(self):
        """Test buffered vs unbuffered behavior."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"title":"This i')
        await queue.put('s a co')

        string_stream = parser.get_string_property("title")

        buffered_values = []
        unbuffered_values = []

        async def collect_buffered():
            async for value in string_stream:
                buffered_values.append(value)

        async def collect_unbuffered():
            async for value in string_stream.unbuffered():
                unbuffered_values.append(value)

        buffered_task = asyncio.create_task(collect_buffered())
        unbuffered_task = asyncio.create_task(collect_unbuffered())

        await asyncio.sleep(0.01)
        await queue.put('ol parser!')
        await queue.put(' Whatt!"}')
        await queue.put(None)

        await asyncio.gather(buffered_task, unbuffered_task)
        assert buffered_values
        assert unbuffered_values
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_late_subscription_behavior(self):
        """Test late subscription behavior."""
        queue: asyncio.Queue[str | None] = asyncio.Queue()
        parser = JsonStreamParser(self._queue_stream(queue))

        await queue.put('{"text":"hel')
        await queue.put('lo"}')

        text_stream = parser.get_string_property("text")
        await asyncio.sleep(0.01)

        emitted = [value async for value in text_stream]
        assert "".join(emitted) == "hello"

        await queue.put(None)
        await parser.dispose()
