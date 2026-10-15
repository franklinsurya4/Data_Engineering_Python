import json

from config import *
from loader import load_dataframe
from profiler import profile_dataframe


# 4. DEFINE FUNCTION
def build_prompts(file_name, df, data_types, column_profile):

    # Get the first 10 rows as sample JSON
    sample_json = df.head(10).astype(str).to_json(
        orient="records",
        indent=2,
        force_ascii=False
    )

    # Get column names
    columns = df.columns.tolist()

    # Convert data types to JSON
    types_json = json.dumps(
        data_types,
        indent=2,
        ensure_ascii=False
    )

    # Convert profile into readable text
    profile_text = column_profile.to_string(index=False)

    # Classification prompt
    classification_prompt = f"""
File: {file_name}

Columns:
{json.dumps(columns, ensure_ascii=False)}

Data Types:
{types_json}

Column Profile:
{profile_text}

Sample Data:
{sample_json}

Tasks:
1. Identify the data governance domain.
2. Identify PII and confidential columns.
3. Recommend automated data quality rules and checks.

Return valid JSON only.
"""

    # Target schema prompt
    schema_prompt = f"""
File: {file_name}

Columns:
{json.dumps(columns, ensure_ascii=False)}

Data Types:
{types_json}

Column Profile:
{profile_text}

Sample Data:
{sample_json}

Tasks:
1. Recommend a target analytical database schema.
2. Identify potential primary and foreign keys using available evidence.
3. Recommend data quality constraints.

Return valid JSON only.
"""

    return classification_prompt, schema_prompt


# TEST THE FUNCTION
if __name__ == "__main__":

    test_file = LANDING / "employee.csv"

    # Check archive if the file is not in landing
    if not test_file.exists():
        test_file = ARCHIVE / "employee.csv"

    if not test_file.exists():
        raise FileNotFoundError(
            "employee.csv was not found in landing or archive."
        )

    df = load_dataframe(test_file)

    data_types, column_profile, duplicates = profile_dataframe(
        df,
        test_file.name
    )

    print("\n--- Testing build_prompts ---")

    c_prompt, s_prompt = build_prompts(
        test_file.name,
        df,
        data_types,
        column_profile
    )

    print("\nClassification Prompt Preview:")
    print(c_prompt[:500] + "\n...[TRUNCATED FOR DISPLAY]")

    print("\nSchema Prompt Preview:")
    print(s_prompt[:500] + "\n...[TRUNCATED FOR DISPLAY]")

    print("\nPrompts created successfully!")
