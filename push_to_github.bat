@echo off
title VCTRL - Push to GitHub
cd /d "%~dp0"

echo =======================================================================
echo  VCTRL - Push Repository to GitHub
echo =======================================================================
echo.
echo Target Remote: https://github.com/VoidRanger-47/Virtual-Steering.git
echo Current Branch: main
echo.
echo If prompted for Username, enter: VoidRanger-47
echo If prompted for Password, enter your GitHub Personal Access Token (PAT).
echo (Generate token at: https://github.com/settings/tokens with 'repo' scope)
echo.
git push -u origin main
echo.
if %ERRORLEVEL% EQU 0 (
    echo =======================================================================
    echo [SUCCESS] Repository pushed to GitHub successfully!
    echo URL: https://github.com/VoidRanger-47/Virtual-Steering
    echo =======================================================================
) else (
    echo.
    echo [NOTE] If authentication failed:
    echo 1. Go to https://github.com/settings/tokens
    echo 2. Click "Generate new token (classic)"
    echo 3. Check the "repo" box and click "Generate token"
    echo 4. Paste that token when prompted for Password.
)
echo.
pause
