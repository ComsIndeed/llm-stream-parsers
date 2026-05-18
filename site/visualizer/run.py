import os
import sys
import subprocess
import webbrowser
import time

def main():
    print("=" * 60)
    print("       LLM JSON Stream Parsers Visualizer Launcher")
    print("=" * 60)
    
    # 1. Check and install dependencies if missing
    try:
        import fastapi
        import uvicorn
    except ImportError:
        print("\nFastAPI or Uvicorn is missing. Automatically installing dependencies...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "fastapi", "uvicorn"])
            print("Successfully installed fastapi and uvicorn!\n")
            import fastapi
            import uvicorn
        except Exception as e:
            print(f"Error installing dependencies: {e}")
            print("Please run: pip install fastapi uvicorn")
            sys.exit(1)

    # 2. Get backend directories
    script_dir = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.join(script_dir, "backend")
    
    # 3. Print active host ports
    host = "127.0.0.1"
    port = 8000
    url = f"http://{host}:{port}"
    
    print(f"Starting FastAPI visualizer server at {url}...")
    
    # 4. Spawn browser shortly after server starts
    def open_browser():
        time.sleep(1.5)
        print(f"\nOpening visualizer page in your browser: {url}")
        webbrowser.open(url)

    # Use a thread or simple delayed process to open browser
    import threading
    threading.Thread(target=open_browser, daemon=True).start()

    # 5. Run uvicorn server in backend folder
    try:
        uvicorn.run("main:app", host=host, port=port, reload=True, app_dir=backend_dir)
    except KeyboardInterrupt:
        print("\nVisualizer server stopped gracefully. Have a great day!")

if __name__ == "__main__":
    main()
