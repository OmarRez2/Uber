from __future__ import annotations

import csv
import json
import sqlite3
from pathlib import Path
from typing import Iterable, Sequence


ROOT = Path(__file__).resolve().parent
SOURCE_DB = ROOT / "uber_analysis.db"
OUTPUT_DIR = ROOT / "sqlserver_import_data"


EXPORTS: tuple[tuple[str, str], ...] = (
    (
        "trip_details.tsv",
        """
        SELECT
            trip_id,
            pickup_time,
            dropoff_time,
            passenger_count,
            trip_distance,
            pu_location_id,
            do_location_id,
            fare_amount,
            surge_fee,
            vehicle,
            payment_type
        FROM trip_details
        ORDER BY trip_id
        """,
    ),
    (
        "location_table.tsv",
        """
        SELECT location_id, location, city
        FROM location_table
        ORDER BY location_id
        """,
    ),
    (
        "official_taxi_zones.tsv",
        """
        SELECT location_id, borough, zone, service_zone
        FROM official_taxi_zones
        ORDER BY location_id
        """,
    ),
)


def sql_server_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        text = format(value, ".15g")
    else:
        text = str(value)
    if any(character in text for character in ("\t", "\r", "\n")):
        raise ValueError(f"A value contains a tab or line break: {text!r}")
    return text


def export_query(
    connection: sqlite3.Connection,
    filename: str,
    query: str,
) -> int:
    target = OUTPUT_DIR / filename
    temporary = target.with_suffix(target.suffix + ".tmp")
    row_count = 0

    cursor = connection.execute(query)
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(
            handle,
            delimiter="\t",
            lineterminator="\r\n",
            quoting=csv.QUOTE_NONE,
            escapechar="\\",
        )
        while True:
            rows: Sequence[Sequence[object]] = cursor.fetchmany(10_000)
            if not rows:
                break
            writer.writerows(
                [sql_server_text(value) for value in row] for row in rows
            )
            row_count += len(rows)

    temporary.replace(target)
    return row_count


def main() -> None:
    if not SOURCE_DB.exists():
        raise FileNotFoundError(f"SQLite source database was not found: {SOURCE_DB}")

    OUTPUT_DIR.mkdir(exist_ok=True)
    connection = sqlite3.connect(f"file:{SOURCE_DB}?mode=ro", uri=True)
    try:
        connection.execute("PRAGMA query_only = ON")
        counts = {
            filename: export_query(connection, filename, query)
            for filename, query in EXPORTS
        }
    finally:
        connection.close()

    manifest = {
        "source": str(SOURCE_DB),
        "encoding": "UTF-8",
        "delimiter": "TAB",
        "has_header": False,
        "files": counts,
    }
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print("Prepared SQL Server import files:")
    for filename, count in counts.items():
        print(f"  {filename}: {count:,} rows")


if __name__ == "__main__":
    main()
