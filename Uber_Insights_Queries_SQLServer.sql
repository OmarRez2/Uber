/*
    Uber Trip Analysis - Microsoft SQL Server / T-SQL version
    Server: .\SQLEXPRESS
    Database: Uber
*/

USE [Uber];
GO

SET NOCOUNT ON;

-- 1) Confirm the grain: one row = one trip
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT trip_id) AS distinct_trip_ids,
    COUNT(*) - COUNT(DISTINCT trip_id) AS duplicate_trip_ids
FROM dbo.trips;

-- 2) Core KPIs: keep both revenue definitions until the business confirms one
SELECT
    COUNT(*) AS total_bookings,
    ROUND(SUM(fare_amount), 2) AS fare_total,
    ROUND(SUM(surge_fee), 2) AS surge_total,
    ROUND(SUM(fare_amount + surge_fee), 2) AS booking_value_including_surge,
    ROUND(AVG(fare_amount), 2) AS average_fare,
    ROUND(AVG(fare_amount + surge_fee), 2) AS average_booking_value,
    ROUND(SUM(trip_distance), 2) AS total_trip_distance,
    ROUND(AVG(trip_distance), 2) AS average_trip_distance,
    ROUND(AVG(duration_minutes), 2) AS raw_average_trip_time
FROM dbo.trips;

-- 3) Quality checks required before efficiency analysis
SELECT
    SUM(CASE WHEN duration_minutes <= 0 THEN 1 ELSE 0 END) AS invalid_duration,
    SUM(CASE WHEN speed_mph > 100 THEN 1 ELSE 0 END) AS speed_over_100_mph,
    SUM(CASE WHEN duration_minutes > 240 THEN 1 ELSE 0 END) AS duration_over_4_hours,
    SUM(CASE WHEN trip_distance <= 0 THEN 1 ELSE 0 END) AS invalid_distance,
    SUM(CASE WHEN fare_amount <= 0 THEN 1 ELSE 0 END) AS invalid_fare
FROM dbo.trips;

-- 4) Vehicle performance grid
SELECT
    vehicle,
    COUNT(*) AS total_bookings,
    ROUND(SUM(fare_amount), 2) AS fare_total,
    ROUND(AVG(fare_amount), 2) AS average_fare,
    ROUND(SUM(trip_distance), 2) AS total_distance,
    ROUND(AVG(trip_distance), 2) AS average_distance,
    ROUND(AVG(duration_minutes), 2) AS average_duration
FROM dbo.trips
GROUP BY vehicle
ORDER BY total_bookings DESC;

-- 5) Payment mix and Surge behavior
SELECT
    payment_type,
    COUNT(*) AS bookings,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.trips), 2) AS booking_share_pct,
    ROUND(SUM(fare_amount), 2) AS fare_total,
    ROUND(SUM(surge_fee), 2) AS surge_total,
    SUM(CASE WHEN surge_fee > 0 THEN 1 ELSE 0 END) AS surge_bookings,
    ROUND(100.0 * AVG(CASE WHEN surge_fee > 0 THEN 1.0 ELSE 0.0 END), 2) AS surge_rate_pct
FROM dbo.trips
GROUP BY payment_type
ORDER BY bookings DESC;

-- 6) Passenger-count mix
SELECT
    passenger_count,
    COUNT(*) AS bookings,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.trips), 2) AS share_pct,
    ROUND(AVG(fare_amount), 2) AS average_fare,
    ROUND(AVG(trip_distance), 2) AS average_distance
FROM dbo.trips
GROUP BY passenger_count
ORDER BY passenger_count;

-- 7) Daily bookings and revenue
SELECT
    pickup_date,
    COUNT(*) AS bookings,
    ROUND(SUM(fare_amount), 2) AS fare_total,
    ROUND(AVG(fare_amount), 2) AS average_fare
FROM dbo.trips
GROUP BY pickup_date
ORDER BY pickup_date;

-- 8) Correct weekday comparison: normalize for number of occurrences
;WITH daily AS
(
    SELECT
        pickup_date,
        weekday_number,
        weekday,
        COUNT(*) AS bookings
    FROM dbo.trips
    GROUP BY pickup_date, weekday_number, weekday
)
SELECT
    weekday_number,
    weekday,
    COUNT(*) AS occurrences,
    SUM(bookings) AS total_bookings,
    ROUND(AVG(CAST(bookings AS DECIMAL(18, 2))), 2) AS average_bookings_per_occurrence
FROM daily
GROUP BY weekday_number, weekday
ORDER BY weekday_number;

