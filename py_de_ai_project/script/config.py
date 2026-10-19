import os
from pathlib import Path
from dotenv import load_dotenv

# 1. PROJECT CONFIGURATION

PROJECT_FOLDER = Path(
    r"C:\Users\S FRANKLIN SURYA\Downloads\Data-Engineering-Python\py_de_ai_project"
)

LANDING = PROJECT_FOLDER / "landing"
DATA = PROJECT_FOLDER / "data"
PROCESSING = DATA / "processing"
ARCHIVE = DATA / "archive"
ERROR = DATA / "error"
OUTPUT = DATA / "output"

# 2. CREATE REQUIRED FOLDERS

for folder in [LANDING, PROCESSING, ARCHIVE, ERROR, OUTPUT]:
    folder.mkdir(parents=True, exist_ok=True)

# 3. LOAD ENVIRONMENT VARIABLES

ENV_FILE = PROJECT_FOLDER / ".env"
load_dotenv(ENV_FILE, override=True)
#load_dotenv() is a Python function used to load environment variables from a .env file

MODEL = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
api_key = os.getenv("GEMINI_API_KEY", "").strip()
#strip() removes unwanted whitespace from the beginning and end of a string.


# 4. INITIALIZE AI CLIENT

client = None

if api_key:
    from google import genai
    client = genai.Client(api_key=api_key)

# 5. TEST CONFIGURATION

if __name__ == "__main__":
    print("Project folders created.")
    print("Environment file exists:", ENV_FILE.is_file())
    print("API key loaded:", bool(api_key))
    print("AI client initialized:", client is not None)
    print("Configured model:", MODEL)

