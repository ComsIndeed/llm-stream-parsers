"""Observability tests."""

import pytest
from llm_json_stream import JsonStreamParser, ParseEventType, ParseEvent
from tests.utils.stream_utils import stream_text_in_chunks


class TestObservability:
    """Observability and event tracking test suite."""

    @pytest.mark.asyncio
    async def test_stream_events_firing(self):
        """Test that stream events fire correctly."""
        events: list[ParseEvent] = []
        json_text = '{"name": "test"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream, on_log=events.append)

        await parser.get_map_property("")
        await parser.dispose()

        assert any(event.type == ParseEventType.ROOT_START for event in events)
        assert any(event.type == ParseEventType.ROOT_COMPLETE for event in events)

    @pytest.mark.asyncio
    async def test_chunk_emission_tracking(self):
        """Test chunk emission tracking."""
        events: list[ParseEvent] = []
        json_text = '{"text": "Hello World"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=5)
        parser = JsonStreamParser(stream, on_log=events.append)

        text_stream = parser.get_string_property("text")
        await text_stream
        await parser.dispose()

        assert any(
            event.type == ParseEventType.STRING_CHUNK and event.property_path == "text"
            for event in events
        )

    @pytest.mark.asyncio
    async def test_completion_events(self):
        """Test completion events."""
        events: list[ParseEvent] = []
        json_text = '{"value": 1}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream, on_log=events.append)

        await parser.get_number_property("value")
        await parser.dispose()

        assert any(event.type == ParseEventType.PROPERTY_COMPLETE for event in events)
        assert any(event.type == ParseEventType.ROOT_COMPLETE for event in events)

    @pytest.mark.asyncio
    async def test_error_events(self):
        """Test error events."""
        events: list[ParseEvent] = []
        json_text = '{"value": "oops"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream, on_log=events.append)

        value_stream = parser.get_number_property("value")
        with pytest.raises(ValueError):
            await value_stream

        assert any(event.type == ParseEventType.ERROR for event in events)
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_multiple_listeners(self):
        """Test multiple listeners on same stream."""
        events_a: list[ParseEvent] = []
        events_b: list[ParseEvent] = []

        def log_event(event: ParseEvent) -> None:
            events_a.append(event)
            events_b.append(event)

        json_text = '{"value": true}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=5)
        parser = JsonStreamParser(stream, on_log=log_event)

        await parser.get_boolean_property("value")
        await parser.dispose()

        assert len(events_a) > 0
        assert len(events_b) > 0

    @pytest.mark.asyncio
    async def test_event_ordering(self):
        """Test event ordering."""
        events: list[ParseEvent] = []
        json_text = '{"name": "Alice"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=4, interval=5)
        parser = JsonStreamParser(stream, on_log=events.append)

        await parser.get_map_property("")
        await parser.dispose()

        root_start_index = next(
            i for i, event in enumerate(events) if event.type == ParseEventType.ROOT_START
        )
        root_complete_index = next(
            i
            for i, event in enumerate(events)
            if event.type == ParseEventType.ROOT_COMPLETE
        )

        assert root_start_index < root_complete_index
