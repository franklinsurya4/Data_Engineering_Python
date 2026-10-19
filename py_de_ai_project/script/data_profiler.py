
import shutil
from pathlib import Path

from config import *
from loader import load_dataframe
from profiler import profile_dataframe
from prompts import build_prompts
from ai_client import ask_gemini


# ============================================================
# 1. PRINT DATASET REPORT
# ============================================================

def print_dataframe_report(df, file_name):
    """Display dataset statistics and structure in the terminal."""

    print("\n" + "=" * 65)
    print("DATA ENGINEERING DATA PROFILER")
    print(f"Gemini model: {MODEL}")
    print(f"Processing file: {file_name}")
    print("=" * 65)

    # First 5 rows
    print("\nFirst 5 records:")
    print(df.head().to_string())

    # Dataset shape
    print("\nShape:")
    print(df.shape)

    # Column names
    print("\nColumns:")
    print(df.columns.tolist())

    # Data types
    print("\nData types:")
    print(df.dtypes.to_string())

    # Statistical information
    print("\nStatistical information:")
    print(df.describe(include="all").to_string())

    # DataFrame information
    print("\nDataFrame information:")
    df.info(show_counts=True)

    # Missing values
    print("\nMissing values:")
    print(df.isnull().sum().to_string())

    print("\nMissing value percentages:")
    missing_percentage = (
        df.isnull().mean().mul(100).round(2)
    )
    print(missing_percentage.to_string())

    # Unique values per column
    print("\nUnique value counts:")
    print(df.nunique(dropna=False).to_string())

    # Duplicate rows
    print("\nDuplicate rows:")
    duplicate_count = df.duplicated().sum()
    print(f"Total duplicate rows: {duplicate_count}")

    # Repeated values within individual columns
    print("\nRepeated values by column:")
    for column in df.columns:
        repeated_count = df[column].duplicated().sum()
        print(f"{column}: {repeated_count}")

    print("\n" + "=" * 65)
    print("DATASET REPORT COMPLETED")
    print("=" * 65)


# ============================================================
# 2. PROCESS ONE FILE
# ============================================================

def process_file(source_file):
    """
    1. Move file from landing to processing.
    2. Load CSV, JSON, XLSX, or TXT into Pandas.
    3. Print dataset report.
    4. Generate and save the data profile.
    5. Build classification and schema prompts.
    6. Ask Gemini for governance and schema recommendations.
    7. Save classification, schema, and processed CSV.
    8. Archive the source file.
    """

    file_name = source_file.name
    processing_file = PROCESSING / file_name

    print(f"\n{'=' * 55}")
    print(
        f"PROCESSING: {file_name} "
        f"({source_file.stat().st_size} bytes)"
    )
    print(f"{'=' * 55}")

    try:
        # Step 1: Move file to processing folder
        shutil.move(str(source_file), str(processing_file))

        # Step 2: Load dataset
        df = load_dataframe(processing_file)

        if df is None:
            print(f"FAILED: Could not load {file_name}")
            shutil.move(
                str(processing_file),
                str(ERROR / file_name)
            )
            return False

        if len(df.columns) == 0:
            print(f"WARNING: Dataset has no columns: {file_name}")
            shutil.move(
                str(processing_file),
                str(ERROR / file_name)
            )
            return False

        # Step 3: Display report in terminal
        print_dataframe_report(df, file_name)

        # Step 4: Generate and save dataset profile
        data_types, column_profile, duplicates = (
            profile_dataframe(df, file_name)
        )

        # Step 5: Build AI prompts
        c_prompt, s_prompt = build_prompts(
            file_name,
            df,
            data_types,
            column_profile
        )

        # Step 6: Gemini classification
        print(
            f"\nRequesting AI Data Governance & "
            f"Classification ({MODEL})..."
        )
        classification_json = ask_gemini(c_prompt)

        if not classification_json:
            raise RuntimeError(
                "Gemini classification returned no result."
            )

        # Step 7: Gemini schema recommendations
        print(
            f"\nRequesting Target Schema & "
            f"Key Recommendations ({MODEL})..."
        )
        schema_json = ask_gemini(s_prompt)

        if not schema_json:
            raise RuntimeError(
                "Gemini schema generation returned no result."
            )

        # Step 8: Define output file paths
        file_stem = Path(file_name).stem

        classification_file = (
            OUTPUT / f"{file_stem}_classification.json"
        )
        schema_file = OUTPUT / f"{file_stem}_schema.json"
        processed_file = OUTPUT / f"{file_stem}_processed.csv"

        # Step 9: Save generated artifacts
        classification_file.write_text(
            classification_json,
            encoding="utf-8"
        )

        schema_file.write_text(
            schema_json,
            encoding="utf-8"
        )

        df.to_csv(processed_file, index=False)

        # Step 10: Archive source file
        shutil.move(
            str(processing_file),
            str(ARCHIVE / file_name)
        )

        # Step 11: Display completion summary
        print(f"\nSUCCESS: {file_name}")
        print(
            f"  Profile:        "
            f"{OUTPUT / f'{file_stem}_profile.csv'}"
        )
        print(f"  Classification: {classification_file}")
        print(f"  Schema:         {schema_file}")
        print(f"  Processed CSV:  {processed_file}")
        print(f"  Archived to:    {ARCHIVE / file_name}")

        return True

    except Exception as exc:
        print(f"\nFAILED: {file_name}")
        print(f"Error: {exc}")

        # Move a failed file to the error folder if possible
        if processing_file.exists():
            try:
                shutil.move(
                    str(processing_file),
                    str(ERROR / file_name)
                )
                print(f"Moved failed file to: {ERROR / file_name}")
            except Exception as move_error:
                print(f"Could not quarantine file: {move_error}")

        return False


# ============================================================
# 3. MAIN BATCH PIPELINE
# ============================================================

def main():
    """Scan landing folder and process supported datasets."""

    if client is None:
        print(
            "CONFIG ERROR: Check your GEMINI_API_KEY in "
            f"{PROJECT_FOLDER / '.env'}"
        )
        return

    supported_extensions = [".csv", ".json", ".xlsx", ".txt"]

    # Ensure required directories exist
    for folder in [LANDING, PROCESSING, OUTPUT, ARCHIVE, ERROR]:
        folder.mkdir(parents=True, exist_ok=True)

    files = []

    # Scan landing folder
    for file_path in LANDING.iterdir():
        if not file_path.is_file():
            continue

        if file_path.suffix.lower() in supported_extensions:
            files.append(file_path)
        else:
            print(
                f"Unsupported file quarantined: "
                f"{file_path.name}"
            )
            shutil.move(
                str(file_path),
                str(ERROR / file_path.name)
            )

    files.sort()

    print("\n--- Batch Ingestion Scan ---")
    print(f"Found {len(files)} supported file(s) in {LANDING}:")

    for file_path in files:
        print(f"  -> {file_path.name}")

    if not files:
        print("No files available in landing/ to process.")
        return

    success_count = 0
    failure_count = 0

    # Process files sequentially
    for source_file in files:
        if process_file(source_file):
            success_count += 1
        else:
            failure_count += 1

    print("\n" + "=" * 55)
    print("BATCH PIPELINE SUMMARY")
    print("=" * 55)
    print(f"Total files:      {len(files)}")
    print(f"Successful files: {success_count}")
    print(f"Failed files:     {failure_count}")
    print(f"Output folder:    {OUTPUT}")
    print(f"Archive folder:   {ARCHIVE}")
    print("=" * 55)


# ============================================================
# 4. ENTRY POINT
# ============================================================

if __name__ == "__main__":
    main()
