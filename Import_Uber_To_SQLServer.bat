@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

set "SERVER=.\SQLEXPRESS"
set "DATABASE=Uber"
set "DATA_DIR=%~dp0sqlserver_import_data"

echo =============================================
echo Importing Uber data into SQL Server Express
echo Server: %SERVER%
echo Database: %DATABASE%
echo =============================================
echo.

where python >nul 2>nul
if not errorlevel 1 (
    python "%~dp0prepare_sqlserver_data.py"
) else (
    where py >nul 2>nul
    if errorlevel 1 (
        echo ERROR: Python was not found.
        goto :error
    )
    py -3 "%~dp0prepare_sqlserver_data.py"
)
if errorlevel 1 goto :error

echo.
echo Creating the database objects...
sqlcmd -S "%SERVER%" -E -No -b -i "%~dp0Setup_Uber_SQLServer.sql"
if errorlevel 1 goto :error

set "CURRENT_COUNTS="
for /f "usebackq delims=" %%A in (`sqlcmd -S "%SERVER%" -E -No -d "%DATABASE%" -h -1 -W -Q "SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT_BIG(*) FROM dbo.trip_details),'|',(SELECT COUNT_BIG(*) FROM dbo.location_table),'|',(SELECT COUNT_BIG(*) FROM dbo.official_taxi_zones));"`) do set "CURRENT_COUNTS=%%A"

if "%CURRENT_COUNTS%"=="103728|265|265" (
    echo Data is already imported. Running verification only...
    goto :verify
)

if not "%CURRENT_COUNTS%"=="0|0|0" (
    echo ERROR: The database contains a partial or different import: %CURRENT_COUNTS%
    echo No rows were changed. Review the existing tables before retrying.
    goto :error
)

echo.
echo Loading location_table...
bcp "%DATABASE%.dbo.location_table" in "%DATA_DIR%\location_table.tsv" -S "%SERVER%" -T -Yo -u -c -C 65001 -b 1000 -q
if errorlevel 1 goto :error

echo.
echo Loading official_taxi_zones...
bcp "%DATABASE%.dbo.official_taxi_zones" in "%DATA_DIR%\official_taxi_zones.tsv" -S "%SERVER%" -T -Yo -u -c -C 65001 -b 1000 -q
if errorlevel 1 goto :error

echo.
echo Loading trip_details...
bcp "%DATABASE%.dbo.trip_details" in "%DATA_DIR%\trip_details.tsv" -S "%SERVER%" -T -Yo -u -c -C 65001 -b 10000 -q
if errorlevel 1 goto :error

:verify
echo.
echo Verifying row counts and relationships...
sqlcmd -S "%SERVER%" -E -No -d "%DATABASE%" -b -Q "SET NOCOUNT ON; SELECT 'trip_details' AS table_name, COUNT_BIG(*) AS row_count FROM dbo.trip_details UNION ALL SELECT 'location_table', COUNT_BIG(*) FROM dbo.location_table UNION ALL SELECT 'official_taxi_zones', COUNT_BIG(*) FROM dbo.official_taxi_zones; IF (SELECT COUNT_BIG(*) FROM dbo.trip_details) <> 103728 THROW 50001, 'Unexpected trip_details row count.', 1; IF EXISTS (SELECT 1 FROM dbo.trip_details AS t LEFT JOIN dbo.location_table AS p ON p.location_id=t.pu_location_id LEFT JOIN dbo.location_table AS d ON d.location_id=t.do_location_id WHERE p.location_id IS NULL OR d.location_id IS NULL) THROW 50002, 'An invalid location reference was found.', 1;"
if errorlevel 1 goto :error

echo.
echo Testing all 17 SQL Server queries...
sqlcmd -S "%SERVER%" -E -No -b -i "%~dp0Uber_Insights_Queries_SQLServer.sql" -o "%~dp0SQLServer_Query_Test_Output.txt"
if errorlevel 1 goto :error

echo.
echo SUCCESS: Uber is ready in SQL Server.
echo Open SSMS and connect to: %SERVER%
echo Then select database: %DATABASE%
echo Query file: Uber_Insights_Queries_SQLServer.sql
goto :finish

:error
echo.
echo IMPORT FAILED. Read the error above; no automatic delete was performed.
if /i not "%~1"=="/nopause" pause
exit /b 1

:finish
if /i not "%~1"=="/nopause" pause
exit /b 0
