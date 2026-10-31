@echo off
rem Map checker: double-click to run. Stop it any time (close the window); the next run
rem goes on where it stopped. Optional: run_map_check.cmd [seeds per setting] [pages at once]
cd /d "%~dp0"
where node >nul 2>nul || (echo Node.js is not installed. & pause & exit /b 1)
if not exist node_modules\playwright-core (
  echo Installing the browser driver, once...
  call npm install playwright-core@1.48.2 --no-audit --no-fund --loglevel=error || (pause & exit /b 1)
)
rem Low priority, so the computer stays usable while it runs.
start "Map check" /low /b /wait node run-check.js %*
echo.
echo Finished. Results: SUMMARY_map_check.md
pause
