@echo off
title Virtual Driving Controller - Install ViGEmBus Driver
cd /d "%~dp0"

echo =======================================================================
echo  Virtual Driving Controller - Driver Installer
echo =======================================================================
echo.
echo Installing bundled ViGEmBus driver (Xbox 360 controller virtual bus)...
echo.

if not exist "drivers\ViGEmBus_Setup.exe" (
    echo [ERROR] drivers\ViGEmBus_Setup.exe not found!
    pause
    exit /b 1
)

echo Launching installer...
start /wait "" "drivers\ViGEmBus_Setup.exe"

echo.
echo [OK] Driver installation finished.
echo You can now start the server with 'run_server.bat'.
echo.
pause
