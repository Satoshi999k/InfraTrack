@echo off
setlocal
set "PROJECT_DIR=%~dp0"
set "FLUTTER_BAT=D:\Download folder\flutter\bin\flutter.bat"
set "PORT=8080"

if not exist "%FLUTTER_BAT%" (
  echo Flutter was not found at:
  echo %FLUTTER_BAT%
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$connections = Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue; $connections | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"
cd /d "%PROJECT_DIR%"
echo Restarting InfraTrack at http://localhost:%PORT%
start "InfraTrack Flutter Server" powershell -NoExit -ExecutionPolicy Bypass -Command "Set-Location -LiteralPath '%PROJECT_DIR%'; & '%FLUTTER_BAT%' run -d web-server --web-port %PORT%"
endlocal
