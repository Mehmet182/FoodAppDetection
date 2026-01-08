import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// İtiraz durumları
enum ObjectionStatus {
  pending,   // Beklemede
  approved,  // Onaylandı
  rejected,  // Reddedildi
}

/// Yemek itirazı modeli
class FoodObjection {
  final String id;
  final String recordId;
  final String userId;
  final String userName;
  final String reason;
  final ObjectionStatus status;
  final DateTime createdAt;
  final String? adminResponse;
  final int appealCount; // Kaç kere itiraz edildi (max 2)

  FoodObjection({
    required this.id,
    required this.recordId,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.adminResponse,
    this.appealCount = 1,
  });

  bool get canReAppeal => status == ObjectionStatus.rejected && appealCount < 2;

  factory FoodObjection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodObjection(
      id: doc.id,
      recordId: data['recordId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      reason: data['reason'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminResponse: data['adminResponse'],
      appealCount: data['appealCount'] ?? 1,
    );
  }

  static ObjectionStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return ObjectionStatus.approved;
      case 'rejected':
        return ObjectionStatus.rejected;
      default:
        return ObjectionStatus.pending;
    }
  }

  static String _statusToString(ObjectionStatus status) {
    switch (status) {
      case ObjectionStatus.approved:
        return 'approved';
      case ObjectionStatus.rejected:
        return 'rejected';
      default:
        return 'pending';
    }
  }
}

/// İtiraz servisi
class ObjectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// İtiraz ekle
  Future<bool> addObjection({
    required String recordId,
    required String reason,
    required String userName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await _firestore.collection('food_objections').add({
        'recordId': recordId,
        'userId': user.uid,
        'userName': userName,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'appealCount': 1,
      });

      return true;
    } catch (e) {
      print('İtiraz eklenemedi: $e');
      return false;
    }
  }

  /// Kullanıcının itirazlarını getir
  Stream<List<FoodObjection>> getUserObjections(String userId) {
    return _firestore
        .collection('food_objections')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FoodObjection.fromFirestore(doc)).toList());
  }

  /// Tüm itirazları getir (admin için)
  Stream<List<FoodObjection>> getAllObjections() {
    return _firestore
        .collection('food_objections')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FoodObjection.fromFirestore(doc)).toList());
  }

  /// Bekleyen itirazları getir (admin için)
  Stream<List<FoodObjection>> getPendingObjections() {
    return _firestore
        .collection('food_objections')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FoodObjection.fromFirestore(doc)).toList());
  }

  /// İtiraz durumunu güncelle (admin için)
  Future<bool> updateObjectionStatus({
    required String objectionId,
    required ObjectionStatus status,
    String? adminResponse,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': FoodObjection._statusToString(status),
      };
      
      if (adminResponse != null) {
        updateData['adminResponse'] = adminResponse;
      }

      await _firestore
          .collection('food_objections')
          .doc(objectionId)
          .update(updateData);

      return true;
    } catch (e) {
      print('İtiraz güncellenemedi: $e');
      return false;
    }
  }

  /// Belirli kayda ait itiraz var mı kontrol et
  Future<bool> hasObjection(String recordId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('food_objections')
          .where('recordId', isEqualTo: recordId)
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Tekrar itiraz et (reddedilen itirazı yeniden aç)
  Future<bool> reAppeal({
    required String objectionId,
    required String newReason,
  }) async {
    try {
      // Mevcut itirazı al
      final doc = await _firestore.collection('food_objections').doc(objectionId).get();
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      final currentAppealCount = data['appealCount'] ?? 1;
      
      // Max 2 itiraz kontrolü
      if (currentAppealCount >= 2) return false;
      
      // İtirazı güncelle
      await _firestore.collection('food_objections').doc(objectionId).update({
        'status': 'pending',
        'reason': newReason,
        'adminResponse': null,
        'appealCount': currentAppealCount + 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Tekrar itiraz edilemedi: $e');
      return false;
    }
  }
}
