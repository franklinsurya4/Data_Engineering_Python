import logging
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv

SUPPORTED = {".csv", ".json", ".xlsx", ".xls", ".txt"}
DEFAULT_MODEL = "gemini-3.5-flash-lite"
SAMPLE_ROWS = 10

log = logging.getLogger("profiler")


def build_paths(root: Path) -> dict:
    paths = {
        "landing": root / "landing",
        "processing": root / "data" / "processing",
        "archive": root / "data" / "archive",
        "error": root / "data" / "error",
        "output": root / "data" / "output",
    }
    for p in paths.values():
        p.mkdir(parents=True, exist_ok=True)
    return paths


def timestamped(name: str) -> str:
    return f"{datetime.now():%Y%m%d_%H%M%S}_{name}"


def load_dataframe(path: Path) -> pd.DataFrame:
    ext = path.suffix.lower()
    try:
        if ext == ".csv":
            return pd.read_csv(path)
        if ext == ".json":
            try:
                return pd.read_json(path)
            except ValueError:
                return pd.read_json(path, lines=True)
        if ext in {".xlsx", ".xls"}:
            return pd.read_excel(path)
        if ext == ".txt":
            return pd.read_csv(path, sep=None, engine="python")
    except Exception as exc:
        raise ValueError(f"Could not read {path.name}: {exc}") from exc
    raise ValueError(f"Unsupported extension: {ext}")


def profile_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    total = len(df)
    rows = []
    for col in df.columns:
        s = df[col]
        nulls = int(s.isna().sum())
        rows.append(
            {
                "column": col,
                "dtype": str(s.dtype),
                "null_count": nulls,
                "null_pct": round(nulls / total * 100, 2) if total else 0.0,
                "unique_count": int(s.nunique(dropna=True)),
                "sample_value": None if s.dropna().empty else str(s.dropna().iloc[0]),
            }
        )
    prof = pd.DataFrame(rows)
    prof.attrs["row_count"] = total
    prof.attrs["duplicate_rows"] = int(df.duplicated().sum())
    return prof


def build_prompts(file_name, df, prof):
    profile_txt = prof.to_string(index=False)
    sample_txt = df.head(SAMPLE_ROWS).to_csv(index=False)
    context = (
        f"File: {file_name}\n"
        f"Rows: {len(df)}  Columns: {len(df.columns)}  "
        f"Duplicate rows: {prof.attrs.get('duplicate_rows', 0)}\n\n"
        f"Column profile:\n{profile_txt}\n\n"
        f"Sample ({SAMPLE_ROWS} rows, CSV):\n{sample_txt}"
    )
    governance = (
        "You are a data governance analyst. Using the dataset context below, return JSON with keys: "
        "'columns' (list of {name, business_meaning, classification: PUBLIC|INTERNAL|CONFIDENTIAL|RESTRICTED, "
        "is_pii: bool, pii_type}), 'quality_issues' (list of strings), 'recommendations' (list of strings). "
        "Return JSON only.\n\n" + context
    )
    schema = (
        "You are a data engineer. Using the dataset context below, return JSON with keys: "
        "'table_name', 'columns' (list of {name, sql_type, nullable, notes}), 'primary_key_candidates', "
        "and 'ddl' (a CREATE TABLE statement in ANSI-style SQL). Return JSON only.\n\n" + context
    )
    return governance, schema


def make_client():
    key = os.getenv("GEMINI_API_KEY", "").strip()
    if not key or key == "ActualGoogleStudioKeyHere":
        return None
    from google import genai

    return genai.Client(api_key=key)


def ask_gemini(client, prompt: str) -> str:
    from google.genai import types

    model = os.getenv("GEMINI_MODEL", DEFAULT_MODEL)
    resp = client.models.generate_content(
        model=model,
        contents=prompt,
        config=types.GenerateContentConfig(response_mime_type="application/json"),
    )
    return resp.text or ""


def process_file(src: Path, paths: dict, client) -> None:
    stem = src.stem
    in_flight = paths["processing"] / src.name
    shutil.move(str(src), str(in_flight))
    log.info("Processing %s", src.name)

    try:
        df = load_dataframe(in_flight)
        prof = profile_dataframe(df)
        prof.to_csv(paths["output"] / f"{stem}_profile.csv", index=False)

        if client is None:
            log.warning("No valid GEMINI_API_KEY - skipping AI steps for %s", src.name)
        else:
            gov_prompt, schema_prompt = build_prompts(src.name, df, prof)
            gov = ask_gemini(client, gov_prompt)
            (paths["output"] / f"{stem}_governance.json").write_text(gov, encoding="utf-8")
            schema = ask_gemini(client, schema_prompt)
            (paths["output"] / f"{stem}_schema.json").write_text(schema, encoding="utf-8")

        df.to_csv(paths["output"] / f"{stem}_processed.csv", index=False)
        shutil.move(str(in_flight), str(paths["archive"] / timestamped(src.name)))
        log.info("Archived %s", src.name)
    except Exception as exc:
        log.error("FAILED %s: %s", src.name, exc)
        if in_flight.exists():
            shutil.move(str(in_flight), str(paths["error"] / timestamped(src.name)))


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)-7s %(message)s")
    if len(sys.argv) != 2:
        print("Usage: python data_profiler.py <project_folder>")
        sys.exit(1)

    root = Path(sys.argv[1]).resolve()
    load_dotenv(root / ".env")
    paths = build_paths(root)
    client = make_client()

    files = sorted(p for p in paths["landing"].iterdir() if p.is_file())
    if not files:
        log.info("landing/ is empty - nothing to do")
        return

    for f in files:
        if f.suffix.lower() not in SUPPORTED:
            log.warning("Unsupported type %s -> error/", f.name)
            shutil.move(str(f), str(paths["error"] / timestamped(f.name)))
            continue
        process_file(f, paths, client)

    log.info("Done.")


if __name__ == "__main__":
    main()
