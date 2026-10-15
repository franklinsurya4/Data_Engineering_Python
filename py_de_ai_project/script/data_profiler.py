from config import *
from loader import load_dataframe
from profiler import profile_dataframe
from prompts import build_prompts
from ai_client import ask_gemini


# =====================================================================
# 6. ASSEMBLE PIPELINE FUNCTIONS & EXECUTION
# =====================================================================

def process_file(source_file):
    """
    1. Locks file: moves from landing/ -> data/processing/
    2. Loads into Pandas dataframe dynamically (.csv, .json, .xlsx, .txt)
    3. Profiles dataset metrics & saves _profile.csv
    4. Builds governance and target DDL schema prompts
    5. Queries Gemini AI for dual passes (Governance + DDL Modeling)
    6. Persists _classification.json, _schema.json, and _processed.csv
    7. Safely archives source file to data/archive/
    """
    file_name = source_file.name
    processing_file = PROCESSING / file_name

    print(f"\n{'='*55}")
    print(f"PROCESSING: {file_name} ({source_file.stat().st_size} bytes)")
    print(f"{'='*55}")

    # 1. Atomic lock: move file from landing/ to processing/
    shutil.move(str(source_file), str(processing_file))

    # 2. Ingest via dynamic multi-format reader
    df = load_dataframe(processing_file)
    if df is None:
        print(f"FAILED: Could not parse dataframe for {file_name}")
        shutil.move(str(processing_file), str(ERROR / file_name))
        return

    if len(df.columns) == 0:
        print(f"WARNING: Dataset has 0 columns: {file_name}")
        shutil.move(str(processing_file), str(ERROR / file_name))
        return

    # 3. Compute statistical and structural profile
    data_types, column_profile, duplicates = profile_dataframe(df, file_name)

    # 4. Construct AI prompts
    c_prompt, s_prompt = build_prompts(file_name, df, data_types, column_profile)

    # 5. Dual AI Inferences (Governance + DDL Modeling)
    print(f"Requesting AI Data Governance & Classification ({MODEL})...")
    classification_json = ask_gemini(c_prompt)

    print(f"Requesting Target Schema & Key Recommendations ({MODEL})...")
    schema_json = ask_gemini(s_prompt)

    # 6. Persist generated artifacts
    classification_file = OUTPUT / f"{Path(file_name).stem}_classification.json"
    schema_file = OUTPUT / f"{Path(file_name).stem}_schema.json"
    processed_file = OUTPUT / f"{Path(file_name).stem}_processed.csv"

    classification_file.write_text(classification_json, encoding="utf-8")
    schema_file.write_text(schema_json, encoding="utf-8")
    df.to_csv(processed_file, index=False)

    # 7. Move source file to archive
    shutil.move(str(processing_file), str(ARCHIVE / file_name))

    print(f"\nSUCCESS: {file_name}")
    print(f"  Profile:        {OUTPUT / f'{Path(file_name).stem}_profile.csv'}")
    print(f"  Classification: {classification_file}")
    print(f"  Schema:         {schema_file}")
    print(f"  Processed CSV:  {processed_file}")
    print(f"  Archived to:    {ARCHIVE / file_name}")


def main():
    """
    Main batch scanner:
    - Scans landing/ for .csv, .json, .xlsx, .txt
    - Quarantines unsupported formats into error/
    - Passes valid files sequentially to process_file()
    """
    if client is None:
        print(f"CONFIG ERROR: put your real GEMINI_API_KEY in {PROJECT_FOLDER / '.env'}")
        return

    supported_extensions = [".csv", ".json", ".xlsx", ".txt"]
    files = []

    for f in LANDING.iterdir():
        if f.is_file():
            if f.suffix.lower() in supported_extensions:
                files.append(f)
            else:
                print(f"Unsupported file quarantined: {f.name}")
                shutil.move(str(f), str(ERROR / f.name))

    files.sort()
    print(f"\n--- Batch Ingestion Scan ---")
    print(f"Found {len(files)} supported file(s) in {LANDING}:")
    for f in files:
        print(f"  -> {f.name}")

    if not files:
        print("No files available in landing/ to process.")
        return

    for source_file in files:
        process_file(source_file)

    print(f"\nAll files processed successfully! Check {OUTPUT} and {ARCHIVE}.")

if __name__ == "__main__":
    main()