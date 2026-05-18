"""Trailing comma all types tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestTrailingCommaAllTypes:
    """Trailing comma tests for all property types."""

    @pytest.mark.asyncio
    async def test_trailing_comma_in_object_with_string(self):
        """Test trailing comma in object with string property."""
        json_text = '{"a":"first","b":"last",}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        b_value = await parser.get_string_property("b")
        assert b_value == "last"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_trailing_comma_in_object_with_number(self):
        """Test trailing comma in object with number property."""
        json_text = '{"x":10,"y":20,}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        y_value = await parser.get_number_property("y")
        assert y_value == 20
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_trailing_comma_in_object_with_boolean(self):
        """Test trailing comma in object with boolean property."""
        json_text = '{"active":true,}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        active = await parser.get_boolean_property("active")
        assert active is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_trailing_comma_in_object_with_null(self):
        """Test trailing comma in object with null property."""
        json_text = '{"value":null,}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.get_null_property("value")
        assert value is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_trailing_comma_in_array_with_strings(self):
        """Test trailing comma in array with string elements."""
        json_text = '{"items":["a","b","c",]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        items = await parser.get_list_property("items")
        assert items == ["a", "b", "c"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_trailing_comma_in_array_with_numbers(self):
        """Test trailing comma in array with number elements."""
        json_text = '{"nums":[1,2,42,]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        nums = await parser.get_list_property("nums")
        assert nums == [1, 2, 42]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_trailing_comma_in_nested_structures(self):
        """Test trailing comma in nested structures."""
        json_text = '{"data":[{"a":1,},{"b":2,},],"done":true,}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10, interval=5)
        parser = JsonStreamParser(stream)

        data = await parser.get_list_property("data")
        done = await parser.get_boolean_property("done")

        assert data[0]["a"] == 1
        assert data[1]["b"] == 2
        assert done is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_trailing_commas(self):
        """Test multiple trailing commas."""
        json_text = '{"items":[1,2,],"flags":[true,false,],"name":"test",}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=12, interval=5)
        parser = JsonStreamParser(stream)

        items = await parser.get_list_property("items")
        flags = await parser.get_list_property("flags")
        name = await parser.get_string_property("name")

        assert items == [1, 2]
        assert flags == [True, False]
        assert name == "test"
        await parser.dispose()
