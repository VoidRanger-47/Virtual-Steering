@echo off
title Virtual Driving Controller - USB Reverse Tether
echo =======================================================================
echo  Virtual Driving Controller - USB ADB Low-Latency Reverse Tunnel
echo =======================================================================
echo.
echo Checking for ADB (Android Debug Bridge)...

where adb >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 'adb' command was not found in PATH.
    echo Please install Android platform-tools or add Android SDK to PATH.
    echo.
    pause
    exit /b 1
)

echo [OK] ADB found. Checking connected Android devices...
adb devices
echo.

echo Forwarding UDP port 5005 from Android device to PC localhost...
echo Setting up: adb reverse tcp:5005 tcp:5005
adb reverse tcp:5005 tcp:5005

echo.
echo [OK] Reverse tunnel configured!
echo.
echo Now:
echo   1. In the mobile app, tap 'USB' mode or set host to: 127.0.0.1
echo   2. Run 'run_server.bat' to start the PC host receiver.
echo.
pause
