# 🚀 Flutter Windows App - Kullanım Kılavuzu

## 📋 Gereksinimler

- Flutter SDK yüklü olmalı
- Python yüklü olmalı
- Admin panel dosyaları `admin_panel/` klasöründe olmalı

## 🎯 Nasıl Çalıştırılır?

### 1️⃣ Geliştirme Modunda Çalıştırma

```bash
# Desktop app klasörüne git
cd desktop_app

# Uygulamayı çalıştır
flutter run -d windows
```

### 2️⃣ Release Build (EXE Dosyası)

```bash
# Desktop app klasörüne git
cd desktop_app

# Release build yap
flutter build windows --release

# Çıktı:
# desktop_app\build\windows\x64\runner\Release\desktop_app.exe
```

## 💡 Uygulama Kullanımı

### Ana Ekran (Dashboard)
1. **Backend Başlat** - Python backend'i başlatır
2. **Backend Durdur** - Backend'i kapatır
3. **Admin Panel Aç** - Tarayıcıda admin paneli açar
4. **Firebase Sync** - Firebase'den veri çeker

### Log Görüntüleme
- Backend başlatınca log'lar altta görünür
- Hatalar ve bildirimler burada gösterilir

### Admin Panel
- "Admin Panel Aç" butonuna tıkla
- Varsayılan tarayıcında http://localhost:5000 açılır
- Admin hesabıyla giriş yap

## 🔧 Sorun Giderme

### Backend başlamıyor?
```
Kontrol et:
- Python yüklü mü? (python --version)
- admin_panel/ klasörü doğru yerde mi?
- admin_panel/app.py var mı?
```

### Admin panel açılmıyor?
```
- Önce "Backend Başlat" butonuna tıkla
- Backend çalışıyor mu kontrol et (loglar bakın)
- Tarayıcıda manuel http://localhost:5000 dene
```

## 📦 Dağıtım için

Release build sonrası bu klasörü paylaş:
```
desktop_app\build\windows\x64\runner\Release\
```

Tüm dosyaları birlikte kopyala ve `desktop_app.exe` çalıştır.

## 🎨 Özellikler

✅ Terminal yok, sadece GUI
✅ Backend otomatik yönetimi
✅ Canlı log görüntüleme
✅ Firebase sync desteği
✅ Modern dark tema
