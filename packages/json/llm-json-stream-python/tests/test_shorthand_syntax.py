"""Shorthand syntax tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestShorthandSyntax:
    """Shorthand syntax test suite."""

    @pytest.mark.asyncio
    async def test_dot_notation_properties(self):
        """Test dot notation for nested properties."""
        json_text = '{"user":{"name":"Bob","age":25}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream)

        name = await parser.str("user.name")
        age = await parser.number("user.age")

        assert name == "Bob"
        assert age == 25
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_array_index_access(self):
        """Test array index access."""
        json_text = '{"items":[1,2,3]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream)

        second = await parser.number("items[1]")

        assert second == 2
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_complex_path_expressions(self):
        """Test complex path expressions."""
        json_text = '{"users":[{"profile":{"name":"Alice"}},{"profile":{"name":"Bob"}}]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=5)
        parser = JsonStreamParser(stream)

        first = await parser.str("users[0].profile.name")
        second = await parser.str("users[1].profile.name")

        assert first == "Alice"
        assert second == "Bob"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_shorthand_with_special_characters(self):
        """Test shorthand with special characters in property names."""
        json_text = '{"user-name":"value","user_name":"ok"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        hyphen_value = await parser.str("user-name")
        underscore_value = await parser.str("user_name")

        assert hyphen_value == "value"
        assert underscore_value == "ok"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_levels_of_nesting(self):
        """Test multiple levels of nesting."""
        json_text = '{"a":{"b":{"c":[{"d":"deep"}]}}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        value = await parser.str("a.b.c[0].d")
        assert value == "deep"
        await parser.dispose()
