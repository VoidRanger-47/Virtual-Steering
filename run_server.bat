@echo off
title Virtual Driving Controller - PC Host
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =======================================================================
echo  Virtual Driving Controller - Host Server
echo =======================================================================
echo.

:: 1. Check Python installation
python --version >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python is not installed or not in your PATH.
    echo Please install Python 3.10+ from https://python.org.
    pause
    exit /b 1
)

:: 2. Install Python packages if missing
echo Checking required Python dependencies...
python -m pip install -r server\requirements.txt --quiet

:: 3. Test if ViGEm driver is active
set "PYTHONPATH=%~dp0server;%PYTHONPATH%"
python -c "import vgamepad as vg; pad = vg.VX360Gamepad()" >nul 2>nul
if %ERRORLEVEL% EQU 0 goto START_SERVER

echo.
echo =======================================================================
echo  [NOTICE] ViGEmBus driver is required for Xbox 360 controller emulation.
echo  Installing bundled driver now...
echo =======================================================================
echo.
if exist "drivers\ViGEmBus_Setup.exe" (
    start /wait "" "drivers\ViGEmBus_Setup.exe"
) else (
    echo [WARN] drivers\ViGEmBus_Setup.exe was not found.
)

:START_SERVER
echo.
echo Starting PC receiver server on 0.0.0.0:5005...
cd /d "%~dp0\server"
python server.py

pause
