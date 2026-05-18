import sys
import os
import json
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware

# Add parent directory to path to find runtimes.py
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from runtimes import check_runtimes

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Resolve paths
WORKSPACE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FRONTEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend"))

# Define standard format test payloads
PAYLOADS = {
    "json": {
        "value": '{\n  "name": "Alice",\n  "age": 30,\n  "active": true\n}',
        "config": {
            "name": "string",
            "age": "number",
            "active": "boolean"
        }
    },
    "xml": {
        "value": '<user>\n  <name>Alice</name>\n  <age>30</age>\n  <active>true</active>\n</user>',
        "config": {
            "user.name": "string",
            "user.age": "number",
            "user.active": "boolean"
        }
    },
    "yaml": {
        "value": 'name: Alice\nage: 30\nactive: true\n',
        "config": {
            "name": "string",
            "age": "number",
            "active": "boolean"
        }
    }
}

@app.get("/api/runtimes")
async def get_runtimes(format_type: str = "json"):
    return check_runtimes(WORKSPACE_ROOT, format_type)

@app.get("/api/payloads")
async def get_payloads():
    # Return format configurations list for UI tab button initialization
    return {
        key: {
            "name": key.upper(),
            "raw": val["value"],
            "config": val["config"]
        }
        for key, val in PAYLOADS.items()
    }

# WebSocket for streaming tests
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    
    try:
        while True:
            # Wait for message from client
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message.get("action") == "start":
                language = message.get("language")
                payload_id = message.get("payload_id", "basic")
                chunk_size = int(message.get("chunk_size", 5))
                delay_ms = int(message.get("delay_ms", 50))
                
                # Fetch payload
                payload = PAYLOADS.get(payload_id)
                if not payload:
                    await websocket.send_json({"event": "status", "state": "error", "message": f"Payload '{payload_id}' not found"})
                    continue
                
                # Verify runtime is available
                runtimes = check_runtimes(WORKSPACE_ROOT, payload_id)
                lang_status = runtimes.get(language)
                if not lang_status or not lang_status["available"]:
                    reason = lang_status["reason"] if lang_status else "Unknown language"
                    await websocket.send_json({"event": "status", "state": "error", "message": f"Language '{language}' is not available: {reason}"})
                    continue

                await websocket.send_json({"event": "status", "state": "running", "message": f"Spawning {lang_status['name']} process..."})
                
                # Run the selected language runner process
                process = None
                try:
                    if language == "python":
                        runner_path = os.path.join(WORKSPACE_ROOT, "site", "visualizer", "runners", "run_python.py")
                        process = await asyncio.create_subprocess_exec(
                            sys.executable, runner_path,
                            stdin=asyncio.subprocess.PIPE,
                            stdout=asyncio.subprocess.PIPE,
                            stderr=asyncio.subprocess.PIPE
                        )
                    elif language == "dart":
                        runner_path = os.path.join(WORKSPACE_ROOT, "packages", "json", "llm_json_stream_dart", "example", "visualizer_runner.dart")
                        process = await asyncio.create_subprocess_exec(
                            "dart", "run", runner_path,
                            stdin=asyncio.subprocess.PIPE,
                            stdout=asyncio.subprocess.PIPE,
                            stderr=asyncio.subprocess.PIPE
                        )
                    elif language == "typescript":
                        runner_dir = os.path.join(WORKSPACE_ROOT, "packages", "json", "llm-json-stream-ts", "packages", "llm-json-stream")
                        # Run tsx inside the package folder to resolve dependencies
                        npx_bin = "npx.cmd" if sys.platform == "win32" else "npx"
                        process = await asyncio.create_subprocess_exec(
                            npx_bin, "tsx", "examples/visualizer_runner.ts",
                            cwd=runner_dir,
                            stdin=asyncio.subprocess.PIPE,
                            stdout=asyncio.subprocess.PIPE,
                            stderr=asyncio.subprocess.PIPE
                        )
                        
                except Exception as e:
                    await websocket.send_json({"event": "status", "state": "error", "message": f"Failed to start subprocess: {e}"})
                    continue

                if not process:
                    await websocket.send_json({"event": "status", "state": "error", "message": "Failed to spawn runner process"})
                    continue

                # 1. Send properties config as the first line of stdin
                config_line = json.dumps(payload["config"]) + "\n"
                process.stdin.write(config_line.encode())
                await process.stdin.drain()
                
                # Create a task to read stdout from the subprocess in real-time
                async def pipe_stdout():
                    try:
                        while True:
                            line_bytes = await process.stdout.readline()
                            if not line_bytes:
                                break
                            line = line_bytes.decode().strip()
                            if not line:
                                continue
                            try:
                                event_data = json.loads(line)
                                # Forward parser events directly to the browser
                                await websocket.send_json(event_data)
                            except Exception:
                                # Non-JSON output (e.g. print statements, stderr, logs)
                                await websocket.send_json({"event": "stdout_log", "data": line})
                    except asyncio.CancelledError:
                        pass
                    except Exception as e:
                        print(f"Stdout pipe exception: {e}")

                stdout_task = asyncio.create_task(pipe_stdout())
                
                # 2. Stream the JSON payload character/chunk by character to subprocess stdin
                # and send raw_chunk events to the browser in real-time
                try:
                    text_to_stream = payload["value"]
                    for i in range(0, len(text_to_stream), chunk_size):
                        chunk = text_to_stream[i : i + chunk_size]
                        
                        # Write to process stdin
                        process.stdin.write(chunk.encode())
                        await process.stdin.drain()
                        
                        # Send raw chunk to browser (so it visualizes the incoming stream)
                        await websocket.send_json({"event": "raw_chunk", "data": chunk})
                        
                        # Configurable stream interval
                        if delay_ms > 0:
                            await asyncio.sleep(delay_ms / 1000.0)
                            
                    # Close stdin to signal end of stream
                    process.stdin.close()
                    await process.stdin.wait_closed()
                except Exception as e:
                    await websocket.send_json({"event": "status", "state": "error", "message": f"Stream write failed: {e}"})
                    
                # Wait for subprocess to finish and flush remaining stdout
                await process.wait()
                await stdout_task
                
                # Capture stderr if exit code is non-zero
                if process.returncode != 0:
                    err_bytes = await process.stderr.read()
                    err_msg = err_bytes.decode().strip()
                    await websocket.send_json({
                        "event": "status",
                        "state": "error",
                        "message": f"Runner exited with code {process.returncode}. Error: {err_msg}"
                    })
                else:
                    await websocket.send_json({
                        "event": "status",
                        "state": "completed",
                        "message": f"Native parser completed successfully."
                    })
                    
    except WebSocketDisconnect:
        print("Client disconnected")
    except Exception as e:
        print(f"WS error: {e}")

# Mount static frontend directory
if os.path.exists(FRONTEND_DIR):
    app.mount("/", StaticFiles(directory=FRONTEND_DIR, html=True), name="frontend")
else:
    @app.get("/")
    async def fallback():
        return HTMLResponse("<h1>Visualizer frontend folder not found!</h1>")
