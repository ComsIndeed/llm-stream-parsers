import sys
import os
import json
import asyncio

# Add python package src directory to path
workspace_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
python_src = os.path.join(workspace_root, "packages", "json", "llm-json-stream-python", "src")
sys.path.insert(0, python_src)

from llm_json_stream import JsonStreamParser, ParseEvent

# Force unbuffered output for real-time stdout piping
sys.stdout.reconfigure(line_buffering=True)

def parse_event_to_dict(event: ParseEvent) -> dict:
    # Serialize event data gracefully
    data = None
    if event.data is not None:
        if isinstance(event.data, Exception):
            data = str(event.data)
        else:
            data = event.data
            
    return {
        "event": "parser_event",
        "type": event.type.name,
        "propertyPath": event.property_path,
        "message": event.message,
        "data": data
    }

async def main():
    loop = asyncio.get_event_loop()
    
    # 1. Read first line (properties config JSON)
    config_line = await loop.run_in_executor(None, sys.stdin.readline)
    if not config_line:
        return
        
    try:
        config = json.loads(config_line.strip())
    except Exception as e:
        print(json.dumps({"event": "status", "state": "error", "message": f"Invalid config: {e}"}))
        return

    # Create stdin character generator
    async def stdin_char_stream():
        while True:
            char = await loop.run_in_executor(None, sys.stdin.read, 1)
            if not char:
                break
            yield char

    # Callback for parser events
    def on_log(event: ParseEvent):
        # Print event as JSON line
        print(json.dumps(parse_event_to_dict(event)), flush=True)

    # Initialize parser
    parser = JsonStreamParser(stdin_char_stream(), on_log=on_log)

    # 2. Pre-register all properties based on config to arm the property controllers
    for path, prop_type in config.items():
        try:
            if prop_type == "string":
                parser.get_string_property(path)
            elif prop_type == "number":
                parser.get_number_property(path)
            elif prop_type == "boolean":
                parser.get_boolean_property(path)
            elif prop_type == "null":
                parser.get_null_property(path)
            elif prop_type == "object":
                parser.get_map_property(path)
            elif prop_type == "array":
                parser.get_list_property(path)
        except Exception as e:
            print(json.dumps({"event": "status", "state": "error", "message": f"Failed to register {path}: {e}"}))

    # 3. Wait for parser to consume the entire stdin stream
    # The parser has a consume task running in the background. We await it to complete.
    await parser._consume_task
    await parser.dispose()

if __name__ == "__main__":
    asyncio.run(main())
