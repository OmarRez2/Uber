# Uber Trips Analytics

End-to-end business intelligence project analyzing Uber trip demand, revenue, vehicle performance, time patterns, and location behavior using Power BI and SQL Server.

<p align="center">
  <img src="./Images/Uber%20Logo.png" alt="Uber logo" width="170">
</p>

## Project overview

The project turns 103,728 trip-level records into an interactive Power BI report supported by a reusable SQL Server data model and a library of analytical queries. The report includes Overview, Time Analysis, Details, Trip Snapshot, and Dashboard Guide pages.

## Key KPIs

| Metric | Result |
|---|---:|
| Total bookings | 103,728 |
| Fare revenue | $1,348,291.45 |
| Booking value including surge | $1,553,672.81 |
| Average booking value | $14.98 |
| Total trip distance | 348,933.81 miles |
| Average trip distance | 3.36 miles |
| Average trip duration | 15.86 minutes |

## Key findings

- UberX was the leading vehicle type with 38,744 bookings and $507,140.77 in fare revenue.
- June 26 recorded the highest daily demand with 4,947 bookings.
- Penn Station/Madison Sq West was the busiest pickup location with 4,475 trips.
- After duration and speed quality checks, 103,438 valid trips averaged 15.08 mph.
- Clean efficiency metrics produced an average fare of $4.43 per mile and $1.04 per minute.

## Analysis coverage

- Booking, fare, surge, distance, and duration KPIs
- Daily, weekday, hourly, and 10-minute demand patterns
- Day-versus-night performance
- Vehicle and payment-method comparisons
- Pickup, drop-off, and route analysis
- Passenger-count distribution
- Data-quality and trip-efficiency checks

## Technology

- Power BI and DAX
- SQL Server and T-SQL
- Power BI Project (`.pbip`) / TMDL semantic model
- Python and SQLite for reproducible audit outputs
- Excel and CSV source data

## Repository guide

| Path | Purpose |
|---|---|
| `Uber_Project.pbix` | Ready-to-open Power BI report |
| `Uber_Project_Editable/` | Source-controlled PBIP report and semantic model |
| `Setup_Uber_SQLServer.sql` | SQL Server database, tables, indexes, and views |
| `Uber_Insights_Queries_SQLServer.sql` | SQL Server analysis queries |
| `Uber_Insights_Queries.sql` | SQLite analysis queries |
| `Uber_Query_Results/` | Exported query results for review |
| `Uber Trip Details.xlsx` | Trip-level source data |
| `Location Table.xlsx` | Location lookup data |
| `Images/` | Report visual assets |

## How to explore

1. Open `Uber_Project.pbix` in Power BI Desktop for the fastest review.
2. For source control and model inspection, open `Uber_Project_Editable/Uber_Project.pbip`.
3. To recreate the SQL Server layer, run `Import_Uber_To_SQLServer.bat` on a machine with SQL Server Express and Windows Authentication.
4. Open `Uber_Insights_Queries_SQLServer.sql` in SQL Server Management Studio to reproduce the analysis.

## Data note

The data is used for educational and portfolio analysis. Revenue is presented both as fare-only and fare-plus-surge because the final business definition should be confirmed with the data owner.

## Author

[OmarRez2](https://github.com/OmarRez2)
