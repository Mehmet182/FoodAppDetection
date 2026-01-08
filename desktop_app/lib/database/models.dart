// Data models for the food detection app
// Converted from Python database.py

import 'dart:convert';

class User {
  final int? localId;
  final String? firebaseId;
  final String email;
  final String? name;
  final String role;
  final String? passwordHash;
  final DateTime? lastSync;

  User({
    this.localId,
    this.firebaseId,
    required this.email,
    this.name,
    this.role = 'user',
    this.passwordHash,
    this.lastSync,
  });

  // Getter for id (prefers localId)
  int? get id => localId;

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'firebase_id': firebaseId,
      'email': email,
      'name': name,
      'role': role,
      'password_hash': passwordHash,
      'last_sync': lastSync?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      localId: map['local_id'] as int?,
      firebaseId: map['firebase_id'] as String?,
      email: map['email'] as String,
      name: map['name'] as String?,
      role: map['role'] as String? ?? 'user',
      passwordHash: map['password_hash'] as String?,
      lastSync: map['last_sync'] != null 
          ? DateTime.parse(map['last_sync'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': firebaseId ?? localId.toString(),
      'email': email,
      'name': name,
      'role': role,
    };
  }
}

class FoodItem {
  final String name;
  final int count;
  final double price;
  final double total;
  final int calories;

  FoodItem({
    required this.name,
    required this.count,
    required this.price,
    required this.total,
    required this.calories,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'count': count,
      'price': price,
      'total': total,
      'calories': calories,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      name: map['name'] as String,
      count: map['count'] as int,
      price: (map['price'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      calories: map['calories'] as int,
    );
  }

  // Getter for label (alias for name)
  String get label => name;
}

class FoodRecord {
  final int? localId;
  final String? firebaseId;
  final String userFirebaseId;
  final String userName;
  final List<FoodItem> items;
  final double totalPrice;
  final int totalCalories;
  final String? imagePath;
  final String? imageUrl;
  final DateTime createdAt;
  final bool synced;

  FoodRecord({
    this.localId,
    this.firebaseId,
    required this.userFirebaseId,
    required this.userName,
    required this.items,
    required this.totalPrice,
    this.totalCalories = 0,
    this.imagePath,
    this.imageUrl,
    DateTime? createdAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // Getter for userId (alias for userFirebaseId)
  String get userId => userFirebaseId;

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'firebase_id': firebaseId,
      'user_firebase_id': userFirebaseId,
      'user_name': userName,
      'items': jsonEncode(items.map((e) => e.toMap()).toList()),
      'total_price': totalPrice,
      'total_calories': totalCalories,
      'image_path': imagePath,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory FoodRecord.fromMap(Map<String, dynamic> map) {
    List<FoodItem> itemsList = [];
    if (map['items'] != null) {
      try {
        final itemsData = jsonDecode(map['items'] as String) as List;
        itemsList = itemsData.map((e) => FoodItem.fromMap(e as Map<String, dynamic>)).toList();
      } catch (e) {
        print('Error parsing items: $e');
      }
    }

    return FoodRecord(
      localId: map['local_id'] as int?,
      firebaseId: map['firebase_id'] as String?,
      userFirebaseId: map['user_firebase_id'] as String,
      userName: map['user_name'] as String,
      items: itemsList,
      totalPrice: (map['total_price'] as num).toDouble(),
      totalCalories: map['total_calories'] as int? ?? 0,
      imagePath: map['image_path'] as String?,
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': firebaseId ?? localId.toString(),
      'firebase_id': firebaseId,
      'userId': userFirebaseId,
      'userName': userName,
      'items': items.map((e) => e.toMap()).toList(),
      'totalPrice': totalPrice,
      'totalCalories': totalCalories,
      'imageUrl': imageUrl ?? '',
      'createdAt': createdAt.toIso8601String(),
      'synced': synced,
    };
  }
}

class FoodObjection {
  final int? localId;
  final String? firebaseId;
  final int? recordLocalId;
  final String? recordFirebaseId;
  final String userFirebaseId;
  final String userName;
  final String reason;
  final String status;
  final String? adminResponse;
  final int appealCount;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool synced;

  FoodObjection({
    this.localId,
    this.firebaseId,
    this.recordLocalId,
    this.recordFirebaseId,
    required this.userFirebaseId,
    required this.userName,
    required this.reason,
    this.status = 'pending',
    this.adminResponse,
    this.appealCount = 0,
    DateTime? createdAt,
    this.resolvedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'firebase_id': firebaseId,
      'record_local_id': recordLocalId,
      'record_firebase_id': recordFirebaseId,
      'user_firebase_id': userFirebaseId,
      'user_name': userName,
      'reason': reason,
      'status': status,
      'admin_response': adminResponse,
      'appeal_count': appealCount,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory FoodObjection.fromMap(Map<String, dynamic> map) {
    return FoodObjection(
      localId: map['local_id'] as int?,
      firebaseId: map['firebase_id'] as String?,
      recordLocalId: map['record_local_id'] as int?,
      recordFirebaseId: map['record_firebase_id'] as String?,
      userFirebaseId: map['user_firebase_id'] as String,
      userName: map['user_name'] as String,
      reason: map['reason'] as String,
      status: map['status'] as String? ?? 'pending',
      adminResponse: map['admin_response'] as String?,
      appealCount: map['appeal_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'] as String)
          : null,
      synced: (map['synced'] as int) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': firebaseId ?? localId.toString(),
      'firebase_id': firebaseId,
      'recordId': recordFirebaseId ?? recordLocalId.toString(),
      'userId': userFirebaseId,
      'userName': userName,
      'reason': reason,
      'status': status,
      'adminResponse': adminResponse ?? '',
      'appealCount': appealCount,
      'createdAt': createdAt.toIso8601String(),
      'synced': synced,
    };
  }

  FoodObjection copyWith({
    String? status,
    String? adminResponse,
    DateTime? resolvedAt,
  }) {
    return FoodObjection(
      localId: localId,
      firebaseId: firebaseId,
      recordLocalId: recordLocalId,
      recordFirebaseId: recordFirebaseId,
      userFirebaseId: userFirebaseId,
      userName: userName,
      reason: reason,
      status: status ?? this.status,
      adminResponse: adminResponse ?? this.adminResponse,
      appealCount: appealCount,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      synced: false, // Reset sync when updated
    );
  }
}

class SyncStats {
  final int unsyncedRecords;
  final int unsyncedObjections;
  final int queueCount;

  SyncStats({
    required this.unsyncedRecords,
    required this.unsyncedObjections,
    required this.queueCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'unsynced_records': unsyncedRecords,
      'unsynced_objections': unsyncedObjections,
      'queue_count': queueCount,
    };
  }
}
