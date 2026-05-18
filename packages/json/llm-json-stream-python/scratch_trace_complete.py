import asyncio
from llm_json_stream import JsonStreamParser

async def main():
    json_text = '{"value": "test"'
    print("JSON_TEXT IS:", repr(json_text), list(json_text))
    stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=1)
    parser = JsonStreamParser(stream)
    value_stream = parser.get_string_property('value')
    try:
        val = await value_stream
        print('SUCCESSFULLY COMPLETED WITH VALUE:', val)
    except Exception as e:
        print('EXCEPTION RAISED:', type(e), str(e))
    await parser.dispose()

from tests.utils.stream_utils import stream_text_in_chunks
asyncio.run(main())
