@echo off
echo ========================================
echo    Yemek Tespit - Desktop App
echo ========================================
echo.

cd desktop_app

echo Flutter dependencies yukleniyor...
call flutter pub get

echo.
echo Desktop uygulamasi baslatiliyor...
echo.

call flutter run -d windows

pause
