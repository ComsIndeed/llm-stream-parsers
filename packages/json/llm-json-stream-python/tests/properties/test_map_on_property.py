"""Map on property tests."""

import asyncio

import pytest
from llm_json_stream import (
    BooleanPropertyStream,
    JsonStreamParser,
    ListPropertyStream,
    MapPropertyStream,
    NumberPropertyStream,
    StringPropertyStream,
)
from tests.utils.stream_utils import stream_text_in_chunks


class TestMapOnProperty:
    """Map on property test suite."""

    @pytest.mark.asyncio
    async def test_map_on_property_basic(self):
        """Test map on property basic functionality."""
        input_text = '{"name":"Alice","age":30,"active":true}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        discovered = []
        types = {}

        map_stream.on_property(lambda prop, key: (discovered.append(key), types.setdefault(key, type(prop))))

        result = await map_stream

        assert result == {"name": "Alice", "age": 30, "active": True}
        assert discovered == ["name", "age", "active"]
        assert types["name"] is StringPropertyStream
        assert types["age"] is NumberPropertyStream
        assert types["active"] is BooleanPropertyStream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_map_on_property_with_transformation(self):
        """Test map on property with transformation."""
        input_text = '{"title":"Hello World"}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        chunks: list[str] = []

        def on_property(prop, key):
            if isinstance(prop, StringPropertyStream):
                async def collect():
                    async for chunk in prop:
                        chunks.append(chunk)

                asyncio.create_task(collect())

        map_stream.on_property(on_property)

        await map_stream
        assert "".join(chunks) == "Hello World"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_map_on_property_chaining(self):
        """Test map on property chaining."""
        input_text = '{"user":{"name":"Bob"}}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        root_stream = parser.get_map_property("")
        user_names: list[str] = []

        def on_property(prop, key):
            if isinstance(prop, MapPropertyStream):
                name_stream = prop.get_string_property("name")
                name_stream.on_value(user_names.append)

        root_stream.on_property(on_property)

        await root_stream
        assert user_names == ["Bob"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_map_on_property_nested(self):
        """Test map on property with nested properties."""
        input_text = '{"user":{"name":"Bob","address":{"city":"NYC"}}}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=8, interval=10)
        parser = JsonStreamParser(stream)

        root_map = parser.get_map_property("")
        user_map = parser.get_map_property("user")
        address_map = parser.get_map_property("user.address")

        root_keys = []
        user_keys = []
        address_keys = []

        root_map.on_property(lambda _, key: root_keys.append(key))
        user_map.on_property(lambda _, key: user_keys.append(key))
        address_map.on_property(lambda _, key: address_keys.append(key))

        await root_map

        assert root_keys == ["user"]
        assert user_keys == ["name", "address"]
        assert address_keys == ["city"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_map_on_property_multiple_calls(self):
        """Test map on property with multiple calls."""
        input_text = '{"x":1,"y":2}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        callback1 = []
        callback2 = []

        map_stream.on_property(lambda _, key: callback1.append(f"cb1:{key}"))
        map_stream.on_property(lambda _, key: callback2.append(f"cb2:{key}"))

        await map_stream

        assert callback1 == ["cb1:x", "cb1:y"]
        assert callback2 == ["cb2:x", "cb2:y"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_map_on_property_error_handling(self):
        """Test map on property error handling."""
        input_text = '{"value":42}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        map_stream.on_property(lambda prop, key: (_ for _ in ()).throw(ValueError("boom")) if key == "value" else None)

        with pytest.raises(ValueError):
            await map_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_map_on_property_with_arrays(self):
        """Test map on property with arrays."""
        input_text = '{"items":[1,2,3],"names":["a","b"]}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=6, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        types = {}

        map_stream.on_property(lambda prop, key: types.setdefault(key, type(prop)))

        result = await map_stream
        assert result == {"items": [1, 2, 3], "names": ["a", "b"]}
        assert types["items"] is ListPropertyStream
        assert types["names"] is ListPropertyStream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_map_on_property_with_objects(self):
        """Test map on property with objects."""
        input_text = '{"user":{"name":"Alice"}}'
        stream = stream_text_in_chunks(text=input_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        map_stream = parser.get_map_property("")
        types = {}

        map_stream.on_property(lambda prop, key: types.setdefault(key, type(prop)))

        result = await map_stream
        assert result == {"user": {"name": "Alice"}}
        assert types["user"] is MapPropertyStream
        await parser.dispose()
