# 🍽️ Flutter Yemek Tespit Uygulaması

**Canlı kamera görüntüsü ile gerçek zamanlı yemek tespiti yapan Flutter uygulaması.**

## 📱 Özellikler

- 📷 **Canlı Kamera**: Gerçek zamanlı kamera önizleme
- 🎯 **Nesne Tespiti**: TensorFlow Lite ile yemek tespiti
- 💰 **Fiyat Hesaplama**: Tespit edilen yemeklerin anlık fiyat toplamı
- 🎨 **Modern UI**: Dark theme ile şık tasarım
- 📲 **Cross-platform**: Android ve iOS desteği

## 🚀 Kurulum

### 1. Model Dosyasını Ekleyin

```
food_detection_flutter/assets/model.tflite
```

TFLite model dosyanızı `assets` klasörüne kopyalayın.

### 2. Bağımlılıkları Yükleyin

```bash
cd food_detection_flutter
flutter pub get
```

### 3. Çalıştırın

```bash
flutter run
```

## 📁 Proje Yapısı

```
lib/
├── main.dart                    # Uygulama giriş noktası
├── models/
│   ├── food_class.dart          # 18 yemek sınıfı
│   └── detection_result.dart    # Tespit sonuç modeli
├── services/
│   └── object_detector.dart     # TFLite inference
├── screens/
│   └── camera_screen.dart       # Kamera + tespit ekranı
└── widgets/
    ├── detection_overlay.dart   # Bounding box overlay
    └── bottom_panel.dart        # Sonuç ve fiyat paneli
```

## 🍕 Desteklenen Yemekler (18 Sınıf)

Ana Yemek (₺85), Çay (₺15), Çikolata (₺25), Çorba (₺45), Ekmek (₺5), Gözleme (₺55), Haşlanmış Yumurta (₺12), Kek (₺30), Menemen (₺50), Meyve Suyu (₺20), Meze (₺35), Patates Kızartması (₺40), Patates Sosis (₺55), Peynir (₺25), Poğaça (₺18), Su Şişesi (₺10), Yan Yemek (₺45), Zeytin (₺15)

## 🔧 Yapılandırma

`lib/services/object_detector.dart` içinde:

```dart
static const int _inputSize = 640;           // Model input boyutu
static const double _confidenceThreshold = 0.5;  // Min güven oranı
static const double _iouThreshold = 0.45;    // NMS eşiği
```

## ⚙️ Model Dönüşümü

```python
from ultralytics import YOLO
model = YOLO('best.pt')
model.export(format='tflite')
```

Çıktıyı `model.tflite` olarak yeniden adlandırıp `assets/` klasörüne kopyalayın.
