// SQLite Database Helper for Desktop App
// Converted from Python admin_panel/database.py

import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop
    sqfliteFfiInit();
    
    // Use current directory (where the exe is running or project root in debug)
    final String appDir = Directory.current.path;
    final String dbPath = path.join(appDir, 'local_storage', 'local_data.db');
    
    // Create directory if it doesn't exist
    await Directory(path.dirname(dbPath)).create(recursive: true);
    
    print('📂 New Database path: $dbPath');

    // Use FFI database factory
    final databaseFactory = databaseFactoryFfi;
    
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createTables,
        onOpen: _onOpen,
      ),
    );
    
    return db;
  }

  Future<void> _onOpen(Database db) async {
    // Ensure at least one admin exists if the DB was just created or is empty
    final List<Map<String, dynamic>> admins = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['admin'],
      limit: 1,
    );
    
    if (admins.isEmpty) {
      print('🔐 No admin found, creating default admin...');
      await db.insert('users', {
        'firebase_id': 'admin_default',
        'email': 'admin@demo.com',
        'name': 'System Admin',
        'role': 'admin',
        'password_hash': hashPassword('admin123'),
        'last_sync': DateTime.now().toIso8601String(),
      });
      print('✅ Default admin created: admin@demo.com / admin123');
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT UNIQUE,
        email TEXT NOT NULL,
        name TEXT,
        role TEXT DEFAULT 'user',
        password_hash TEXT,
        last_sync TEXT
      )
    ''');

    // Food records table
    await db.execute('''
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
        synced INTEGER DEFAULT 0
      )
    ''');

    // Food objections table  
    await db.execute('''
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
        synced INTEGER DEFAULT 0
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    print('✅ Database tables created');
  }

  // ==================== PASSWORD UTILITIES ====================

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool verifyPassword(String password, String passwordHash) {
    return hashPassword(password) == passwordHash;
  }

  // ==================== USER OPERATIONS ====================

  Future<List<User>> getUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      orderBy: 'name',
    );
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserByFirebaseId(String firebaseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'firebase_id = ?',
      whereArgs: [firebaseId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<int> addUser({
    String? firebaseId,
    required String email,
    String? name,
    String role = 'user',
    String? password,
  }) async {
    final db = await database;
    final String? passwordHash = password != null ? hashPassword(password) : null;
    
    return await db.insert(
      'users',
      {
        'firebase_id': firebaseId,
        'email': email,
        'name': name,
        'role': role,
        'password_hash': passwordHash,
        'last_sync': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> updateUserPassword(String email, String password) async {
    final db = await database;
    final int count = await db.update(
      'users',
      {'password_hash': hashPassword(password)},
      where: 'email = ?',
      whereArgs: [email],
    );
    return count > 0;
  }

  Future<void> syncUsersFromFirebase(List<Map<String, dynamic>> usersList) async {
    final db = await database;
    for (var user in usersList) {
      await db.insert(
        'users',
        {
          'firebase_id': user['id'],
          'email': user['email'],
          'name': user['name'],
          'role': user['role'] ?? 'user',
          'last_sync': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    print('✅ ${usersList.length} kullanıcı senkronize edildi');
  }

  // ==================== RECORDS OPERATIONS ====================

  Future<List<FoodRecord>> getRecords({String? userId, int? limit}) async {
    final db = await database;
    
    String query = 'SELECT * FROM food_records';
    List<dynamic> args = [];
    
    if (userId != null) {
      query += ' WHERE user_firebase_id = ?';
      args.add(userId);
    }
    
    query += ' ORDER BY created_at DESC';
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }
    
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps.map((map) => FoodRecord.fromMap(map)).toList();
  }

  Future<int> addRecord(FoodRecord record) async {
    final db = await database;
    final int recordId = await db.insert('food_records', record.toMap());
    
    // Add to sync queue
    await db.insert('sync_queue', {
      'table_name': 'food_records',
      'record_id': recordId,
      'action': 'INSERT',
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return recordId;
  }

  Future<bool> deleteRecord(int localId) async {
    final db = await database;
    
    // Get firebase_id first
    final List<Map<String, dynamic>> maps = await db.query(
      'food_records',
      columns: ['firebase_id'],
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    
    final int count = await db.delete(
      'food_records',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    
    // If synced to Firebase, add to delete queue
    if (maps.isNotEmpty && maps.first['firebase_id'] != null) {
      await db.insert('sync_queue', {
        'table_name': 'food_records',
        'record_id': localId,
        'action': 'DELETE',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    return count > 0;
  }

  Future<void> markRecordSynced(int localId, String firebaseId) async {
    final db = await database;
    await db.update(
      'food_records',
      {'synced': 1, 'firebase_id': firebaseId},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<FoodRecord>> getUnsyncedRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'food_records',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => FoodRecord.fromMap(map)).toList();
  }

  // ==================== OBJECTIONS OPERATIONS ====================

  Future<List<FoodObjection>> getObjections({String? status}) async {
    final db = await database;
    
    if (status != null) {
      final List<Map<String, dynamic>> maps = await db.query(
        'food_objections',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'created_at DESC',
      );
      return maps.map((map) => FoodObjection.fromMap(map)).toList();
    } else {
      final List<Map<String, dynamic>> maps = await db.query(
        'food_objections',
        orderBy: 'created_at DESC',
      );
      return maps.map((map) => FoodObjection.fromMap(map)).toList();
    }
  }

  Future<int> addObjection(FoodObjection objection) async {
    final db = await database;
    final int objectionId = await db.insert('food_objections', objection.toMap());
    
    // Add to sync queue
    await db.insert('sync_queue', {
      'table_name': 'food_objections',
      'record_id': objectionId,
      'action': 'INSERT',
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return objectionId;
  }

  Future<bool> updateObjectionStatus({
    required int localId,
    required String status,
    String? adminResponse,
  }) async {
    final db = await database;
    
    final int count = await db.update(
      'food_objections',
      {
        'status': status,
        'admin_response': adminResponse,
        'resolved_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    
    // Add to sync queue
    if (count > 0) {
      await db.insert('sync_queue', {
        'table_name': 'food_objections',
        'record_id': localId,
        'action': 'UPDATE',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    return count > 0;
  }

  Future<void> markObjectionSynced(int localId, String firebaseId) async {
    final db = await database;
    await db.update(
      'food_objections',
      {'synced': 1, 'firebase_id': firebaseId},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<FoodObjection>> getUnsyncedObjections() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'food_objections',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => FoodObjection.fromMap(map)).toList();
  }

  Future<FoodObjection?> getObjectionByFirebaseId(String firebaseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'food_objections',
      where: 'firebase_id = ?',
      whereArgs: [firebaseId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FoodObjection.fromMap(maps.first);
  }

  // ==================== SYNC QUEUE ====================

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'created_at');
  }

  Future<void> clearSyncQueueItem(int itemId) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<SyncStats> getSyncStats() async {
    final db = await database;
    
    final unsyncedRecordsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM food_records WHERE synced = 0',
    );
    final unsyncedRecords = unsyncedRecordsResult.first['count'] as int;
    
    final unsyncedObjectionsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM food_objections WHERE synced = 0',
    );
    final unsyncedObjections = unsyncedObjectionsResult.first['count'] as int;
    
    final queueResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue',
    );
    final queueCount = queueResult.first['count'] as int;
    
    return SyncStats(
      unsyncedRecords: unsyncedRecords,
      unsyncedObjections: unsyncedObjections,
      queueCount: queueCount,
    );
  }

  // ==================== UTILITIES ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
