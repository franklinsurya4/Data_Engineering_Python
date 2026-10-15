import subprocess
import sys
from pathlib import Path

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

FOLDERS = ["script", "landing", "data/archive", "data/error", "data/processing", "data/output"]


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python setup_project.py <project_folder>")
        sys.exit(1)

    root = Path(sys.argv[1]).resolve()
    root.mkdir(parents=True, exist_ok=True)
    print(f"Project root: {root}")

    for folder in FOLDERS:
        (root / folder).mkdir(parents=True, exist_ok=True)
        print(f"  [ok] {folder}/")

    req = root / "requirements.txt"
    req.write_text(REQUIREMENTS, encoding="utf-8")
    print("  [ok] requirements.txt")

    env = root / ".env"
    if env.exists():
        print("  [skip] .env already exists - not overwriting your key")
    else:
        env.write_text(ENV_TEMPLATE, encoding="utf-8")
        print("  [ok] .env (placeholder - add your Gemini key)")

    print("Installing packages...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", str(req)])
    print("\nSetup complete. Next: put your key in .env, drop files in landing/,")
    print(f"then run: python script/data_profiler.py {root}")


if __name__ == "__main__":
    main()
