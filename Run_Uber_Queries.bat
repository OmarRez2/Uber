@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo =============================================
echo Running Uber SQL queries...
echo =============================================
echo.

where python >nul 2>&1
if not errorlevel 1 (
    python "%~dp0run_uber_queries.py"
    set "RUN_EXIT=%ERRORLEVEL%"
) else (
    where py >nul 2>&1
    if errorlevel 1 (
        echo ERROR: Python is not installed or not available in PATH.
        set "RUN_EXIT=1"
    ) else (
        py -3 "%~dp0run_uber_queries.py"
        set "RUN_EXIT=%ERRORLEVEL%"
    )
)

echo.
if "%RUN_EXIT%"=="0" (
    echo Finished successfully.
    echo Open the folder: Uber_Query_Results
) else (
    echo The queries did not finish. Read the error message above.
)

if /I not "%~1"=="/nopause" pause
exit /b %RUN_EXIT%
