import subprocess
import sys
from pathlib import Path

PROJECT_FOLDER = Path(r"C:\Users\S FRANKLIN SURYA\Downloads\Data-Engineering-Python\py_de_ai_project")

FOLDERS = [
    PROJECT_FOLDER / "script",
    PROJECT_FOLDER / "landing",
    PROJECT_FOLDER / "data" / "archive",
    PROJECT_FOLDER / "data" / "error",
    PROJECT_FOLDER / "data" / "processing",
    PROJECT_FOLDER / "data" / "output",
]

REQUIREMENTS = """pandas>=2.0
python-dotenv>=1.0
google-genai>=1.0
openpyxl>=3.1
"""

ENV_TEMPLATE = """# Google AI Studio API Key Configuration
GEMINI_API_KEY=ActualGoogleStudioKeyHere

# Optional: Override default model (default is gemini-3.5-flash-lite)
# GEMINI_MODEL=gemini-3.8-flash
"""

for folder in FOLDERS:
    folder.mkdir(parents=True, exist_ok=True)
    print(f"[ok] {folder}")

req_file = PROJECT_FOLDER / "requirements.txt"
req_file.write_text(REQUIREMENTS, encoding="utf-8")
print(f"[ok] {req_file}")

env_file = PROJECT_FOLDER / ".env"
if env_file.exists():
    print(f"[skip] {env_file} already exists - key not overwritten")
else:
    env_file.write_text(ENV_TEMPLATE, encoding="utf-8")
    print(f"[ok] {env_file}")

print("Installing packages...")
subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", str(req_file)])
print("Setup complete. Add your Gemini key to .env, save data_profiler.py in script\\, drop files in landing\\.")