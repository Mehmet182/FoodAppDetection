@echo off
chcp 65001 >nul
echo.
echo ========================================
echo   🔍 Yemek Tespit Servisi
echo ========================================
echo.

cd /d "%~dp0detection_service"

echo 🤖 Detection servisi başlatılıyor...
echo.
python main.py

pause
