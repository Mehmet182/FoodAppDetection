import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

/// Yemek kaydı modeli
class FoodRecord {
  final String id;
  final String userId;
  final String userName;
  final List<FoodItem> items;
  final double totalPrice;
  final int totalCalories;
  final DateTime createdAt;
  final String? imageUrl;
  final String? imagePath;

  FoodRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.items,
    required this.totalPrice,
    this.totalCalories = 0,
    required this.createdAt,
    this.imageUrl,
    this.imagePath,
  });

  factory FoodRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsList = (data['items'] as List<dynamic>?) ?? [];
    
    return FoodRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      items: itemsList.map((item) => FoodItem.fromMap(item)).toList(),
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      totalCalories: (data['totalCalories'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] as String?,
      imagePath: data['imagePath'] as String?,
    );
  }
}

/// Yemek öğesi (kayıt için)
class FoodItem {
  final String label;
  final double price;
  final double confidence;
  final int calories;

  FoodItem({
    required this.label,
    required this.price,
    required this.confidence,
    this.calories = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'price': price,
      'confidence': confidence,
      'calories': calories,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      label: map['label'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Yemek kayıt servisi
class FoodRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Yemek kaydı ekle
  Future<bool> addRecord({
    required List<DetectionResult> detections,
    required double totalPrice,
    required int totalCalories,
    required String userName,
    String? imageUrl,
    String? targetUserId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // Admin başka kullanıcıya kayıt ekleyebilir
      final recordUserId = targetUserId ?? user.uid;

      final items = detections.map((d) => FoodItem(
        label: d.label,
        price: d.price,
        confidence: d.confidence,
        calories: d.calories,
      ).toMap()).toList();

      final recordData = <String, dynamic>{
        'userId': recordUserId,
        'userName': userName,
        'items': items,
        'totalPrice': totalPrice,
        'totalCalories': totalCalories,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      if (imageUrl != null) {
        recordData['imageUrl'] = imageUrl;
      }
      
      await _firestore.collection('food_records').add(recordData);

      return true;
    } catch (e) {
      print('Kayıt eklenemedi: $e');
      return false;
    }
  }

  /// Kullanıcının kendi kayıtlarını getir
  Stream<List<FoodRecord>> getUserRecords(String userId) {
    return _firestore
        .collection('food_records')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => FoodRecord.fromFirestore(doc)).toList());
  }

  /// Tüm kayıtları getir (admin için)
  Stream<List<FoodRecord>> getAllRecords() {
    return _firestore
        .collection('food_records')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => FoodRecord.fromFirestore(doc)).toList());
  }

  /// Belirli kullanıcının kayıtlarını getir (admin için)
  Stream<List<FoodRecord>> getRecordsByUserId(String userId) {
    return _firestore
        .collection('food_records')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => FoodRecord.fromFirestore(doc)).toList());
  }

  /// Tarih aralığına göre kayıtları getir (admin için)
  Future<List<FoodRecord>> getRecordsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    try {
      Query query = _firestore
          .collection('food_records')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      final snapshot = await query.orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) => FoodRecord.fromFirestore(doc)).toList();
    } catch (e) {
      print('Kayıtlar alınamadı: $e');
      return [];
    }
  }

  /// Toplam harcama hesapla
  Future<double> getTotalSpending({String? userId, DateTime? since}) async {
    try {
      Query query = _firestore.collection('food_records');
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (since != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['totalPrice'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      print('Toplam hesaplanamadı: $e');
      return 0;
    }
  }

  /// Tek bir kaydı getir
  Future<FoodRecord?> getRecordById(String recordId) async {
    try {
      final doc = await _firestore.collection('food_records').doc(recordId).get();
      if (doc.exists) {
        return FoodRecord.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Kayıt alınamadı: $e');
      return null;
    }
  }

  /// Kaydın düzenlenebilir olup olmadığını kontrol et (5 dakika kuralı)
  bool canEditRecord(FoodRecord record) {
    final now = DateTime.now();
    final difference = now.difference(record.createdAt);
    return difference.inMinutes < 5;
  }

  /// Kaydı güncelle (5 dakika içinde)
  Future<bool> updateRecord({
    required String recordId,
    required List<FoodItem> items,
    required double totalPrice,
    required int totalCalories,
  }) async {
    try {
      // Önce kaydı al ve 5 dk kontrolü yap
      final record = await getRecordById(recordId);
      if (record == null) return false;
      
      if (!canEditRecord(record)) {
        print('5 dakika geçti, düzenleme yapılamaz');
        return false;
      }

      await _firestore.collection('food_records').doc(recordId).update({
        'items': items.map((item) => item.toMap()).toList(),
        'totalPrice': totalPrice,
        'totalCalories': totalCalories,
      });

      return true;
    } catch (e) {
      print('Kayıt güncellenemedi: $e');
      return false;
    }
  }
}
