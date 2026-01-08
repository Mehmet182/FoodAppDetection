"""
Food Detection API - FastAPI Backend
AWS EC2'de çalıştırılacak
"""

from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
from PIL import Image
import io
import uvicorn

app = FastAPI(title="Food Detection API")

# CORS - tüm kaynaklardan istek kabul et
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Model ve class bilgileri
model = None
class_names = {}

# Gerçek class fiyatları
CLASS_PRICES = {
    "ana-yemek": 55.0,
    "cay": 10.0,
    "cikolata": 15.0,
    "corba": 35.0,
    "ekmek": 5.0,
    "gozleme": 45.0,
    "haslanmis-yumurta": 8.0,
    "kek": 25.0,
    "menemen": 40.0,
    "meyvesuyu": 20.0,
    "meze": 30.0,
    "patates-kizartmasi": 25.0,
    "patates-sosis": 35.0,
    "peynir": 20.0,
    "pogoca": 12.0,
    "su-sisesi": 10.0,
    "yan-yemek": 30.0,
    "zeytin": 15.0,
}

# Kalori bilgileri (tahmini)
CLASS_CALORIES = {
    "ana-yemek": 450,
    "cay": 2,
    "cikolata": 220,
    "corba": 150,
    "ekmek": 80,
    "gozleme": 350,
    "haslanmis-yumurta": 78,
    "kek": 280,
    "menemen": 200,
    "meyvesuyu": 120,
    "meze": 180,
    "patates-kizartmasi": 320,
    "patates-sosis": 380,
    "peynir": 110,
    "pogoca": 180,
    "su-sisesi": 0,
    "yan-yemek": 200,
    "zeytin": 50,
}

@app.on_event("startup")
async def load_model():
    global model, class_names
    try:
        import sys
        import os
        
        # Model yolunu belirle
        if getattr(sys, 'frozen', False):
            # Exe olarak çalışıyor - model exe'nin yanında olmalı
            base_dir = os.path.dirname(sys.executable)
            model_path = os.path.join(base_dir, "best.pt")
        else:
            # Script olarak çalışıyor
            # Önce shared altındakini dene
            model_path = "../shared/model/best.pt"
            if not os.path.exists(model_path):
                # Bulamazsa current dir dene
                model_path = "best.pt"
            
        print(f"📂 Model yolu: {model_path}")
        
        model = YOLO(model_path)
        class_names = model.names
        
        print("✅ YOLO model yüklendi")
        print(f"📋 Sınıflar ({len(class_names)} adet):")
        for class_id, name in class_names.items():
            price = CLASS_PRICES.get(name, 30.0)
            print(f"   ID: {class_id}  ->  İsim: {name}  ->  Fiyat: {price} TL")
    except Exception as e:
        print(f"❌ Model yükleme hatası: {e}")

@app.get("/")
def root():
    return {"status": "ok", "message": "Food Detection API"}

@app.get("/health")
def health():
    return {"status": "healthy", "model_loaded": model is not None}

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    """Görüntüde yemek tespiti yap"""
    
    if model is None:
        return {"error": "Model yüklenemedi", "detections": []}
    
    try:
        # Görüntüyü oku
        contents = await file.read()
        
        # PIL decompression bomb limitini kaldır
        Image.MAX_IMAGE_PIXELS = None
        
        image = Image.open(io.BytesIO(contents))
        
        # RGB'ye çevir
        if image.mode != "RGB":
            image = image.convert("RGB")
        
        # Büyük görüntüleri küçült (max 1280px)
        max_size = 1280
        if image.width > max_size or image.height > max_size:
            ratio = min(max_size / image.width, max_size / image.height)
            new_size = (int(image.width * ratio), int(image.height * ratio))
            image = image.resize(new_size, Image.Resampling.LANCZOS)
            print(f"📐 Görüntü küçültüldü: {new_size}")
        
        # YOLO inference - threshold 0.70
        results = model.predict(source=image, conf=0.70, verbose=False)
        
        detections = []
        
        for result in results:
            boxes = result.boxes
            if boxes is not None:
                for box in boxes:
                    class_id = int(box.cls[0])
                    confidence = float(box.conf[0])
                    x1, y1, x2, y2 = box.xyxy[0].tolist()
                    
                    # Model'in kendi class ismini kullan
                    label = class_names.get(class_id, f"Class {class_id}")
                    price = CLASS_PRICES.get(label, 30.0)
                    calories = CLASS_CALORIES.get(label, 200)
                    
                    detections.append({
                        "class_id": class_id,
                        "label": label,
                        "confidence": round(confidence, 3),
                        "price": price,
                        "calories": calories,
                        "box": {
                            "x1": round(x1, 1),
                            "y1": round(y1, 1),
                            "x2": round(x2, 1),
                            "y2": round(y2, 1),
                        }
                    })
        
        return {
            "success": True,
            "count": len(detections),
            "image_width": image.width,
            "image_height": image.height,
            "detections": detections
        }
        
    except Exception as e:
        return {"error": str(e), "detections": []}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
