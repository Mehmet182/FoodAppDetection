# 🍽️ Food Detection Application

AI-powered food detection system with **Windows Desktop** and **Android Mobile** applications. Uses YOLO (You Only Look Once) deep learning model for real-time food recognition.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)

---

## 📱 Screenshots

<!-- Add your screenshots here -->
| Windows Desktop App | Android Mobile App |
|:---:|:---:|
| Admin Dashboard | Food Detection |

---

## 🎯 Features

### Windows Desktop App (Admin Panel)
- 📊 **Dashboard** - Statistics overview and service status
- 👥 **User Management** - View and manage users
- 🍽️ **Food Records** - View all food detection records
- ⚠️ **Objections** - Handle user objections
- 🔄 **Firebase Sync** - Sync data with cloud
- 💾 **Offline-First** - Works without internet (SQLite)

### Android Mobile App
- 📷 **Camera Detection** - Real-time food detection via camera
- 🖼️ **Gallery Import** - Detect food from gallery images
- 💰 **Price Calculation** - Automatic price calculation
- ☁️ **Cloud Storage** - Firebase integration
- 👤 **User Auth** - Firebase Authentication

---

## 🏗️ Project Structure

```
food-detection-app/
│
├── 🖥️ desktop_app/              # Flutter Windows Application
│   ├── lib/
│   │   ├── database/            # SQLite database & models
│   │   ├── services/            # Firebase, Sync, Detection services
│   │   ├── screens/             # Login, Dashboard screens
│   │   └── main.dart
│   └── pubspec.yaml
│
├── 📱 food_detection_flutter/    # Flutter Android Application
│   ├── lib/
│   │   ├── models/              # Data models
│   │   ├── services/            # API, Auth, Storage services
│   │   ├── screens/             # App screens
│   │   └── widgets/             # Reusable widgets
│   └── pubspec.yaml
│
├── 🔍 detection_service/         # Python YOLO Detection API
│   ├── main.py                  # FastAPI server
│   └── requirements.txt
│
├── 🔗 shared/                    # Shared Resources
│   ├── model/best.pt            # YOLO trained model
│   └── firebase_credentials.json.template
│
└── 📄 firebase_credentials.json.template  # Firebase config template
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** >= 3.0.0
- **Python** >= 3.8
- **Firebase Project** (for cloud features)

### 1️⃣ Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/food-detection-app.git
cd food-detection-app
```

### 2️⃣ Setup Detection Service

```bash
cd detection_service
pip install -r requirements.txt
```

> ⚠️ **Important:** Download the YOLO model file and place it in `shared/model/` folder.
> 
> **📥 Model Download:**
> - [Download from GitHub Releases](https://github.com/YOUR_USERNAME/food-detection-app/releases/latest)
> - Or [Google Drive Link](YOUR_GOOGLE_DRIVE_LINK_HERE)

### 3️⃣ Setup Firebase (Optional)

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Copy `firebase_credentials.json.template` to `firebase_credentials.json`
3. Fill in your Firebase credentials

---

## 🖥️ Windows Desktop App

### Installation

```bash
cd desktop_app
flutter pub get
```

### Run Development

```bash
flutter run -d windows
```

### Build Release

```bash
flutter build windows --release
```

**Output:** `desktop_app/build/windows/x64/runner/Release/`

### Quick Start (Batch)

```bash
# Just double-click:
START_DESKTOP_APP.bat
```

> ✅ Detection service starts automatically in background

### Default Login

| Email | Password |
|-------|----------|
| admin@example.com | admin123 |

---

## 📱 Android Mobile App

### Installation

```bash
cd food_detection_flutter
flutter pub get
```

### Configure Firebase

1. Create Android app in Firebase Console
2. Download `google-services.json`
3. Place it in `android/app/` folder

### Run Development

```bash
flutter run
```

### Build APK

```bash
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Configure Server URL

Edit `lib/services/api_service.dart` to set your detection API URL:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000';
```

---

## 🔍 Detection Service API

### Run Locally

```bash
cd detection_service
python main.py
```

Server runs on `http://localhost:8000`

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API status |
| GET | `/health` | Health check |
| POST | `/detect` | Food detection (multipart/form-data) |

### Example Request

```bash
curl -X POST "http://localhost:8000/detect" \
  -F "file=@food_image.jpg"
```

### Response

```json
{
  "success": true,
  "count": 3,
  "detections": [
    {
      "label": "ana-yemek",
      "confidence": 0.95,
      "price": 55.0,
      "calories": 450,
      "box": { "x1": 100, "y1": 50, "x2": 300, "y2": 250 }
    }
  ]
}
```

### Supported Foods

| Food | Price (TL) | Calories |
|------|-----------|----------|
| ana-yemek | 55.00 | 450 |
| corba | 35.00 | 150 |
| menemen | 40.00 | 200 |
| gozleme | 45.00 | 350 |
| patates-kizartmasi | 25.00 | 320 |
| ekmek | 5.00 | 80 |
| cay | 10.00 | 2 |
| su-sisesi | 10.00 | 0 |
| meyvesuyu | 20.00 | 120 |
| ... | ... | ... |

---

## 🗄️ Database

### Windows App (SQLite)

Location: `%USERPROFILE%\Documents\food_detection_app\local_data.db`

**Tables:**
- `users` - User accounts
- `food_records` - Food detection records
- `food_objections` - User objections
- `sync_queue` - Pending sync items

### Mobile App (Firebase Firestore)

Collections in Firebase:
- `users`
- `foodRecords`
- `objections`

---

## 📁 Environment Setup

### Firebase Credentials

Create `firebase_credentials.json` from template:

```json
{
  "api_key": "YOUR_API_KEY",
  "auth_domain": "YOUR_PROJECT.firebaseapp.com",
  "project_id": "YOUR_PROJECT_ID",
  "storage_bucket": "YOUR_PROJECT.appspot.com",
  "messaging_sender_id": "YOUR_SENDER_ID",
  "app_id": "YOUR_APP_ID",
  "database_url": "https://YOUR_PROJECT.firebaseio.com"
}
```

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| Desktop UI | Flutter (Windows) |
| Mobile UI | Flutter (Android) |
| Detection API | FastAPI + Uvicorn |
| ML Model | YOLO (Ultralytics) |
| Local DB | SQLite |
| Cloud DB | Firebase Firestore |
| Auth | Firebase Auth |
| Storage | Firebase Storage |

---

## 📋 Requirements

### Python Dependencies

```txt
fastapi
uvicorn
ultralytics
pillow
python-multipart
```

### Flutter Dependencies

See `pubspec.yaml` in each app folder.

---

## 🔧 Troubleshooting

### Detection service not starting?

```bash
# Check Python
python --version

# Install dependencies
cd detection_service
pip install -r requirements.txt

# Run manually
python main.py
```

### Windows app build fails?

```bash
cd desktop_app
flutter clean
flutter pub get
flutter run -d windows
```

### Firebase connection issues?

1. Check `firebase_credentials.json` exists
2. Verify Firebase project settings
3. Check internet connection

---

## 📄 License

This project is for educational purposes.

---

## 👨‍💻 Author

Developed with ❤️

---

**Version:** 2.1 | **Last Updated:** January 2026
