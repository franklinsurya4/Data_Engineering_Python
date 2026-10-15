import pandas as pd
from pathlib import Path

def load_dataframe(file_path):
    file_path = Path(file_path)

    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    return pd.read_csv(file_path)


if __name__ == "__main__":
    from config import LANDING

    test_file = LANDING / "employee.csv"

    df = load_dataframe(test_file)

    print("Data loaded successfully!")
    print("Shape:", df.shape)
    print(df.head())