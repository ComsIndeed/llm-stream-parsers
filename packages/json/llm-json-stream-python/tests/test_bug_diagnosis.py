"""Tests for bug diagnosis and debugging scenarios.

Combines tests from both bug_diagnosis_test.dart (4 tests) and bug_diagnosis.test.ts (9 tests).
"""

import asyncio
import json as json_lib

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestBugDiagnosisChunk25:
    """Bug diagnosis tests from Dart."""

    @pytest.mark.asyncio
    async def test_reproduce_bug_with_minimal_json(self):
        """Reproduce bug with minimal JSON."""
        json_text = json_lib.dumps({"tags": ["more details"], "key": "value"})

        for chunk_size in [10, 15, 20, 25, 30]:
            stream = stream_text_in_chunks(text=json_text, chunk_size=chunk_size, interval=10)
            parser = JsonStreamParser(stream)
            key_stream = parser.get_string_property("key")

            result = await asyncio.wait_for(key_stream, timeout=2)
            assert result == "value"
            await parser.dispose()

    @pytest.mark.asyncio
    async def test_exact_reproduction_chunk_boundary_in_list_string(self):
        """Exact reproduction - chunk boundary in list string."""
        json_text = '{"tags":["sample details"],"key":"val"}'
        stream = stream_text_in_chunks(text=json_text, chunk_size=15, interval=10)
        parser = JsonStreamParser(stream)
        key_stream = parser.get_string_property("key")

        result = await asyncio.wait_for(key_stream, timeout=2)
        assert result == "val"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_actual_failing_json_with_chunk_25(self):
        """Test the actual failing JSON with chunk 25."""
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

        stream = stream_text_in_chunks(text=json_text, chunk_size=25, interval=10)
        parser = JsonStreamParser(stream)
        color_stream = parser.get_string_property("details.color")

        result = await asyncio.wait_for(color_stream, timeout=5)
        assert result == "red"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_concluding_test_for_the_bug(self):
        """Concluding test for the bug."""
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

        stream = stream_text_in_chunks(text=json_text, chunk_size=25, interval=100)
        parser = JsonStreamParser(stream)

        color_stream = parser.get_string_property("details.color")
        size_stream = parser.get_string_property("details.size")
        weight_stream = parser.get_string_property("details.weight")
        material_stream = parser.get_string_property("details.material")

        stream_color = []
        stream_size = []
        stream_weight = []
        stream_material = []

        async def collect(stream, target):
            async for chunk in stream:
                target.append(chunk)

        tasks = [
            asyncio.create_task(collect(color_stream, stream_color)),
            asyncio.create_task(collect(size_stream, stream_size)),
            asyncio.create_task(collect(weight_stream, stream_weight)),
            asyncio.create_task(collect(material_stream, stream_material)),
        ]

        futures = await asyncio.wait_for(
            asyncio.gather(color_stream, size_stream, weight_stream, material_stream),
            timeout=5,
        )

        await asyncio.gather(*tasks)

        assert "".join(stream_color) == "red"
        assert "".join(stream_size) == "large"
        assert "".join(stream_weight) == "1.5kg"
        assert "".join(stream_material) == "plastic"
        assert futures == ["red", "large", "1.5kg", "plastic"]
        await parser.dispose()


class TestBugDiagnosisFromTypeScript:
    """Bug diagnosis tests from TypeScript."""

    @pytest.mark.asyncio
    async def test_diagnose_property_not_completing(self):
        """Diagnose: property not completing."""
        json_text = '{"value":42}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=5,
            interval=50,  # Longer delay
        )

        parser = JsonStreamParser(stream)
        value_stream = parser.get_number_property("value")
        result = await asyncio.wait_for(value_stream, timeout=2)
        assert result == 42
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_diagnose_stream_events_not_firing(self):
        """Diagnose: stream events not firing."""
        json_text = '{"text":"Hello World"}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=8,
            interval=10,
        )

        parser = JsonStreamParser(stream)
        text_stream = parser.get_string_property("text")
        chunks = [chunk async for chunk in text_stream]
        final_value = await text_stream
        assert "".join(chunks) == "Hello World"
        assert final_value == "Hello World"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_diagnose_incorrect_value_parsing(self):
        """Diagnose: incorrect value parsing."""
        json_text = '{"int":42,"float":3.14,"neg":-10,"sci":1e5}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=15,
            interval=10,
        )

        parser = JsonStreamParser(stream)
        int_stream = parser.get_number_property("int")
        float_stream = parser.get_number_property("float")
        neg_stream = parser.get_number_property("neg")
        sci_stream = parser.get_number_property("sci")

        results = await asyncio.gather(int_stream, float_stream, neg_stream, sci_stream)
        assert results == [42, 3.14, -10, 1e5]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_diagnose_memory_leak_in_callbacks(self):
        """Diagnose: memory leak in callbacks."""
        json_text = '{"list":[1,2,3,4,5]}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=8,
            interval=10,
        )

        parser = JsonStreamParser(stream)
        list_stream = parser.get_list_property("list")

        seen: list[int] = []

        def on_element(element, index):
            element.on_value(lambda value: seen.append(value))

        list_stream.on_element(on_element)
        result = await list_stream
        assert result == [1, 2, 3, 4, 5]
        assert seen == [1, 2, 3, 4, 5]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_diagnose_race_condition_in_async_operations(self):
        """Diagnose: race condition in async operations."""
        json_text = '{"a":1,"b":2,"c":3}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=7,
            interval=10,
        )

        parser = JsonStreamParser(stream)
        a_stream = parser.get_number_property("a")
        b_stream = parser.get_number_property("b")
        c_stream = parser.get_number_property("c")

        results = await asyncio.gather(a_stream, b_stream, c_stream)
        assert results == [1, 2, 3]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_diagnose_chunk_boundary_issues(self):
        """Diagnose: chunk boundary issues."""
        json_text = '{"longPropertyName":"longPropertyValue"}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=10,  # Will split property name and value
            interval=10,
        )

        parser = JsonStreamParser(stream)
        prop_stream = parser.get_string_property("longPropertyName")
        assert await prop_stream == "longPropertyValue"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_diagnose_escaped_characters_in_strings(self):
        """Diagnose: escaped characters in strings."""
        json_text = '{"path":"C:\\\\Users\\\\test\\\\file.txt"}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=12,
            interval=10,
        )

        parser = JsonStreamParser(stream)
        path_stream = parser.get_string_property("path")
        assert await path_stream == "C:\\Users\\test\\file.txt"
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_diagnose_nested_access_before_parent_completes(self):
        """Diagnose: nested access before parent completes."""
        json_text = '{"parent":{"child":"value"},"other":"data"}'
        
        stream = stream_text_in_chunks(
            text=json_text,
            chunk_size=15,
            interval=10,
        )

        parser = JsonStreamParser(stream)
        parent_stream = parser.get_map_property("parent")
        child_stream = parser.get_string_property("parent.child")
        other_stream = parser.get_string_property("other")

        results = await asyncio.gather(parent_stream, child_stream, other_stream)
        assert results[1] == "value"
        assert results[2] == "data"
        await parser.dispose()
