import shutil
import os

def check_runtimes(workspace_root: str, format_type: str = "json"):
    format_type = format_type.lower()
    packages_dir = os.path.join(workspace_root, "packages", format_type)
    
    # Define how to detect each SDK
    sdk_checks = {
        "python": "python",
        "dart": "dart",
        "typescript": "node",
        "csharp": "dotnet",
        "kotlin": "java"  # or kotlinc
    }
    
    # Check if directories exist and have actual files (more than just .gitkeep)
    status = {}
    for lang, sdk_cmd in sdk_checks.items():
        # Map directory name
        if lang == "dart":
            dir_name = f"llm_{format_type}_stream_dart"
        elif lang == "typescript":
            dir_name = f"llm-{format_type}-stream-ts"
        else:
            dir_name = f"llm-{format_type}-stream-{lang}"
            
        lang_path = os.path.join(packages_dir, dir_name)
        
        # Check if folder exists
        exists = os.path.exists(lang_path)
        is_implemented = False
        
        if exists:
            # Check if it has actual code files (more than just .gitkeep)
            files = [f for f in os.listdir(lang_path) if f != ".gitkeep" and not f.startswith(".")]
            is_implemented = len(files) > 0

        # Check if SDK command is in system PATH
        sdk_installed = shutil.which(sdk_cmd) is not None
        if lang == "python":
            sdk_installed = shutil.which("python") is not None or shutil.which("python3") is not None
            
        # Determine human-friendly status
        available = is_implemented and sdk_installed
        
        reason = None
        if not exists or not is_implemented:
            reason = "Not implemented yet (placeholder)"
        elif not sdk_installed:
            reason = f"SDK not installed locally (cmd '{sdk_cmd}' not found)"
            
        status[lang] = {
            "name": lang.capitalize() if lang != "csharp" else "C#",
            "available": available,
            "implemented": is_implemented,
            "sdkInstalled": sdk_installed,
            "reason": reason
        }
        
    return status
