import pandas as pd
from pathlib import Path

from config import *
from loader import load_dataframe

# 1. DEFINE FUNCTION
def profile_dataframe(df, file_name):
    row_count = len(df)

    if row_count > 0:
        null_percentage = (
            df.isnull().sum() / row_count * 100
        ).round(2)
    else:
        null_percentage = df.isnull().sum()

    # 2. CREATE COLUMN PROFILE
    column_profile = pd.DataFrame({
        "column_name": df.columns,
        "data_type": df.dtypes.astype(str).values,
        "null_count": df.isnull().sum().values,
        "actual_count": row_count,
        "unique_count": df.nunique().values,
        "null_percentage": null_percentage.values
    })

    # 3. SAVE PROFILE TO OUTPUT FOLDER
    profile_file = OUTPUT / f"{Path(file_name).stem}_profile.csv"
    column_profile.to_csv(profile_file, index=False)

    # 4. RETURN DATA TYPES AND DUPLICATE COUNT
    data_types = df.dtypes.astype(str).to_dict()
    duplicates = int(df.duplicated().sum())

    print(f"Profile saved to: {profile_file}")

    return data_types, column_profile, duplicates


# 5. TEST THE FUNCTION
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

    print("\n--- Testing profile_dataframe ---")

    data_types, column_profile, duplicates = profile_dataframe(
        df, test_file.name
    )

    print("\nData Types Dictionary:")
    print(data_types)

    print("\nColumn Profile DataFrame:")
    print(column_profile.to_string(index=False))

    print("\nDuplicate Rows:", duplicates)
