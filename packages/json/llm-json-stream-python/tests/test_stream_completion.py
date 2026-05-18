"""Stream completion tests."""

import pytest
from llm_json_stream import JsonStreamParser, ParseEventType
from tests.utils.stream_utils import stream_text_in_chunks


class TestStreamCompletion:
    """Stream completion test suite."""

    @pytest.mark.asyncio
    async def test_stream_completes_normally(self):
        """Test stream completes normally."""
        json_text = '{"name":"Alice"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=20, interval=1)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("name")
        assert name == "Alice"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_stream_completes_with_remaining_data(self):
        """Test stream completes with remaining buffered data."""
        json_text = '{"value":42} trailing text'
        stream = stream_text_in_chunks(text=json_text, chunk_size=10, interval=1)
        parser = JsonStreamParser(stream, close_on_root_complete=True)

        value = await parser.get_number_property("value")
        assert value == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_completion_events_fire(self):
        """Test completion events fire."""
        events = []
        json_text = '{"value":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=1)
        parser = JsonStreamParser(stream, on_log=events.append)

        await parser.get_boolean_property("value")
        await parser.dispose()

        assert any(event.type == ParseEventType.PROPERTY_COMPLETE for event in events)
        assert any(event.type == ParseEventType.ROOT_COMPLETE for event in events)

    @pytest.mark.asyncio
    async def test_future_resolves_on_completion(self):
        """Test future resolves on stream completion."""
        json_text = '{"score":100}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=1)
        parser = JsonStreamParser(stream)

        score_stream = parser.get_number_property("score")
        score = await score_stream
        assert score == 100
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_completions(self):
        """Test multiple stream completions."""
        json_text = '{"name":"Bob","age":25,"active":true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=50, interval=1)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        age_stream = parser.get_number_property("age")
        active_stream = parser.get_boolean_property("active")

        name, age, active = await name_stream, await age_stream, await active_stream
        assert name == "Bob"
        assert age == 25
        assert active is True
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_early_termination(self):
        """Test early stream termination."""
        json_text = '{"value": "test"'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=1)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_string_property("value")
        with pytest.raises(RuntimeError):
            await value_stream
        await parser.dispose()
