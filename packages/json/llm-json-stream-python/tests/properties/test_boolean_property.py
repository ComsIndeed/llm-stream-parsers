"""Boolean property tests."""

import asyncio

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestBooleanProperty:
    """Boolean property test suite."""

    @pytest.mark.asyncio
    async def test_true_value(self):
        """Test true value."""
        json_text = '{"active":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=3, interval=10)
        parser = JsonStreamParser(stream)

        active_stream = parser.get_boolean_property("active")
        emitted = [value async for value in active_stream]
        final_value = await active_stream

        assert emitted == [True]
        assert final_value is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_false_value(self):
        """Test false value."""
        json_text = '{"disabled":false}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        disabled_stream = parser.get_boolean_property("disabled")
        emitted = [value async for value in disabled_stream]
        final_value = await disabled_stream

        assert emitted == [False]
        assert final_value is False
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_true_split_across_chunks(self):
        """Test true value split across chunks."""
        json_text = '{"flag":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream)

        flag_stream = parser.get_boolean_property("flag")
        emitted = [value async for value in flag_stream]
        final_value = await flag_stream

        assert emitted == [True]
        assert final_value is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_false_split_across_chunks(self):
        """Test false value split across chunks."""
        json_text = '{"flag":false}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=5)
        parser = JsonStreamParser(stream)

        flag_stream = parser.get_boolean_property("flag")
        emitted = [value async for value in flag_stream]
        final_value = await flag_stream

        assert emitted == [False]
        assert final_value is False
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_boolean_properties(self):
        """Test multiple boolean properties."""
        json_text = '{"flag1":true,"flag2":false,"flag3":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        flag1_stream = parser.get_boolean_property("flag1")
        flag2_stream = parser.get_boolean_property("flag2")
        flag3_stream = parser.get_boolean_property("flag3")

        flag1 = await flag1_stream
        flag2 = await flag2_stream
        flag3 = await flag3_stream

        assert flag1 is True
        assert flag2 is False
        assert flag3 is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_boolean_in_nested_object(self):
        """Test boolean in nested object."""
        json_text = '{"settings":{"enabled":true}}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        enabled_stream = parser.get_boolean_property("settings.enabled")
        emitted = [value async for value in enabled_stream]
        final_value = await enabled_stream

        assert emitted == [True]
        assert final_value is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_boolean_in_array(self):
        """Test boolean in array."""
        json_text = '{"flags":[true,false]}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=10)
        parser = JsonStreamParser(stream)

        first_stream = parser.get_boolean_property("flags[0]")
        second_stream = parser.get_boolean_property("flags[1]")

        assert await first_stream is True
        assert await second_stream is False
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_invalid_boolean_value(self):
        """Test invalid boolean value."""
        json_text = '{"flag":truish}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
        parser = JsonStreamParser(stream)

        flag_stream = parser.get_boolean_property("flag")
        with pytest.raises(RuntimeError):
            await flag_stream
        await parser.dispose()
