"""
Firebase'den verileri çekip SQLite'a aktaran script
Windows build problemi olmadan Firebase verilerini kullanmak için
"""

import firebase_admin
from firebase_admin import credentials, firestore, auth
import sqlite3
import hashlib
from datetime import datetime
import json
import os

# Firebase credentials
cred = credentials.Certificate('../shared/firebase_credentials.json')
firebase_admin.initialize_app(cred)

db_firestore = firestore.client()

# SQLite database path
DB_PATH = os.path.join(os.path.expanduser('~'), 'Documents', 'food_detection_app', 'local_data.db')

# Dizini oluştur
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

def get_db():
    """SQLite bağlantısı"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Database tablolarını oluştur"""
    conn = get_db()
    cursor = conn.cursor()
    
    # Users
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_id TEXT UNIQUE,
            email TEXT NOT NULL,
            name TEXT,
            role TEXT DEFAULT 'user',
            password_hash TEXT,
            last_sync TEXT
        )
    ''')
    
    # Food records
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS food_records (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_id TEXT,
            user_firebase_id TEXT,
            user_name TEXT,
            items TEXT,
            total_price REAL,
            total_calories INTEGER,
            image_path TEXT,
            image_url TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            synced INTEGER DEFAULT 1
        )
    ''')
    
    # Food objections
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS food_objections (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            firebase_id TEXT,
            record_local_id INTEGER,
            record_firebase_id TEXT,
            user_firebase_id TEXT,
            user_name TEXT,
            reason TEXT,
            status TEXT DEFAULT 'pending',
            admin_response TEXT,
            appeal_count INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            resolved_at TEXT,
            synced INTEGER DEFAULT 1
        )
    ''')
    
    # Sync queue
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            record_id INTEGER NOT NULL,
            action TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()
    print("✅ Database tabloları oluşturuldu")

def hash_password(password):
    """Şifreyi hashle"""
    return hashlib.sha256(password.encode()).hexdigest()

def import_users():
    """Firebase'den kullanıcıları çek"""
    print("\n📥 Kullanıcılar Firebase'den çekiliyor...")
    
    conn = get_db()
    cursor = conn.cursor()
    
    # Firebase Authentication'dan kullanıcıları çek
    try:
        page = auth.list_users()
        count = 0
        
        while page:
            for user in page.users:
                # Firestore'dan user detaylarını çek
                user_doc = db_firestore.collection('users').document(user.uid).get()
                
                if user_doc.exists:
                    user_data = user_doc.to_dict()
                    
                    cursor.execute('''
                        INSERT OR REPLACE INTO users (firebase_id, email, name, role, last_sync)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (
                        user.uid,
                        user.email,
                        user_data.get('name', user.display_name),
                        user_data.get('role', 'user'),
                        datetime.now().isoformat()
                    ))
                    count += 1
                    print(f"  ✓ {user.email} - {user_data.get('role', 'user')}")
            
            page = page.get_next_page()
        
        conn.commit()
        print(f"✅ {count} kullanıcı aktarıldı")
    except Exception as e:
        print(f"❌ Kullanıcı import hatası: {e}")
    finally:
        conn.close()

def import_records():
    """Firebase'den kayıtları çek"""
    print("\n📥 Yemek kayıtları Firebase'den çekiliyor...")
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        records_ref = db_firestore.collection('food_records').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(500)
        docs = records_ref.stream()
        
        count = 0
        for doc in docs:
            data = doc.to_dict()
            
            cursor.execute('''
                INSERT OR REPLACE INTO food_records 
                (firebase_id, user_firebase_id, user_name, items, total_price, total_calories, image_url, created_at, synced)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
            ''', (
                doc.id,
                data.get('userId'),
                data.get('userName'),
                json.dumps(data.get('items', [])),
                data.get('totalPrice', 0),
                data.get('totalCalories', 0),
                data.get('imageUrl', ''),
                data.get('createdAt').isoformat() if data.get('createdAt') else datetime.now().isoformat()
            ))
            count += 1
        
        conn.commit()
        print(f"✅ {count} kayıt aktarıldı")
    except Exception as e:
        print(f"❌ Kayıt import hatası: {e}")
    finally:
        conn.close()

def import_objections():
    """Firebase'den itirazları çek"""
    print("\n📥 İtirazlar Firebase'den çekiliyor...")
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        objections_ref = db_firestore.collection('food_objections').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(200)
        docs = objections_ref.stream()
        
        count = 0
        for doc in docs:
            data = doc.to_dict()
            
            cursor.execute('''
                INSERT OR REPLACE INTO food_objections 
                (firebase_id, record_firebase_id, user_firebase_id, user_name, reason, status, admin_response, appeal_count, created_at, resolved_at, synced)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            ''', (
                doc.id,
                data.get('recordId'),
                data.get('userId'),
                data.get('userName'),
                data.get('reason'),
                data.get('status', 'pending'),
                data.get('adminResponse'),
                data.get('appealCount', 0),
                data.get('createdAt').isoformat() if data.get('createdAt') else datetime.now().isoformat(),
                data.get('resolvedAt').isoformat() if data.get('resolvedAt') else None
            ))
            count += 1
        
        conn.commit()
        print(f"✅ {count} itiraz aktarıldı")
    except Exception as e:
        print(f"❌ İtiraz import hatası: {e}")
    finally:
        conn.close()

def set_admin_password():
    """Admin şifresi ayarla"""
    print("\n🔐 Admin şifresi ayarlanıyor...")
    
    conn = get_db()
    cursor = conn.cursor()
    
    # Admin kullanıcısını bul
    cursor.execute("SELECT * FROM users WHERE role = 'admin' LIMIT 1")
    admin = cursor.fetchone()
    
    if admin:
        # Varsayılan şifre: admin123
        password_hash = hash_password('admin123')
        cursor.execute('UPDATE users SET password_hash = ? WHERE local_id = ?', (password_hash, admin['local_id']))
        conn.commit()
        print(f"✅ Admin şifresi ayarlandı: {admin['email']} / admin123")
    else:
        print("⚠️ Admin kullanıcısı bulunamadı")
    
    conn.close()

if __name__ == '__main__':
    print("=" * 60)
    print("Firebase → SQLite Veri Aktarımı")
    print("=" * 60)
    
    # 1. Database oluştur
    init_db()
    
    # 2. Kullanıcıları aktar
    import_users()
    
    # 3. Kayıtları aktar
    import_records()
    
    # 4. Admin şifresi ayarla
    set_admin_password()
    
    print("\n" + "=" * 60)
    print("✅ Veriler başarıyla aktarıldı!")
    print("📂 Database: " + DB_PATH)
    print("=" * 60)
