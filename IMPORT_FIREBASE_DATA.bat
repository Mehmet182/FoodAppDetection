@echo off
echo ========================================
echo  Firebase Verilerini SQLite'a Aktar
echo ========================================
echo.

cd desktop_app

echo Firebase Admin SDK kuruluyor...
pip install -r import_requirements.txt

echo.
echo Firebase verilerini aktarma baslatiliyor...
python import_firebase_data.py

echo.
echo ========================================
echo  Tamamlandi!
echo ========================================
pause
