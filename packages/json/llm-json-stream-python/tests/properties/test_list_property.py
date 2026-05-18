"""List/Array property tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestListProperty:
    """List/Array property test suite."""

    @pytest.mark.asyncio
    async def test_simple_array(self):
        """Test simple array."""
        json_text = '{"numbers":[1,2,3]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        numbers_stream = parser.get_list_property("numbers")
        numbers = await numbers_stream

        assert numbers == [1, 2, 3]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_empty_array(self):
        """Test empty array."""
        json_text = '{"empty":[]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        empty_stream = parser.get_list_property("empty")
        assert await empty_stream == []
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_of_strings(self):
        """Test array of strings."""
        json_text = '{"names":["Alice","Bob","Charlie"]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        names_stream = parser.get_list_property("names")
        assert await names_stream == ["Alice", "Bob", "Charlie"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_of_numbers(self):
        """Test array of numbers."""
        json_text = '{"values":[1,2,3,4]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        values_stream = parser.get_list_property("values")
        assert await values_stream == [1, 2, 3, 4]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_of_objects(self):
        """Test array of objects."""
        json_text = '{"items":[{"name":"Item1"},{"name":"Item2"}]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=10)
        parser = JsonStreamParser(stream)

        first_name_stream = parser.get_string_property("items[0].name")
        second_name_stream = parser.get_string_property("items[1].name")

        assert await first_name_stream == "Item1"
        assert await second_name_stream == "Item2"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_nested_arrays(self):
        """Test nested arrays."""
        json_text = '{"matrix":[[1,2],[3,4],[5,6]]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        val00_stream = parser.get_number_property("matrix[0][0]")
        val01_stream = parser.get_number_property("matrix[0][1]")
        val10_stream = parser.get_number_property("matrix[1][0]")
        val11_stream = parser.get_number_property("matrix[1][1]")

        assert await val00_stream == 1
        assert await val01_stream == 2
        assert await val10_stream == 3
        assert await val11_stream == 4
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_with_mixed_types(self):
        """Test array with mixed types."""
        json_text = '{"mixed":["text",42,true,null]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        text_stream = parser.get_string_property("mixed[0]")
        num_stream = parser.get_number_property("mixed[1]")
        bool_stream = parser.get_boolean_property("mixed[2]")
        null_stream = parser.get_null_property("mixed[3]")

        assert await text_stream == "text"
        assert await num_stream == 42
        assert await bool_stream is True
        assert await null_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_split_across_chunks(self):
        """Test array split across chunks."""
        json_text = '{"items":["first","second","third"]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        first_stream = parser.get_string_property("items[0]")
        second_stream = parser.get_string_property("items[1]")
        third_stream = parser.get_string_property("items[2]")

        assert await first_stream == "first"
        assert await second_stream == "second"
        assert await third_stream == "third"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_on_element_callbacks(self):
        """Test array onElement callbacks."""
        json_text = '{"colors":["red","green","blue"]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        colors_stream = parser.get_list_property("colors")
        elements: list[str] = []

        def on_element(element, index):
            element.on_value(elements.append)

        colors_stream.on_element(on_element)
        await colors_stream

        assert elements == ["red", "green", "blue"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_incremental_updates(self):
        """Test array incremental updates."""
        json_chunks = [
            '{"tags":["firs',
            't tag for te',
            'sting",',
            '"second"]',
            '}'
        ]
        queue: asyncio.Queue[str | None] = asyncio.Queue()

        async def queue_stream():
            while True:
                item = await queue.get()
                if item is None:
                    break
                yield item

        parser = JsonStreamParser(queue_stream())
        list_stream = parser.get_list_property("tags")
        emitted: list[list[str]] = []

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

        assert final_list[-1] == "second"
        assert emitted
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_with_trailing_comma(self):
        """Test array with trailing comma."""
        json_text = '{"items":["first","second","last",]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=10)
        parser = JsonStreamParser(stream)

        items_stream = parser.get_list_property("items")
        assert await items_stream == ["first", "second", "last"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_very_large(self):
        """Test very large array."""
        json_text = '{"nums":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=10)
        parser = JsonStreamParser(stream)

        nums_stream = parser.get_list_property("nums")
        nums = await nums_stream

        assert nums == list(range(1, 21))
        await parser.dispose()
