import asyncio
from llm_json_stream import JsonStreamParser
from tests.utils.stream_utils import stream_text_in_chunks

async def main():
    json_text = '{"flag":truish}'
    stream = stream_text_in_chunks(text=json_text, chunk_size=5, interval=10)
    parser = JsonStreamParser(stream)
    flag_stream = parser.get_boolean_property('flag')
    try:
        val = await flag_stream
        print('SUCCESSFULLY COMPLETED WITH VALUE:', val)
    except Exception as e:
        print('EXCEPTION RAISED:', type(e), str(e))
    await parser.dispose()

asyncio.run(main())
