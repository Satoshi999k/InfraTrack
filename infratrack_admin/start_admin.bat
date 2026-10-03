@echo off
setlocal
cd /d "%~dp0"

echo Starting InfraTrack Admin Portal...
echo.

if not exist "node_modules" (
    echo Installing dependencies for the first run...
    call npm install
    if errorlevel 1 (
        echo.
        echo Dependency installation failed.
        pause
        exit /b 1
    )
)

echo.
echo Admin portal will be available at http://localhost:5173
 echo Node API will be available at http://localhost:3001
 echo.
call npm run dev

pause