-- 9) Pickup-time analysis by hour
SELECT
    pickup_hour,
    COUNT(*) AS bookings,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.trips), 2) AS share_pct,
    ROUND(AVG(fare_amount), 2) AS average_fare
FROM dbo.trips
GROUP BY pickup_hour
ORDER BY bookings DESC;

-- 10) Pickup-time analysis by 10-minute bucket
SELECT
    ten_minute_bucket,
    COUNT(*) AS bookings
FROM dbo.trips
GROUP BY ten_minute_bucket
ORDER BY bookings DESC;

-- 11) Day vs Night (Day = 06:00-17:59)
SELECT
    day_night,
    COUNT(*) AS bookings,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.trips), 2) AS share_pct,
    ROUND(SUM(fare_amount), 2) AS fare_total,
    ROUND(AVG(fare_amount), 2) AS average_fare,
    ROUND(AVG(trip_distance), 2) AS average_distance,
    ROUND(AVG(duration_minutes), 2) AS average_duration
FROM dbo.trips
GROUP BY day_night;

-- 12) Top pickup locations
SELECT TOP (10)
    t.pu_location_id,
    l.location,
    l.city,
    COUNT(*) AS bookings,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.trips), 2) AS share_pct
FROM dbo.trips AS t
JOIN dbo.locations AS l
  ON t.pu_location_id = l.location_id
GROUP BY t.pu_location_id, l.location, l.city
ORDER BY bookings DESC;

-- 13) Top drop-off locations
SELECT TOP (10)
    t.do_location_id,
    l.location,
    l.city,
    COUNT(*) AS bookings
FROM dbo.trips AS t
JOIN dbo.locations AS l
  ON t.do_location_id = l.location_id
GROUP BY t.do_location_id, l.location, l.city
ORDER BY bookings DESC;

-- 14) Most common routes
SELECT TOP (10)
    pu.location AS pickup_location,
    dro.location AS dropoff_location,
    COUNT(*) AS trips,
    ROUND(AVG(t.fare_amount), 2) AS average_fare,
    ROUND(AVG(t.trip_distance), 2) AS average_distance,
    ROUND(AVG(t.duration_minutes), 2) AS average_duration
FROM dbo.trips AS t
JOIN dbo.locations AS pu
  ON t.pu_location_id = pu.location_id
JOIN dbo.locations AS dro
  ON t.do_location_id = dro.location_id
GROUP BY t.pu_location_id, t.do_location_id, pu.location, dro.location
ORDER BY trips DESC;

-- 15) Farthest trips for outlier review
SELECT TOP (10)
    t.trip_id,
    t.trip_distance,
    ROUND(t.duration_minutes, 2) AS duration_minutes,
    ROUND(t.speed_mph, 2) AS speed_mph,
    ROUND(t.fare_amount, 2) AS fare_amount,
    ROUND(t.surge_fee, 2) AS surge_fee,
    pu.location AS pickup_location,
    dro.location AS dropoff_location
FROM dbo.trips AS t
JOIN dbo.locations AS pu
  ON t.pu_location_id = pu.location_id
JOIN dbo.locations AS dro
  ON t.do_location_id = dro.location_id
ORDER BY t.trip_distance DESC;

-- 16) Most preferred vehicle at each pickup location
;WITH vehicle_rank AS
(
    SELECT
        t.pu_location_id,
        l.location,
        t.vehicle,
        COUNT(*) AS bookings,
        ROW_NUMBER() OVER
        (
            PARTITION BY t.pu_location_id
            ORDER BY COUNT(*) DESC, t.vehicle
        ) AS vehicle_rank
    FROM dbo.trips AS t
    JOIN dbo.locations AS l
      ON t.pu_location_id = l.location_id
    GROUP BY t.pu_location_id, l.location, t.vehicle
)
SELECT
    pu_location_id,
    location,
    vehicle,
    bookings
FROM vehicle_rank
WHERE vehicle_rank = 1
ORDER BY bookings DESC;

-- 17) Clean efficiency metrics
SELECT
    COUNT(*) AS valid_trips,
    ROUND(AVG(fare_amount / NULLIF(trip_distance, 0)), 2) AS average_fare_per_mile,
    ROUND(AVG(fare_amount / NULLIF(duration_minutes, 0)), 2) AS average_fare_per_minute,
    ROUND(AVG(speed_mph), 2) AS average_speed_mph
FROM dbo.trips
WHERE duration_minutes > 0
  AND duration_minutes <= 240
  AND speed_mph <= 100;
