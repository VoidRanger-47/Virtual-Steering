@echo off
title VCTRL - Build Android Release APK
cd /d "%~dp0client"

echo =======================================================================
echo  VCTRL - Build & Update Android Release APK
echo =======================================================================
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 'flutter' command was not found in PATH.
    echo Please make sure the Flutter SDK is installed and added to PATH.
    echo.
    pause
    exit /b 1
)

echo Building updated release APK...
flutter build apk --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =======================================================================
    echo [SUCCESS] APK built successfully!
    echo Output file:
    echo   %~dp0client\build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Copy this file to your Android phone to install the updated VCTRL app.
    echo =======================================================================
) else (
    echo.
    echo [ERROR] Build failed. Please review error messages above.
)

echo.
pause
