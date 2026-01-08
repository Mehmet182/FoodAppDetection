# 🍽️ Food Detection App

AI destekli yemek tespit uygulaması. **Windows Desktop** ve **Android** platformlarında çalışır.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)

---

## � Proje Yapısı

```
food-detection-app/
├── desktop_app/           # Windows Masaüstü Uygulaması (Admin Panel)
├── food_detection_flutter/ # Android Mobil Uygulama
├── detection_service/      # Python YOLO API
└── shared/model/           # YOLO Model (best.pt)
```

---

## ⚙️ Kurulum

### 1. Model İndir

📥 **[Model İndir (best.pt)](https://github.com/Mehmet182/FoodAppDetection/releases/download/v1.0.0/best.pt)**

İndirdikten sonra `shared/model/` klasörüne koy.

### 2. Python Bağımlılıkları

```bash
cd detection_service
pip install -r requirements.txt
```

### 3. Flutter Bağımlılıkları

```bash
# Windows App
cd desktop_app
flutter pub get

# Android App
cd food_detection_flutter
flutter pub get
```

---

## 🖥️ Windows Uygulaması

### Çalıştır

```bash
# Kolay yol - çift tıkla:
START_DESKTOP_APP.bat

# Veya manuel:
cd desktop_app
flutter run -d windows
```

### Demo Hesapları

| Rol | Email | Şifre |
|-----|-------|-------|
| 👨‍💼 Admin | mehmet@gmail.com | mehmet123 |
| 👤 User | emre@gmail.com | emre123 |

### Özellikler
- � Dashboard - İstatistikler
- 👥 Kullanıcı Yönetimi
- 🍽️ Yemek Kayıtları
- ⚠️ İtiraz Yönetimi
- 🔄 Firebase Senkronizasyon
- 💾 Offline Çalışma (SQLite)

---

## 📱 Android Uygulaması

### Firebase Kurulumu

1. [Firebase Console](https://console.firebase.google.com) → Yeni proje oluştur
2. Android uygulaması ekle
3. `google-services.json` indir
4. `food_detection_flutter/android/app/` klasörüne koy

### Çalıştır

```bash
cd food_detection_flutter
flutter run
```

### Özellikler
- 📷 Kamera ile Yemek Tespiti
- 🖼️ Galeriden Resim Analizi
- 💰 Otomatik Fiyat Hesaplama
- ☁️ Firebase Entegrasyonu

---

## 🔍 Detection API

```bash
cd detection_service
python main.py
```

**Endpoint:** `http://localhost:8000`

| Method | URL | Açıklama |
|--------|-----|----------|
| GET | `/health` | Durum kontrolü |
| POST | `/detect` | Yemek tespiti |

---

## 🍽️ Desteklenen Yemekler

| Yemek | Fiyat | Kalori |
|-------|-------|--------|
| Ana Yemek | 55₺ | 450 |
| Çorba | 35₺ | 150 |
| Menemen | 40₺ | 200 |
| Gözleme | 45₺ | 350 |
| Patates Kızartması | 25₺ | 320 |
| Ekmek | 5₺ | 80 |
| Çay | 10₺ | 2 |
| Su | 10₺ | 0 |

---

## �️ Teknolojiler

| Bileşen | Teknoloji |
|---------|-----------|
| Desktop UI | Flutter Windows |
| Mobile UI | Flutter Android |
| API | FastAPI |
| ML Model | YOLOv8 |
| Local DB | SQLite |
| Cloud | Firebase |

---

## � Lisans

Eğitim amaçlı proje.
