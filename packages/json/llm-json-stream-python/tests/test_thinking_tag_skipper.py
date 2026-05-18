"""Thinking tag skipper tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestThinkingTagSkipperBasicFunctionality:
    """Basic thinking tag skipper functionality tests."""

    @pytest.mark.asyncio
    async def test_skip_content_inside_think_tags(self):
        """Test skipping content inside default think tags."""
        json_text = '<think>Reasoning...</think>{"name":"Alice"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        name = await parser.get_string_property("name")
        assert name == "Alice"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_skip_content_inside_custom_tags(self):
        """Test skipping content inside custom tags."""
        json_text = '[thought]Processing[/thought]{"value":42}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(
            stream,
            skip_thoughts=True,
            thinking_tags=("[thought]", "[/thought]"),
        )

        value = await parser.get_number_property("value")
        assert value == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_handle_json_without_thinking_tags(self):
        """Test handling JSON without any thinking tags."""
        json_text = '{"status":"ok","count":5}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        status = await parser.get_string_property("status")
        count = await parser.get_number_property("count")

        assert status == "ok"
        assert count == 5
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_thinking_blocks(self):
        """Test multiple thinking blocks."""
        json_text = '<think>First</think><think>Second</think>{"result":"success"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        result = await parser.get_string_property("result")
        assert result == "success"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_thinking_blocks_with_tags_inside_json_strings(self):
        """Test thinking blocks with tags inside JSON string values."""
        json_text = '{"text":"<think>not a tag</think>"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=False)

        text = await parser.get_string_property("text")
        assert text == "<think>not a tag</think>"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_empty_thinking_blocks(self):
        """Test empty thinking blocks."""
        json_text = '<think></think>{"value":42}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        value = await parser.get_number_property("value")
        assert value == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_nested_thinking_blocks(self):
        """Test nested thinking blocks."""
        json_text = '<think>Outer <think>Inner</think> Outer</think>{"value":1}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        value = await parser.get_number_property("value")
        assert value == 1
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_malformed_thinking_blocks(self):
        """Test malformed thinking blocks."""
        json_text = '<think>Unclosed block {"value":1}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        value_stream = parser.get_number_property("value")
        with pytest.raises(RuntimeError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_thinking_blocks_split_across_chunks(self):
        """Test thinking blocks split across chunks."""
        json_text = '<think>Reasoning</think>{"value":2}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        value = await parser.get_number_property("value")
        assert value == 2
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_thinking_tag_case_sensitivity(self):
        """Test thinking tag case sensitivity."""
        json_text = '<THINK>Uppercase</THINK>{"value":3}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        value = await parser.get_number_property("value")
        assert value == 3
        await parser.dispose()
