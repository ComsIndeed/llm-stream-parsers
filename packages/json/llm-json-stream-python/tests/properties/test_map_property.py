"""Map/Object property tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestMapProperty:
    """Map/Object property test suite."""

    @pytest.mark.asyncio
    async def test_simple_object(self):
        """Test simple object."""
        json_text = '{"name":"Alice","age":30}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        name_stream = parser.get_string_property("name")
        age_stream = parser.get_number_property("age")

        final_map = await map_stream
        assert final_map["name"] == "Alice"
        assert final_map["age"] == 30
        assert await name_stream == "Alice"
        assert await age_stream == 30
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_empty_object(self):
        """Test empty object."""
        json_text = '{"empty":{}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        empty_stream = parser.get_map_property("empty")
        empty_map = await empty_stream

        assert empty_map == {}
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_with_string_properties(self):
        """Test object with string properties."""
        json_text = '{"name":"Bob","city":"Paris"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        city_stream = parser.get_string_property("city")

        assert await name_stream == "Bob"
        assert await city_stream == "Paris"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_with_numeric_properties(self):
        """Test object with numeric properties."""
        json_text = '{"count":42,"score":99}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        count_stream = parser.get_number_property("count")
        score_stream = parser.get_number_property("score")

        assert await count_stream == 42
        assert await score_stream == 99
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_with_mixed_types(self):
        """Test object with mixed property types."""
        json_text = '{"string":"text","number":42,"bool":true,"null":null}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        string_stream = parser.get_string_property("string")
        number_stream = parser.get_number_property("number")
        bool_stream = parser.get_boolean_property("bool")
        null_stream = parser.get_null_property("null")

        assert await string_stream == "text"
        assert await number_stream == 42
        assert await bool_stream is True
        assert await null_stream is None
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_nested_objects(self):
        """Test nested objects."""
        json_text = '{"user":{"name":"Charlie","age":35}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        user_map = parser.get_map_property("user")
        name_stream = parser.get_string_property("user.name")
        age_stream = parser.get_number_property("user.age")

        assert await user_map == {"name": "Charlie", "age": 35}
        assert await name_stream == "Charlie"
        assert await age_stream == 35
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_with_arrays(self):
        """Test object containing arrays."""
        json_text = '{"items":[1,2,3],"names":["a","b"]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        items_stream = parser.get_list_property("items")
        names_stream = parser.get_list_property("names")

        assert await items_stream == [1, 2, 3]
        assert await names_stream == ["a", "b"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_split_across_chunks(self):
        """Test object split across chunks."""
        json_text = '{"user":{"name":"Dana","email":"dana@example.com"}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("user.name")
        email_stream = parser.get_string_property("user.email")

        assert await name_stream == "Dana"
        assert await email_stream == "dana@example.com"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_incremental_updates(self):
        """Test object incremental updates."""
        json_text = '{"posts":[{"title":"A","content":"Hi"}]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("posts[0]")
        snapshots = []

        async def collect():
            async for snapshot in map_stream:
                snapshots.append(dict(snapshot))

        await asyncio.create_task(collect())
        final_map = await map_stream

        assert final_map["title"] == "A"
        assert final_map["content"] == "Hi"
        assert snapshots
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_with_trailing_comma(self):
        """Test object with trailing comma."""
        json_text = '{"a":1,"b":2,}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        a_stream = parser.get_number_property("a")
        b_stream = parser.get_number_property("b")
        root_stream = parser.get_map_property("")

        assert await a_stream == 1
        assert await b_stream == 2
        assert await root_stream == {"a": 1, "b": 2}
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_streaming_properties(self):
        """Test object streaming properties."""
        json_text = '{"title":"Hello World"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        string_chunks: list[str] = []

        def on_property(prop, key):
            if key == "title":
                async def collect():
                    async for chunk in prop:
                        string_chunks.append(chunk)

                asyncio.create_task(collect())

        map_stream.on_property(on_property)

        await map_stream
        assert "".join(string_chunks) == "Hello World"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_object_with_special_key_names(self):
        """Test object with special key names."""
        json_text = '{"first-name":"Alice","user id":123}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("first-name")
        id_stream = parser.get_number_property("user id")

        assert await name_stream == "Alice"
        assert await id_stream == 123
        await parser.dispose()
