@echo off
title VCTRL - Allow UDP 5005 in Windows Firewall
cd /d "%~dp0"

echo =======================================================================
echo  VCTRL - Windows Firewall Port Rule (UDP 5005)
echo =======================================================================
echo.
echo Adding inbound firewall rule for UDP port 5005...
netsh advfirewall firewall add rule name="VCTRL-Host-UDP-5005" dir=in action=allow protocol=UDP localport=5005

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Port 5005 UDP is now allowed through Windows Firewall!
    echo Your phone can now communicate with this PC over Wi-Fi.
) else (
    echo.
    echo [ERROR] Failed to add rule. Please RIGHT-CLICK this file and choose
    echo         "Run as administrator".
)

echo.
pause
