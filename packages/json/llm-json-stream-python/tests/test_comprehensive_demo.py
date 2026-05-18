"""Comprehensive test suite demonstrating chunk size and stream speed variations."""

import asyncio
import json as json_lib

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestComprehensiveChunkSizeAndSpeedMatrix:
    """Test various chunk sizes and speeds."""

    @pytest.mark.parametrize("chunk_size,speed", [
        (1, 0), (1, 5), (1, 50), (1, 100),
        (3, 0), (3, 5), (3, 50), (3, 100),
        (10, 0), (10, 5), (10, 50), (10, 100),
        (50, 0), (50, 5), (50, 50), (50, 100),
        (100, 0), (100, 5), (100, 50), (100, 100),
        (1000, 0), (1000, 5), (1000, 50), (1000, 100),
    ])
    @pytest.mark.asyncio
    async def test_chunk_size_and_speed_matrix(self, chunk_size, speed):
        """Test with various chunk sizes and speeds (milliseconds)."""
        json_text = '{"name":"Alice","age":30,"active":true}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=chunk_size,
            interval=speed,
        )
        
        parser = JsonStreamParser(stream)
        name_stream = parser.get_string_property("name")
        age_stream = parser.get_number_property("age")
        active_stream = parser.get_boolean_property("active")

        results = await asyncio.wait_for(
            asyncio.gather(name_stream, age_stream, active_stream),
            timeout=10,
        )

        assert results[0] == "Alice"
        assert results[1] == 30
        assert results[2] is True
        await parser.dispose()


class TestVisualDemonstrationOfBugScenario:
    """Visual demonstration of bug scenario."""

    @pytest.mark.asyncio
    async def test_demonstration_tiny_value_huge_chunk(self):
        """DEMONSTRATION: Tiny value, huge chunk."""
        json_text = '{"x":"a"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)
        x_stream = parser.get_string_property("x")

        event_count = 0

        async def collect():
            nonlocal event_count
            async for _ in x_stream:
                event_count += 1

        task = asyncio.create_task(collect())
        result = await asyncio.wait_for(x_stream, timeout=5)
        await task

        assert result == "a"
        assert event_count >= 1
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_demonstration_large_value_small_chunk(self):
        """DEMONSTRATION: Large value, small chunk."""
        json_text = '{"text":"hello world"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=1, interval=1)
        parser = JsonStreamParser(stream)
        text_stream = parser.get_string_property("text")

        chunks = [chunk async for chunk in text_stream]
        result = await text_stream

        assert "".join(chunks) == "hello world"
        assert result == "hello world"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_demonstration_normal_chunk(self):
        """DEMONSTRATION: Normal chunk size."""
        json_text = '{"value":"hello"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=1)
        parser = JsonStreamParser(stream)
        value_stream = parser.get_string_property("value")

        chunks = [chunk async for chunk in value_stream]
        result = await value_stream

        assert "".join(chunks) == "hello"
        assert result == "hello"
        await parser.dispose()


class TestApiDemoFlutterAppScenario:
    """Python equivalents for API demo tests in Dart."""

    @pytest.mark.parametrize(
        "chunk_size,interval",
        [
            (1, 5),
            (5, 10),
            (10, 10),
            (25, 10),
            (50, 10),
            (100, 5),
            (500, 0),
            (1000, 0),
        ],
    )
    @pytest.mark.asyncio
    async def test_futures_and_streams_match(self, chunk_size, interval):
        json_text = json_lib.dumps(
            {
                "name": "Sample Item",
                "description": "This is a very long description that could potentially span multiple lines and contain a lot of information about the item, including its features, benefits, and usage.",
                "tags": [
                    "sample tag 1 with some extra info",
                    "sample tag 2 with more details",
                    "sample tag 3 that is a bit longer",
                ],
                "details": {
                    "color": "red",
                    "size": "large",
                    "weight": "1.5kg",
                    "material": "plastic",
                },
                "status": "active",
            }
        )

        stream = stream_text_in_chunks(text=json_text, chunk_size=chunk_size, interval=interval)
        parser = JsonStreamParser(stream)

        name_stream = parser.get_string_property("name")
        description_stream = parser.get_string_property("description")
        color_stream = parser.get_string_property("details.color")
        size_stream = parser.get_string_property("details.size")
        weight_stream = parser.get_string_property("details.weight")
        material_stream = parser.get_string_property("details.material")
        status_stream = parser.get_string_property("status")

        stream_values = {
            "name": [],
            "description": [],
            "color": [],
            "size": [],
            "weight": [],
            "material": [],
            "status": [],
        }

        async def collect(stream_value, key):
            async for chunk in stream_value:
                stream_values[key].append(chunk)

        tasks = [
            asyncio.create_task(collect(name_stream, "name")),
            asyncio.create_task(collect(description_stream, "description")),
            asyncio.create_task(collect(color_stream, "color")),
            asyncio.create_task(collect(size_stream, "size")),
            asyncio.create_task(collect(weight_stream, "weight")),
            asyncio.create_task(collect(material_stream, "material")),
            asyncio.create_task(collect(status_stream, "status")),
        ]

        future_results = await asyncio.wait_for(
            asyncio.gather(
                name_stream,
                description_stream,
                color_stream,
                size_stream,
                weight_stream,
                material_stream,
                status_stream,
            ),
            timeout=30,
        )

        await asyncio.gather(*tasks)

        assert future_results[0] == "Sample Item"
        assert future_results[1].startswith("This is a very long description")
        assert future_results[2] == "red"
        assert future_results[3] == "large"
        assert future_results[4] == "1.5kg"
        assert future_results[5] == "plastic"
        assert future_results[6] == "active"

        assert "".join(stream_values["name"]) == future_results[0]
        assert "".join(stream_values["description"]) == future_results[1]
        assert "".join(stream_values["color"]) == future_results[2]
        assert "".join(stream_values["size"]) == future_results[3]
        assert "".join(stream_values["weight"]) == future_results[4]
        assert "".join(stream_values["material"]) == future_results[5]
        assert "".join(stream_values["status"]) == future_results[6]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_large_chunk_with_nested_properties(self):
        json_text = json_lib.dumps(
            {
                "details": {"color": "red", "weight": "1.5kg"}
            }
        )
        stream = stream_text_in_chunks(text=json_text, chunk_size=1000, interval=10)
        parser = JsonStreamParser(stream)

        color_stream = parser.get_string_property("details.color")
        weight_stream = parser.get_string_property("details.weight")

        color_chunks = [chunk async for chunk in color_stream]
        weight_chunks = [chunk async for chunk in weight_stream]

        results = await asyncio.wait_for(asyncio.gather(color_stream, weight_stream), timeout=5)

        assert results[0] == "red"
        assert results[1] == "1.5kg"
        assert "".join(color_chunks) == "red"
        assert "".join(weight_chunks) == "1.5kg"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_small_chunks_with_long_description(self):
        json_text = json_lib.dumps(
            {
                "description": "This is a very long description that could potentially span multiple lines and contain a lot of information about the item, including its features, benefits, and usage.",
            }
        )
        stream = stream_text_in_chunks(text=json_text, chunk_size=2, interval=1)
        parser = JsonStreamParser(stream)

        description_stream = parser.get_string_property("description")
        chunks = [chunk async for chunk in description_stream]
        result = await asyncio.wait_for(description_stream, timeout=10)

        assert "very long description" in result
        assert "".join(chunks) == result
        assert len(chunks) > 1
        await parser.dispose()
