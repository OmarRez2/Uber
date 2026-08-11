/*
    Creates a safe, reusable SQL Server database for the Uber project.
    This script does not drop or truncate existing tables.
*/

USE [master];
GO

IF DB_ID(N'Uber') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [Uber];');
END;
GO

USE [Uber];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.location_table', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.location_table
    (
        location_id SMALLINT NOT NULL,
        location NVARCHAR(100) NOT NULL,
        city NVARCHAR(50) NOT NULL,
        CONSTRAINT PK_location_table PRIMARY KEY CLUSTERED (location_id)
    );
END;

IF OBJECT_ID(N'dbo.official_taxi_zones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.official_taxi_zones
    (
        location_id SMALLINT NOT NULL,
        borough NVARCHAR(50) NOT NULL,
        zone NVARCHAR(100) NOT NULL,
        service_zone NVARCHAR(50) NOT NULL,
        CONSTRAINT PK_official_taxi_zones PRIMARY KEY CLUSTERED (location_id)
    );
END;

IF OBJECT_ID(N'dbo.trip_details', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.trip_details
    (
        trip_id INT NOT NULL,
        pickup_time DATETIME2(0) NOT NULL,
        dropoff_time DATETIME2(0) NOT NULL,
        passenger_count TINYINT NOT NULL,
        trip_distance DECIMAL(8, 2) NOT NULL,
        pu_location_id SMALLINT NOT NULL,
        do_location_id SMALLINT NOT NULL,
        fare_amount DECIMAL(10, 2) NOT NULL,
        surge_fee DECIMAL(10, 2) NOT NULL,
        vehicle NVARCHAR(30) NOT NULL,
        payment_type NVARCHAR(30) NOT NULL,
        CONSTRAINT PK_trip_details PRIMARY KEY CLUSTERED (trip_id)
    );
END;

IF OBJECT_ID(N'dbo.FK_trip_details_pickup_location', N'F') IS NULL
BEGIN
    ALTER TABLE dbo.trip_details WITH CHECK
        ADD CONSTRAINT FK_trip_details_pickup_location
        FOREIGN KEY (pu_location_id)
        REFERENCES dbo.location_table (location_id);
END;

IF OBJECT_ID(N'dbo.FK_trip_details_dropoff_location', N'F') IS NULL
BEGIN
    ALTER TABLE dbo.trip_details WITH CHECK
        ADD CONSTRAINT FK_trip_details_dropoff_location
        FOREIGN KEY (do_location_id)
        REFERENCES dbo.location_table (location_id);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.trip_details')
      AND name = N'IX_trip_details_pickup_time'
)
    CREATE INDEX IX_trip_details_pickup_time
        ON dbo.trip_details (pickup_time);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.trip_details')
      AND name = N'IX_trip_details_pickup_location'
)
    CREATE INDEX IX_trip_details_pickup_location
        ON dbo.trip_details (pu_location_id);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.trip_details')
      AND name = N'IX_trip_details_dropoff_location'
)
    CREATE INDEX IX_trip_details_dropoff_location
        ON dbo.trip_details (do_location_id);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.trip_details')
      AND name = N'IX_trip_details_vehicle'
)
    CREATE INDEX IX_trip_details_vehicle
        ON dbo.trip_details (vehicle);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.trip_details')
      AND name = N'IX_trip_details_payment_type'
)
    CREATE INDEX IX_trip_details_payment_type
        ON dbo.trip_details (payment_type);
GO

CREATE OR ALTER VIEW dbo.locations
AS
SELECT
    location_id,
    location,
    city
FROM dbo.location_table;
GO

CREATE OR ALTER VIEW dbo.trips
AS
SELECT
    td.trip_id,
    td.pickup_time AS pickup,
    td.dropoff_time AS dropoff,
    td.passenger_count,
    td.trip_distance,
    td.pu_location_id,
    td.do_location_id,
    td.fare_amount,
    td.surge_fee,
    td.vehicle,
    td.payment_type,
    CAST(
        DATEDIFF_BIG(SECOND, td.pickup_time, td.dropoff_time) / 60.0
        AS DECIMAL(12, 4)
    ) AS duration_minutes,
    CAST(
        td.trip_distance * 3600.0
        / NULLIF(DATEDIFF_BIG(SECOND, td.pickup_time, td.dropoff_time), 0)
        AS DECIMAL(18, 6)
    ) AS speed_mph,
    CAST(td.fare_amount + td.surge_fee AS DECIMAL(11, 2)) AS booking_value,
    CAST(td.pickup_time AS DATE) AS pickup_date,
    DATEPART(HOUR, td.pickup_time) AS pickup_hour,
    CAST(
        DATEDIFF(DAY, CONVERT(DATE, '19000101', 112), CAST(td.pickup_time AS DATE)) % 7 + 1
        AS TINYINT
    ) AS weekday_number,
    CHOOSE(
        DATEDIFF(DAY, CONVERT(DATE, '19000101', 112), CAST(td.pickup_time AS DATE)) % 7 + 1,
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
    ) AS weekday,
    CONCAT(
        RIGHT('0' + CONVERT(VARCHAR(2), DATEPART(HOUR, td.pickup_time)), 2),
        ':',
        RIGHT(
            '0' + CONVERT(VARCHAR(2), (DATEPART(MINUTE, td.pickup_time) / 10) * 10),
            2
        )
    ) AS ten_minute_bucket,
    CASE
        WHEN DATEPART(HOUR, td.pickup_time) BETWEEN 6 AND 17 THEN 'Day'
        ELSE 'Night'
    END AS day_night
FROM dbo.trip_details AS td;
GO

PRINT 'Uber schema and views are ready.';
GO
