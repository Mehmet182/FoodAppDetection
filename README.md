# 🍽️ Food Detection App

AI-powered food detection application with desktop (Windows) and mobile (Android) clients. Uses YOLOv8 for real-time food recognition.

## 📁 Project Structure

```
food-detection-app/
├── 🖥️ desktop_app/              ← Flutter Desktop App (Windows)
│   ├── lib/
│   │   ├── database/            ← SQLite database
│   │   ├── services/            ← Firebase, Sync, Detection
│   │   └── screens/             ← Login, Dashboard
│   └── pubspec.yaml
│
├── 🔍 detection_service/        ← Python YOLO Detection API
│   ├── main.py                  ← FastAPI server (port 8000)
│   └── requirements.txt
│
├── 📱 food_detection_flutter/   ← Flutter Mobile App (Android)
│   ├── lib/
│   └── android/
│
├── 🔗 shared/                   ← Shared Resources
│   ├── firebase_credentials.json.template
│   └── model/best.pt           ← YOLO model (not in repo)
│
├── START_DESKTOP_APP.bat        ← Quick start for Windows
└── START_DETECTION_SERVICE.bat  ← Manual service start
```

## ✨ Features

- **AI Food Detection**: YOLOv8 powered real-time food recognition
- **Offline-First**: Works without internet, syncs when online
- **Cross-Platform**: Windows desktop + Android mobile
- **Firebase Integration**: Cloud sync and authentication
- **Admin Panel**: Full user and record management (Desktop)

## 🚀 Quick Start

### Prerequisites

- **Python 3.8+** with pip
- **Flutter 3.0+** with Windows desktop support
- **Firebase Project** (for cloud features)

### 1. Clone & Setup

```bash
git clone https://github.com/YOUR_USERNAME/food-detection-app.git
cd food-detection-app
```

### 2. Install Dependencies

**Detection Service (Python):**
```bash
cd detection_service
pip install -r requirements.txt
```

**Desktop App (Flutter):**
```bash
cd desktop_app
flutter pub get
```

**Mobile App (Flutter):**
```bash
cd food_detection_flutter
flutter pub get
```

### 3. Setup Firebase (Optional - for cloud sync)

1. Copy the template:
   ```bash
   cp shared/firebase_credentials.json.template shared/firebase_credentials.json
   ```
2. Replace placeholder values with your Firebase service account credentials

### 4. Add YOLO Model

Download or train a YOLOv8 model and place it at:
```
shared/model/best.pt
```

### 5. Run the Application

**Windows Desktop (Recommended):**
```bash
# Option 1: Double-click START_DESKTOP_APP.bat

# Option 2: Manual
cd desktop_app
flutter run -d windows
```

> ✅ Detection service starts automatically in background

**Android Mobile:**
```bash
cd food_detection_flutter
flutter run
```

## 🔐 Default Login

| Role  | Email               | Password   |
|-------|---------------------|------------|
| Admin | admin@example.com   | admin123   |

## 💻 Development

### Debug Mode

```bash
# Desktop
cd desktop_app
flutter run -d windows

# Mobile
cd food_detection_flutter
flutter run
```

### Production Build

```bash
# Windows EXE
cd desktop_app
flutter build windows --release
# Output: build/windows/x64/runner/Release/

# Android APK
cd food_detection_flutter
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Manual Detection Service

```bash
cd detection_service
python main.py
# Runs on http://localhost:8000
```

## 🗄️ Database

**Local SQLite** (Desktop):
```
%USERPROFILE%\Documents\food_detection_app\local_data.db
```

**Tables:**
- `users` - User accounts
- `food_records` - Detection records
- `food_objections` - User objections
- `sync_queue` - Pending sync items

## 🔧 Troubleshooting

<details>
<summary><strong>Detection service not working?</strong></summary>

1. Check Python installation: `python --version`
2. Install dependencies: `pip install -r detection_service/requirements.txt`
3. Verify model exists: `shared/model/best.pt`
4. Run manually: `python detection_service/main.py`

</details>

<details>
<summary><strong>Flutter app not starting?</strong></summary>

```bash
flutter clean
flutter pub get
flutter run -d windows
```

</details>

<details>
<summary><strong>Firebase connection issues?</strong></summary>

- Verify `shared/firebase_credentials.json` exists and is valid
- Check internet connection
- App works offline, sync resumes when online

</details>

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| Desktop App | Flutter Windows |
| Mobile App | Flutter Android |
| Detection API | Python + FastAPI + YOLOv8 |
| Local Database | SQLite |
| Cloud Database | Firebase Firestore |
| Authentication | Firebase Auth |

## 📄 License

This project is for educational purposes.

---

**Made with ❤️ using Flutter & YOLOv8**
