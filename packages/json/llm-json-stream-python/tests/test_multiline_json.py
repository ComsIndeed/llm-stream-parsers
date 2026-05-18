"""Multiline JSON tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestMultilineJSON:
    """Multiline JSON test suite."""

    @pytest.mark.asyncio
    async def test_json_with_newlines(self):
        """Test JSON with newlines."""
        json_text = """
{
    "name": "Alice",
    "age": 30
}
"""
        stream = stream_text_in_chunks(text=json_text, chunk_size=1, interval=1)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("name")
        age = await parser.get_number_property("age")

        assert name == "Alice"
        assert age == 30
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_json_with_multiline_strings(self):
        """Test JSON with multiline strings."""
        json_text = r'{"text":"Line1\nLine2"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=1)
        parser = JsonStreamParser(stream)

        text = await parser.get_string_property("text")
        assert text == "Line1\nLine2"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_json_with_various_whitespace(self):
        """Test JSON with various whitespace."""
        json_text = "\n\n  \t  {\"name\": \"Charlie\", \"value\": 42}"
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=1)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("name")
        value = await parser.get_number_property("value")

        assert name == "Charlie"
        assert value == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_json_with_indentation(self):
        """Test JSON with indentation."""
        json_text = """
{
    "user": {
        "profile": {
            "name": "Bob",
            "email": "bob@example.com"
        }
    }
}
"""
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=1)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("user.profile.name")
        email = await parser.get_string_property("user.profile.email")

        assert name == "Bob"
        assert email == "bob@example.com"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_json_without_whitespace(self):
        """Test minified JSON without whitespace."""
        json_text = '{"name":"Dana","active":true,"score":99}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10, interval=1)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("name")
        active = await parser.get_boolean_property("active")
        score = await parser.get_number_property("score")

        assert name == "Dana"
        assert active is True
        assert score == 99
        await parser.dispose()
