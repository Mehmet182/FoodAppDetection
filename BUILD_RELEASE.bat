@echo off
echo ===================================================
echo 📦 WINDOWS RELEASE PAKETLEME BASLATIYOR
echo ===================================================

echo.
echo [1/5] PyInstaller ve bagimliliklar yukleniyor...
pip install pyinstaller ultralytics fastapi uvicorn python-multipart pillow
if %errorlevel% neq 0 (
    echo ❌ Pip install hatasi!
    exit /b %errorlevel%
)

echo.
echo [2/5] Detection Service (Python) EXE derleniyor...
cd detection_service
pyinstaller --onefile --noconsole --name detection_service main.py
if %errorlevel% neq 0 (
    echo ❌ PyInstaller hatasi!
    cd ..
    exit /b %errorlevel%
)
cd ..

echo.
echo [3/5] Flutter Windows App derleniyor...
cd desktop_app
call flutter build windows --release
if %errorlevel% neq 0 (
    echo ❌ Flutter build hatasi!
    cd ..
    exit /b %errorlevel%
)
cd ..

echo.
echo [4/5] Dagitim klasoru (dist) hazirlaniyor...
if exist dist rmdir /s /q dist
mkdir dist
mkdir dist\detection_service

echo.
echo [5/5] Dosyalar kopyalaniyor...
echo - Flutter dosyalari...
xcopy /s /e /y "desktop_app\build\windows\x64\runner\Release\*" "dist\"

echo - Detection service exe...
copy "detection_service\dist\detection_service.exe" "dist\detection_service\"

echo - Model dosyasi (best.pt)...
if exist "shared\model\best.pt" (
    copy "shared\model\best.pt" "dist\detection_service\"
    echo ✅ Model kopyalandi
) else (
    echo ⚠️ shared\model\best.pt bulunamadi! detection_service\best.pt denenecek...
    if exist "detection_service\best.pt" (
        copy "detection_service\best.pt" "dist\detection_service\"
        echo ✅ Model detection_service klasorunden kopyalandi
    ) else (
        echo ❌ MODEL DOSYASI BULUNAMADI! Lutfen best.pt dosyasini dist\detection_service klasorune elle atin.
    )
)

echo.
echo ===================================================
echo ✅ PAKETLEME TAMAMLANDI!
echo 📂 Cikti klasoru: %CD%\dist
echo 👉 dist klasorunu ziplayip baska bilgisayara tasiyabilirsiniz.
echo ===================================================
dir dist
