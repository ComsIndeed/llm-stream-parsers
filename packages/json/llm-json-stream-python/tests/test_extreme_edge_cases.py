"""Extreme edge cases tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestExtremeEdgeCases:
    """Extreme edge cases test suite."""

    @pytest.mark.asyncio
    async def test_extremely_nested_object(self):
        """Test extremely nested object."""
        json_text = '{"a":{"b":{"c":{"d":{"e":"deep"}}}}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.get_string_property("a.b.c.d.e")
        assert value == "deep"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_extremely_large_array(self):
        """Test extremely large array."""
        large_array = list(range(200))
        json_text = '{"items":' + str(large_array).replace("'", "") + "}"
        stream = stream_text_in_chunks(text=json_text, chunk_size=20, interval=1)
        parser = JsonStreamParser(stream)

        items = await parser.get_list_property("items")
        assert items[:3] == [0, 1, 2]
        assert len(items) == 200
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_mixed_nested_structures(self):
        """Test mixed nested structures."""
        json_text = '{"data":[{"id":1,"tags":["a","b"]},{"id":2,"tags":["c"]}]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=5)
        parser = JsonStreamParser(stream)

        data = await parser.get_list_property("data")
        assert data[0]["id"] == 1
        assert data[1]["tags"] == ["c"]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_single_character_chunks(self):
        """Test with single character chunks."""
        json_text = '{"value":123}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1, interval=1)
        parser = JsonStreamParser(stream)

        value = await parser.get_number_property("value")
        assert value == 123
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_whole_json_as_single_chunk(self):
        """Test with whole JSON as single chunk."""
        json_text = '{"value":true,"count":2}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=len(json_text), interval=1)
        parser = JsonStreamParser(stream)

        value = await parser.get_boolean_property("value")
        count = await parser.get_number_property("count")

        assert value is True
        assert count == 2
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_many_properties_with_various_types(self):
        """Test many properties with various types."""
        json_text = '{"name":"Alice","age":30,"active":true,"score":null,"tags":["x"],"meta":{"ok":true}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10, interval=5)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("name")
        age = await parser.get_number_property("age")
        active = await parser.get_boolean_property("active")
        score = await parser.get_null_property("score")
        tags = await parser.get_list_property("tags")
        meta = await parser.get_map_property("meta")

        assert name == "Alice"
        assert age == 30
        assert active is True
        assert score is None
        assert tags == ["x"]
        assert meta == {"ok": True}
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_thinking_blocks_outside_json(self):
        """Test thinking blocks outside JSON."""
        json_text = '<think>reasoning</think>{"value":1}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        value = await parser.get_number_property("value")
        assert value == 1
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_malformed_inputs_edge_cases(self):
        """Test malformed inputs edge cases."""
        json_text = '{"nums":[1,2,]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream)

        nums = await parser.get_list_property("nums")
        assert nums == [1, 2]
        await parser.dispose()
