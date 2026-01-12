# 🍽️ Yemek Tespit Uygulaması

## 📁 PROJE YAPISI

```
food-detection-app/
│
├── 🖥️ desktop_app/              ← FLUTTER DESKTOP UYGULAMASI
│   ├── lib/
│   │   ├── database/            ← SQLite database
│   │   ├── services/            ← Firebase, Sync, Detection
│   │   ├── screens/             ← Login, Dashboard
│   │   └── main.dart
│   └── pubspec.yaml
│
├── 🔍 detection_service/        ← PYTHON YOLO SERVİSİ (Otomatik Başlar)
│   ├── main.py
│   └── requirements.txt
│
├── 📱 mobile/                   ← FLUTTER MOBİL APP
│   └── food_detection_flutter/  ← Uzak sunucu ile çalışır
│
├── 🔗 shared/                   ← ORTAK KAYNAKLAR
│   ├── firebase_credentials.json
│   └── model/best.pt
│
└── 🚀 START_DESKTOP_APP.bat     ← Tek tıkla başlat
```

## ✨ MİMARİ

### Desktop App (Windows)
- **Flutter Desktop**: Tam fonksiyonel admin paneli
- **SQLite**: Yerel veritabanı (offline)
- **Firebase**: Cloud sync (online)
- **Python Detection**: Otomatik arka planda başlar (**terminal görünmez**)

### Mobile App
- **Flutter Mobile**: Uzak sunucuya bağlanır
- **Detection Service**: Uzaktaki API'yi kullanır

## 🚀 KULLANIM

### Basit Başlatma (Önerilen)

```bash
# Tek tıkla başlat:
START_DESKTOP_APP.bat
```

> ✅ Detection service otomatik arka planda başlar
> ✅ Terminal penceresi görünmez
> ✅ Kullanıcı hiçbir şey yapmasına gerek yok

### Manuel Başlatma (Geliştirme)

```bash
cd desktop_app
flutter run -d windows
```

### İlk Kurulum

```bash
# 1. Detection service dependencies
cd detection_service
pip install -r requirements.txt

# 2. Desktop app dependencies
cd ../desktop_app
flutter pub get
```

## 🔐 GİRİŞ

**Varsayılan Admin:**
- Email: `admin@example.com`
- Şifre: `admin123`

> Login ekranında giriş yapın. Detection service otomatik başlayacak.

## 📊 ÖZELLİKLER

- ✅ **Otomatik Başlatma**: Detection service kendiliğinden başlar
- ✅ **Terminal Yok**: Python arka planda gizli çalışır
- ✅ **Offline-First**: İnternet olmadan çalışır
- ✅ **Auto-Sync**: Firebase ile otomatik senkronizasyon
- ✅ **Dashboard**: İstatistikler ve servis durumu
- ✅ **Kullanıcı Yönetimi**: Kullanıcı listesi
- ✅ **Kayıtlar**: Yemek tespit kayıtları
- ✅ **İtirazlar**: Kullanıcı itirazları

## 🔧 TEKNİK DETAYLAR

### Detection Service
- **Port**: 8000 (localhost)
- **Başlatma**: Otomatik (pythonw.exe - terminal yok)
- **Durum**: Desktop app içinden kontrol edilebilir

### Database
```
%USERPROFILE%\Documents\food_detection_app\local_data.db
```

Tablolar:
- `users` - Kullanıcılar
- `food_records` - Yemek kayıtları
- `food_objections` - İtirazlar
- `sync_queue` - Senkronizasyon

### Firebase
Credentials dosyası:
```
shared/firebase_credentials.json
```

## 📱 MOBİL UYGULAMA

Mobil app **uzak sunucu** ile çalışır:

```bash
cd mobile/food_detection_flutter
flutter run
```

> Mobil uygulama desktop detection service'i kullanmaz, kendi remote API'sini kullanır.

## 🏗️ GELİŞTİRME

### Debug Mode
```bash
cd desktop_app
flutter run -d windows
```

### Release Build
```bash
cd desktop_app
flutter build windows --release
```

EXE:
```
desktop_app/build/windows/x64/runner/Release/desktop_app.exe
```

## 🐛 SORUN ÇÖZME

### Detection service çalışmıyor?

1. **Python kurulu mu?**
```bash
python --version
```

2. **Dependencies yüklü mü?**
```bash
cd detection_service
pip install -r requirements.txt
```

3. **Model dosyası var mı?**
```
shared/model/best.pt
```

4. **Manuel başlatma**
```bash
cd detection_service
python main.py
```

### Desktop app başlamıyor?

```bash
cd desktop_app
flutter clean
flutter pub get
flutter run -d windows
```

### Firebase bağlanamıyor?

```
shared/firebase_credentials.json
```
Dosyasını kontrol edin.

## 🎯 FARKLAR

### Önceki Versiyon ❌
- Flask backend gerekiyordu
- Tarayıcıda açılıyordu
- Manuel başlatma gerekiyordu
- Terminal pencereleri açılıyordu

### Yeni Versiyon ✅
- Flask yok, sadece Flutter
- Tarayıcı gerekmiyor
- Otomatik başlatma
- Terminal görünmüyor
- Tek EXE dosyası

---

**v2.1** - Seamless Desktop Experience (No Terminal Windows)
