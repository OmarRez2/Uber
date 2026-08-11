"""Load the reviewed Uber workbook rows into a local SQLite audit database."""

from __future__ import annotations

import csv
import json
import sqlite3
from pathlib import Path

from uber_data_profile import excel_datetime, iter_xlsx_records


ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "uber_analysis.db"


def main() -> None:
    connection = sqlite3.connect(DB_PATH)
    try:
        connection.executescript(
            """
            DROP TABLE IF EXISTS trip_details;
            DROP TABLE IF EXISTS location_table;
            DROP TABLE IF EXISTS official_taxi_zones;
            DROP TABLE IF EXISTS power_bi_model_observations;
            DROP TABLE IF EXISTS data_dictionary;
            DROP TABLE IF EXISTS quality_issues;

            CREATE TABLE trip_details (
                trip_id INTEGER NOT NULL,
                pickup_time TEXT NOT NULL,
                dropoff_time TEXT NOT NULL,
                passenger_count INTEGER NOT NULL,
                trip_distance REAL NOT NULL,
                pu_location_id INTEGER NOT NULL,
                do_location_id INTEGER NOT NULL,
                fare_amount REAL NOT NULL,
                surge_fee REAL NOT NULL,
                vehicle TEXT NOT NULL,
                payment_type TEXT NOT NULL,
                duration_minutes REAL NOT NULL,
                speed_mph REAL
            );

            CREATE TABLE location_table (
                location_id INTEGER PRIMARY KEY,
                location TEXT NOT NULL,
                city TEXT NOT NULL
            );

            CREATE TABLE official_taxi_zones (
                location_id INTEGER PRIMARY KEY,
                borough TEXT,
                zone TEXT,
                service_zone TEXT
            );

            CREATE TABLE power_bi_model_observations (
                observation TEXT PRIMARY KEY,
                value_text TEXT,
                value_number REAL
            );

            CREATE TABLE data_dictionary (
                table_name TEXT NOT NULL,
                column_name TEXT NOT NULL,
                column_type TEXT NOT NULL,
                meaning TEXT NOT NULL,
                model_role TEXT,
                quality_note TEXT,
                PRIMARY KEY (table_name, column_name)
            );

            CREATE TABLE quality_issues (
                check_name TEXT PRIMARY KEY,
                evidence TEXT NOT NULL,
                severity TEXT NOT NULL,
                severity_rank INTEGER NOT NULL,
                confidence TEXT NOT NULL,
                impact TEXT NOT NULL,
                action TEXT NOT NULL
            );
            """
        )

        trip_batch = []
        for row in iter_xlsx_records(ROOT / "Uber Trip Details.xlsx", "Trip Details"):
            pickup = excel_datetime(row["Pickup Time"])
            dropoff = excel_datetime(row["Drop Off Time"])
            duration = (dropoff - pickup).total_seconds() / 60
            distance = float(row["trip_distance"])
            speed = distance / (duration / 60) if duration > 0 else None
            trip_batch.append(
                (
                    int(row["Trip ID"]),
                    pickup.isoformat(sep=" "),
                    dropoff.isoformat(sep=" "),
                    int(row["passenger_count"]),
                    distance,
                    int(row["PULocationID"]),
                    int(row["DOLocationID"]),
                    float(row["fare_amount"]),
                    float(row["Surge Fee"]),
                    str(row["Vehicle"]).strip(),
                    str(row["Payment_type"]).strip(),
                    duration,
                    speed,
                )
            )
            if len(trip_batch) >= 5000:
                connection.executemany(
                    "INSERT INTO trip_details VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", trip_batch
                )
                trip_batch.clear()
        if trip_batch:
            connection.executemany(
                "INSERT INTO trip_details VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", trip_batch
            )

        locations = [
            (int(row["LocationID"]), str(row["Location"]), str(row["City"]))
            for row in iter_xlsx_records(ROOT / "Location Table.xlsx", "Location Table")
        ]
        connection.executemany("INSERT INTO location_table VALUES (?,?,?)", locations)

        with (ROOT / "official_taxi_zone_lookup.csv").open(
            "r", encoding="utf-8-sig", newline=""
        ) as handle:
            official = [
                (
                    int(row["LocationID"]),
                    row["Borough"],
                    row["Zone"],
                    row["service_zone"],
                )
                for row in csv.DictReader(handle)
            ]
        connection.executemany("INSERT INTO official_taxi_zones VALUES (?,?,?,?)", official)

        profile = json.loads((ROOT / "analysis_results.json").read_text(encoding="utf-8"))
        model = profile["model_observations"]
        model_rows = [
            ("visible_tables", ", ".join(model["power_bi_visible_tables"]), len(model["power_bi_visible_tables"])),
            ("hidden_auto_date_tables", None, model["power_bi_hidden_auto_date_tables"]),
            ("explicit_measures", None, model["power_bi_explicit_measures"]),
            ("location_table_loaded", str(model["power_bi_location_table_loaded"]), int(model["power_bi_location_table_loaded"])),
            ("live_model_row_count", None, model["live_model_row_count"]),
        ]
        connection.executemany(
            "INSERT INTO power_bi_model_observations VALUES (?,?,?)", model_rows
        )

        data_dictionary_rows = [
            ("trip_details", "Trip ID", "Whole number", "معرّف فريد للرحلة؛ هو أفضل مفتاح لحساب عدد الحجوزات بدون تكرار.", "Primary/candidate key", None),
            ("trip_details", "Pickup Time", "Date/Time", "وقت بداية الرحلة؛ منه نستخرج التاريخ واليوم والساعة وفترة اليوم.", "Time analysis", None),
            ("trip_details", "Drop Off Time", "Date/Time", "وقت نهاية الرحلة؛ الفرق عن وقت البداية يساوي مدة الرحلة.", "Duration calculation", None),
            ("trip_details", "passenger_count", "Whole number", "عدد الركاب داخل الرحلة؛ القيم من 1 إلى 6 في الملف الحالي.", "Volume / occupancy", None),
            ("trip_details", "trip_distance", "Decimal number", "مسافة الرحلة بالأميال في مرجع مناطق TLC الذي بُنيت عليه البيانات.", "Distance KPI", None),
            ("trip_details", "PULocationID", "Whole number", "مفتاح منطقة الالتقاط، ويرتبط بـ Location Table[LocationID].", "Pickup relationship", None),
            ("trip_details", "DOLocationID", "Whole number", "مفتاح منطقة الوصول؛ يحتاج علاقة ثانية غير نشطة أو جدول مواقع بدور منفصل.", "Drop-off relationship", None),
            ("trip_details", "fare_amount", "Decimal number", "قيمة الأجرة الأساسية المسجلة للرحلة قبل حسم تعريف Surge Fee.", "Fare revenue", None),
            ("trip_details", "Surge Fee", "Decimal number", "رسوم زيادة مرتبطة بالتسعير الديناميكي؛ يجب تحديد هل تُضاف إلى fare_amount أم أنها مشمولة فيه.", "Pricing uplift", None),
            ("trip_details", "Vehicle", "Text", "فئة السيارة: UberX، Uber Comfort، Uber Black، UberXL، Uber Green.", "Vehicle segment", None),
            ("trip_details", "Payment_type", "Text", "طريقة الدفع: Uber Pay، Cash، Amazon Pay، Google Pay.", "Payment segment", None),
            ("location_table", "LocationID", "Whole number", "المفتاح الفريد لمنطقة التاكسي؛ يغطي القيم 1–265 بدون تكرار.", None, "سليم كمفتاح"),
            ("location_table", "Location", "Text", "اسم منطقة الالتقاط أو الوصول.", None, "يتفق مع المرجع الرسمي في 263 من 265 صفًا؛ الصفان 264 و265 تسميتهما مختصرة"),
            ("location_table", "City", "Text", "المدينة/المقاطعة المفترض استخدامها في التجميع الجغرافي.", None, "غير موثوق: 109 من 265 قيمة لا تطابق Borough الرسمي"),
        ]
        connection.executemany(
            "INSERT INTO data_dictionary VALUES (?,?,?,?,?,?)", data_dictionary_rows
        )

        quality = profile["quality"]
        kpis = profile["kpis"]
        quality_issue_rows = [
            ("القيم المفقودة", "0 خلية مفقودة في الأعمدة الـ11", "Low", 1, "High", "لا توجد فجوات مباشرة في حساب المؤشرات الأساسية.", "احتفظ باختبارات Not Null عند التحديث."),
            ("تكرار Trip ID والصفوف", "0 Trip ID مكرر و0 صف مطابق مكرر", "Low", 1, "High", "COUNTROWS وDISTINCTCOUNT متساويان حاليًا.", "اجعل Trip ID فريدًا في اختبار الجودة."),
            ("دقة City في Location Table", f"{quality['city_mismatch_count']} من {profile['dataset']['location_rows']} صفًا غير مطابق ({quality['city_mismatch_rate']:.1%})", "High", 3, "High", "أي تحليل أو Slicer حسب City سيعطي توزيعًا جغرافيًا مضللًا.", "استبدل City بقيمة Borough الرسمية ثم أعد تحميل الجدول."),
            ("تحميل جدول المواقع في Power BI", "الموديل الحالي يعرض Trip Details فقط؛ Location Table غير محمّل", "Critical", 4, "High", "لا يمكن بناء Top Pickup/Drop-off أو City analysis بصورة صحيحة داخل التقرير الحالي.", "حمّل Location Table وأنشئ علاقتي Pickup وDrop-off."),
            ("المقاييس الصريحة في الموديل", "0 DAX measures صريحة في Uber.pbix", "High", 3, "High", "المؤشرات الديناميكية المطلوبة في Problem Statement غير مُنفذة كمقاييس قابلة لإعادة الاستخدام.", "أنشئ measures واضحة بدل الاعتماد على implicit aggregation."),
            ("منطق الزمن والسرعة", f"{quality['quality_rule_counts']['speed_over_100_mph']} رحلة تتجاوز 100 mph و{quality['quality_rule_counts']['non_positive_duration']} بمدة صفر", "Medium", 2, "High", "تؤثر على تحليلات الكفاءة والمدة والسرعة، وإن كانت نسبتها صغيرة.", "استبعد أو صحح الرحلات ذات المدة <=0 أو السرعة غير المعقولة."),
            ("تعريف Total Booking Value", f"fare_amount = ${kpis['fare_total']:,.2f} مقابل fare + surge = ${kpis['booking_value_including_surge']:,.2f}", "High", 3, "Medium", "اختيار التعريف يغير الإيراد الشهري بـ$205,381.36.", "ثبّت تعريفًا تجاريًا موحدًا قبل نشر KPI الإيراد."),
            ("التغطية الزمنية", "30 يومًا فقط: 1–30 يونيو 2024", "Medium", 2, "High", "يمكن وصف يونيو، لكن لا يمكن استنتاج موسمية أو نمو طويل المدى.", "أضف عدة أشهر أو سنوات قبل مقارنة الاتجاهات الموسمية."),
        ]
        connection.executemany(
            "INSERT INTO quality_issues VALUES (?,?,?,?,?,?,?)", quality_issue_rows
        )
        connection.executescript(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS ux_trip_details_trip_id ON trip_details(trip_id);
            CREATE INDEX IF NOT EXISTS ix_trip_details_pickup_time ON trip_details(pickup_time);
            CREATE INDEX IF NOT EXISTS ix_trip_details_vehicle ON trip_details(vehicle);
            CREATE INDEX IF NOT EXISTS ix_trip_details_payment ON trip_details(payment_type);
            CREATE INDEX IF NOT EXISTS ix_trip_details_pu ON trip_details(pu_location_id);
            CREATE INDEX IF NOT EXISTS ix_trip_details_do ON trip_details(do_location_id);
            """
        )
        connection.commit()
        counts = {
            "trip_details": connection.execute("SELECT COUNT(*) FROM trip_details").fetchone()[0],
            "location_table": connection.execute("SELECT COUNT(*) FROM location_table").fetchone()[0],
            "official_taxi_zones": connection.execute("SELECT COUNT(*) FROM official_taxi_zones").fetchone()[0],
        }
        print(json.dumps({"database": str(DB_PATH), "counts": counts}, indent=2))
    finally:
        connection.close()


if __name__ == "__main__":
    main()
