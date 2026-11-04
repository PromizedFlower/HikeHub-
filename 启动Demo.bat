@echo off
chcp 65001 >nul
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
echo ============================================
echo   HikeHub Demo - starting...
echo   (A 390x844 window will open shortly)
echo ============================================
echo.
python main.py
if errorlevel 1 (
  echo.
  echo [ERROR] HikeHub failed to start. Please check the message above.
  echo Common fixes:
  echo   1. pip install -r requirements.txt
  echo   2. Make sure .env is in this same folder
  pause
)
