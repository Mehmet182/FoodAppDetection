import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Planlanan yemek modeli
class ScheduledMeal {
  final String id;
  final DateTime scheduledDate;
  final List<MealItem> items;
  final double totalPrice;
  final int totalCalories;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  ScheduledMeal({
    required this.id,
    required this.scheduledDate,
    required this.items,
    required this.totalPrice,
    this.totalCalories = 0,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory ScheduledMeal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsList = (data['items'] as List<dynamic>?) ?? [];
    
    return ScheduledMeal(
      id: doc.id,
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: itemsList.map((item) => MealItem.fromMap(item)).toList(),
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      totalCalories: (data['totalCalories'] as num?)?.toInt() ?? 0,
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'items': items.map((item) => item.toMap()).toList(),
      'totalPrice': totalPrice,
      'totalCalories': totalCalories,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Menü öğesi
class MealItem {
  final String name;
  final double price;
  final int calories;
  final int count;

  MealItem({
    required this.name,
    required this.price,
    this.calories = 0,
    this.count = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'calories': calories,
      'count': count,
    };
  }

  factory MealItem.fromMap(Map<String, dynamic> map) {
    return MealItem(
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      count: (map['count'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Planlanan yemek servisi
class ScheduledMealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gelecekteki yemekleri getir (bugünden sonraki 7 gün)
  Stream<List<ScheduledMeal>> getUpcomingMeals() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    return _firestore
        .collection('scheduled_meals')
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfWeek))
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ScheduledMeal.fromFirestore(doc)).toList());
  }

  /// Belirli bir günün yemeklerini getir
  Future<List<ScheduledMeal>> getMealsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final snapshot = await _firestore
          .collection('scheduled_meals')
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      return snapshot.docs.map((doc) => ScheduledMeal.fromFirestore(doc)).toList();
    } catch (e) {
      print('Günlük yemek alınamadı: $e');
      return [];
    }
  }

  /// Yemek planla (Admin için)
  Future<bool> scheduleMeal({
    required DateTime date,
    required List<MealItem> items,
    required String createdByName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Toplam fiyat ve kalori hesapla
      double totalPrice = 0;
      int totalCalories = 0;
      for (var item in items) {
        totalPrice += item.price * item.count;
        totalCalories += item.calories * item.count;
      }

      // Planlanmış günün başlangıcını al (saat 00:00)
      final scheduledDate = DateTime(date.year, date.month, date.day, 12, 0); // Öğle vakti

      final meal = ScheduledMeal(
        id: '',
        scheduledDate: scheduledDate,
        items: items,
        totalPrice: totalPrice,
        totalCalories: totalCalories,
        createdBy: user.uid,
        createdByName: createdByName,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('scheduled_meals').add(meal.toMap());
      return true;
    } catch (e) {
      print('Yemek planlanamadı: $e');
      return false;
    }
  }

  /// Planlanan yemeği güncelle
  Future<bool> updateScheduledMeal({
    required String mealId,
    required List<MealItem> items,
  }) async {
    try {
      double totalPrice = 0;
      int totalCalories = 0;
      for (var item in items) {
        totalPrice += item.price * item.count;
        totalCalories += item.calories * item.count;
      }

      await _firestore.collection('scheduled_meals').doc(mealId).update({
        'items': items.map((item) => item.toMap()).toList(),
        'totalPrice': totalPrice,
        'totalCalories': totalCalories,
      });

      return true;
    } catch (e) {
      print('Yemek güncellenemedi: $e');
      return false;
    }
  }

  /// Planlanan yemeği sil
  Future<bool> deleteScheduledMeal(String mealId) async {
    try {
      await _firestore.collection('scheduled_meals').doc(mealId).delete();
      return true;
    } catch (e) {
      print('Yemek silinemedi: $e');
      return false;
    }
  }

  /// Tüm planlanmış yemekleri getir (Admin için)
  Stream<List<ScheduledMeal>> getAllScheduledMeals() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection('scheduled_meals')
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ScheduledMeal.fromFirestore(doc)).toList());
  }
}
