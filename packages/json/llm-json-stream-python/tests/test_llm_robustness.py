"""LLM robustness tests."""

import pytest
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks


class TestLLMRobustness:
    """LLM robustness test suite."""

    @pytest.mark.asyncio
    async def test_realistic_llm_response_1(self):
        """Test realistic LLM response 1."""
        json_text = """Here is the JSON data you requested:
```json
{"name":"Alice","age":30}
```"""
        stream = stream_text_in_chunks(text=json_text, chunk_size=10, interval=5)
        parser = JsonStreamParser(stream)

        name = await parser.get_string_property("name")
        age = await parser.get_number_property("age")

        assert name == "Alice"
        assert age == 30
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_realistic_llm_response_2(self):
        """Test realistic LLM response 2."""
                json_text = """<think>
Planning response
</think>

```json
{
    "products": [
        {"id": 1, "name": "Widget", "price": 29.99,},
        {"id": 2, "name": "Gadget", "price": 49.99,},
    ],
    "total": 2,
}
```"""
                stream = stream_text_in_chunks(text=json_text, chunk_size=20, interval=5)
                parser = JsonStreamParser(stream, skip_thoughts=True)

                total = await parser.get_number_property("total")
                first_name = await parser.get_string_property("products[0].name")
                second_price = await parser.get_number_property("products[1].price")

                assert total == 2
                assert first_name == "Widget"
                assert second_price == 49.99
                await parser.dispose()

    @pytest.mark.asyncio
    async def test_realistic_llm_response_3(self):
        """Test realistic LLM response 3."""
        json_text = """Result:
```json
{"status":"success","data":[1,2,3,],}
```"""
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream)

        status = await parser.get_string_property("status")
        data = await parser.get_list_property("data")

        assert status == "success"
        assert data == [1, 2, 3]
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_llm_with_malformed_json(self):
        """Test LLM with malformed JSON."""
        json_text = """Here is the output:
```json
{"value": 123
```"""
        stream = stream_text_in_chunks(text=json_text, chunk_size=8, interval=5)
        parser = JsonStreamParser(stream)

        value_stream = parser.get_number_property("value")
        with pytest.raises(RuntimeError):
            await value_stream
        await parser.dispose()

    @pytest.mark.asyncio
    async def test_llm_with_mixed_thinking_and_json(self):
        """Test LLM with mixed thinking and JSON."""
        json_text = """<think>Reasoning steps</think>
{"ready":true}"""
        stream = stream_text_in_chunks(text=json_text, chunk_size=6, interval=5)
        parser = JsonStreamParser(stream, skip_thoughts=True)

        ready = await parser.get_boolean_property("ready")
        assert ready is True
        await parser.dispose()
