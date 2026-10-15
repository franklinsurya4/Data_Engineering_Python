import time

from config import *
from loader import load_dataframe
from profiler import profile_dataframe
from prompts import build_prompts


# 5. CALL GEMINI WITH RETRY HANDLING
def ask_gemini(prompt, max_retries=3):
    if client is None:
        raise RuntimeError(
            f"GEMINI_API_KEY is missing. Check {PROJECT_FOLDER / '.env'}"
        )

    for attempt in range(1, max_retries + 1):
        try:
            print(f"Sending request to Gemini (attempt {attempt}/{max_retries})...")

            response = client.models.generate_content(
                model=MODEL,
                contents=prompt
            )

            if not response.text:
                raise RuntimeError("Gemini returned an empty response.")

            return response.text

        except Exception as error:
            error_message = str(error)

            # Retry only errors that may be temporary
            retryable = any(
                marker in error_message
                for marker in ["503", "UNAVAILABLE", "429", "RESOURCE_EXHAUSTED"]
            )

            if not retryable or attempt == max_retries:
                raise RuntimeError(
                    f"Gemini request failed after {attempt} attempt(s). "
                    f"Check the model name, API quota, and service availability. "
                    f"Original error: {error}"
                ) from error

            wait_seconds = attempt * 5
            print(f"Temporary API issue. Retrying in {wait_seconds} seconds...")
            time.sleep(wait_seconds)


# 6. TEST THE AI CLIENT
if __name__ == "__main__":
    test_file = LANDING / "employee.csv"

    if not test_file.exists():
        test_file = ARCHIVE / "employee.csv"

    if not test_file.exists():
        raise FileNotFoundError(
            "employee.csv was not found in landing or archive."
        )

    df = load_dataframe(test_file)

    data_types, column_profile, duplicates = profile_dataframe(
        df, test_file.name
    )

    c_prompt, s_prompt = build_prompts(
        test_file.name, df, data_types, column_profile
    )

    print("\n--- Testing ask_gemini ---")

    try:
        classification_result = ask_gemini(c_prompt)

        print("\n--- Classification Result ---")
        print(classification_result)

    except RuntimeError as error:
        print("\nAI request could not be completed:")
        print(error)