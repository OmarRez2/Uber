"""Beginner-friendly runner for Uber_Insights_Queries.sql."""

from __future__ import annotations

import csv
import re
import sqlite3
import sys
from datetime import datetime
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent
DATABASE_PATH = PROJECT_DIR / "uber_analysis.db"
SQL_PATH = PROJECT_DIR / "Uber_Insights_Queries.sql"
OUTPUT_DIR = PROJECT_DIR / "Uber_Query_Results"


COMPATIBILITY_VIEWS = """
CREATE TEMP VIEW trips AS
SELECT
    trip_id,
    pickup_time AS pickup,
    dropoff_time AS dropoff,
    passenger_count,
    trip_distance,
    pu_location_id,
    do_location_id,
    fare_amount,
    surge_fee,
    vehicle,
    payment_type,
    duration_minutes,
    speed_mph,
    fare_amount + surge_fee AS booking_value,
    DATE(pickup_time) AS pickup_date,
    CAST(STRFTIME('%H', pickup_time) AS INTEGER) AS pickup_hour,
    CASE STRFTIME('%w', pickup_time)
        WHEN '0' THEN 7
        ELSE CAST(STRFTIME('%w', pickup_time) AS INTEGER)
    END AS weekday_number,
    CASE STRFTIME('%w', pickup_time)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END AS weekday,
    PRINTF(
        '%02d:%02d',
        CAST(STRFTIME('%H', pickup_time) AS INTEGER),
        (CAST(STRFTIME('%M', pickup_time) AS INTEGER) / 10) * 10
    ) AS ten_minute_bucket,
    CASE
        WHEN CAST(STRFTIME('%H', pickup_time) AS INTEGER) BETWEEN 6 AND 17
        THEN 'Day'
        ELSE 'Night'
    END AS day_night
FROM trip_details;

CREATE TEMP VIEW locations AS
SELECT location_id, location, city
FROM location_table;
"""


def query_title(statement: str, query_number: int) -> str:
    match = re.search(r"--\s*\d+\)\s*(.+)", statement)
    return match.group(1).strip() if match else f"Query {query_number}"


def main() -> int:
    if not DATABASE_PATH.exists():
        print(f"ERROR: Database not found: {DATABASE_PATH}")
        return 1
    if not SQL_PATH.exists():
        print(f"ERROR: SQL file not found: {SQL_PATH}")
        return 1

    OUTPUT_DIR.mkdir(exist_ok=True)
    sql_text = SQL_PATH.read_text(encoding="utf-8-sig")
    statements = [statement.strip() for statement in sql_text.split(";") if statement.strip()]

    summary_lines = [
        "Uber SQL Query Results",
        f"Generated: {datetime.now().isoformat(timespec='seconds')}",
        f"Database: {DATABASE_PATH}",
        f"SQL file: {SQL_PATH}",
        "",
    ]

    connection = sqlite3.connect(DATABASE_PATH)
    try:
        connection.executescript(COMPATIBILITY_VIEWS)
        for query_number, statement in enumerate(statements, start=1):
            title = query_title(statement, query_number)
            cursor = connection.execute(statement)
            rows = cursor.fetchall()
            headers = [column[0] for column in cursor.description or []]
            output_path = OUTPUT_DIR / f"Query_{query_number:02d}.csv"
            with output_path.open("w", encoding="utf-8-sig", newline="") as handle:
                writer = csv.writer(handle)
                if headers:
                    writer.writerow(headers)
                writer.writerows(rows)
            summary_lines.append(
                f"Query {query_number:02d}: {title} | rows={len(rows)} | file={output_path.name}"
            )
            print(f"[OK] Query {query_number:02d}: {title} -> {output_path.name}")
    except sqlite3.Error as error:
        print(f"SQL ERROR: {error}")
        return 1
    finally:
        connection.close()

    summary_path = OUTPUT_DIR / "Results_Summary.txt"
    summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8-sig")
    print()
    print(f"SUCCESS: {len(statements)} queries completed.")
    print(f"Results folder: {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
