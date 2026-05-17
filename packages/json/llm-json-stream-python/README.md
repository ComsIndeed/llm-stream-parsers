# llm-json-stream-python

A native Python library for parsing JSON streams with support for early value
retrieval.

## Installation

```bash
pip install .
```

## Features

- Native Python `AsyncIterable` support.
- Dual-behavior objects (Awaitable and AsyncIterable).
- Zero production dependencies.

## Quick start

```python
from llm_json_stream import JsonStreamParser

async def main(stream_from_llm):
	parser = JsonStreamParser(stream_from_llm)

	# Stream partial chunks
	async for chunk in parser.get_string_property("user.name"):
		print("Name chunk:", chunk)

	# Await complete values
	age = await parser.get_number_property("user.age")
	print("Age:", age)
```
