// Scheduled Meal Service for Windows Desktop App
// Uses Firebase REST API for scheduled meals management

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_rest_service.dart';

/// Planlanan yemek modeli (Desktop)
class ScheduledMeal {
  final String? firebaseId;
  final DateTime scheduledDate;
  final List<MealItem> items;
  final double totalPrice;
  final int totalCalories;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  ScheduledMeal({
    this.firebaseId,
    required this.scheduledDate,
    required this.items,
    required this.totalPrice,
    this.totalCalories = 0,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory ScheduledMeal.fromFirestoreRest(Map<String, dynamic> doc, String id) {
    final fields = doc['fields'] ?? {};
    final itemsArray = fields['items']?['arrayValue']?['values'] ?? [];
    
    final items = (itemsArray as List).map<MealItem>((itemValue) {
      final itemFields = itemValue['mapValue']?['fields'] ?? {};
      return MealItem(
        name: itemFields['name']?['stringValue'] ?? '',
        price: double.tryParse(
            (itemFields['price']?['doubleValue'] ?? 
             itemFields['price']?['integerValue'] ?? '0').toString()) ?? 0,
        calories: int.tryParse(
            (itemFields['calories']?['integerValue'] ?? '0').toString()) ?? 0,
        count: int.tryParse(
            (itemFields['count']?['integerValue'] ?? '1').toString()) ?? 1,
      );
    }).toList();

    return ScheduledMeal(
      firebaseId: id,
      scheduledDate: DateTime.tryParse(
          fields['scheduledDate']?['timestampValue'] ?? '') ?? DateTime.now(),
      items: items,
      totalPrice: double.tryParse(
          (fields['totalPrice']?['doubleValue'] ?? 
           fields['totalPrice']?['integerValue'] ?? '0').toString()) ?? 0,
      totalCalories: int.tryParse(
          (fields['totalCalories']?['integerValue'] ?? '0').toString()) ?? 0,
      createdBy: fields['createdBy']?['stringValue'] ?? '',
      createdByName: fields['createdByName']?['stringValue'] ?? '',
      createdAt: DateTime.tryParse(
          fields['createdAt']?['timestampValue'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestoreRest() {
    return {
      'fields': {
        'scheduledDate': {'timestampValue': scheduledDate.toUtc().toIso8601String()},
        'items': {
          'arrayValue': {
            'values': items.map((item) => {
              'mapValue': {
                'fields': {
                  'name': {'stringValue': item.name},
                  'price': {'doubleValue': item.price},
                  'calories': {'integerValue': item.calories.toString()},
                  'count': {'integerValue': item.count.toString()},
                }
              }
            }).toList(),
          }
        },
        'totalPrice': {'doubleValue': totalPrice},
        'totalCalories': {'integerValue': totalCalories.toString()},
        'createdBy': {'stringValue': createdBy},
        'createdByName': {'stringValue': createdByName},
        'createdAt': {'timestampValue': createdAt.toUtc().toIso8601String()},
      }
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
}

/// Planlanan yemek servisi (REST API ile)
class ScheduledMealService {
  static final ScheduledMealService instance = ScheduledMealService._();
  ScheduledMealService._();

  static const String projectId = FirebaseRestService.projectId;
  
  String? get _idToken => FirebaseRestService.instance.isAuthenticated 
      ? FirebaseRestService.instance.isAuthenticated.toString() 
      : null;

  /// Gelecekteki yemekleri getir (bugünden sonraki 7 gün)
  Future<List<ScheduledMeal>> getUpcomingMeals() async {
    try {
      final rest = FirebaseRestService.instance;
      if (!rest.isAuthenticated) {
        print('⚠️ Kimlik doğrulama gerekli');
        return [];
      }

      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/scheduled_meals?pageSize=50';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${_getToken()}'},
      );

      if (response.statusCode != 200) {
        print('❌ Scheduled meals çekilemedi: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final documents = data['documents'] ?? [];
      
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfWeek = startOfToday.add(const Duration(days: 7));

      List<ScheduledMeal> meals = [];
      for (var doc in documents) {
        final id = doc['name']?.split('/').last ?? '';
        final meal = ScheduledMeal.fromFirestoreRest(doc, id);
        
        // Sadece gelecekteki yemekleri al
        if (meal.scheduledDate.isAfter(startOfToday) && 
            meal.scheduledDate.isBefore(endOfWeek)) {
          meals.add(meal);
        }
      }

      // Tarihe göre sırala
      meals.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      return meals;
    } catch (e) {
      print('❌ Upcoming meals hatası: $e');
      return [];
    }
  }

  /// Tüm planlanmış yemekleri getir
  Future<List<ScheduledMeal>> getAllScheduledMeals() async {
    try {
      final rest = FirebaseRestService.instance;
      if (!rest.isAuthenticated) {
        print('⚠️ Kimlik doğrulama gerekli');
        return [];
      }

      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/scheduled_meals?pageSize=100';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${_getToken()}'},
      );

      if (response.statusCode != 200) {
        print('❌ Scheduled meals çekilemedi: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final documents = data['documents'] ?? [];
      
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      List<ScheduledMeal> meals = [];
      for (var doc in documents) {
        final id = doc['name']?.split('/').last ?? '';
        final meal = ScheduledMeal.fromFirestoreRest(doc, id);
        
        // Sadece bugün ve sonrasını al
        if (!meal.scheduledDate.isBefore(startOfToday)) {
          meals.add(meal);
        }
      }

      // Tarihe göre sırala
      meals.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      return meals;
    } catch (e) {
      print('❌ All scheduled meals hatası: $e');
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
      final rest = FirebaseRestService.instance;
      if (!rest.isAuthenticated) {
        print('⚠️ Kimlik doğrulama gerekli');
        return false;
      }

      // Toplam fiyat ve kalori hesapla
      double totalPrice = 0;
      int totalCalories = 0;
      for (var item in items) {
        totalPrice += item.price * item.count;
        totalCalories += item.calories * item.count;
      }

      // Planlanmış günün öğle vakti
      final scheduledDate = DateTime(date.year, date.month, date.day, 12, 0);

      final meal = ScheduledMeal(
        scheduledDate: scheduledDate,
        items: items,
        totalPrice: totalPrice,
        totalCalories: totalCalories,
        createdBy: 'desktop_admin',
        createdByName: createdByName,
        createdAt: DateTime.now(),
      );

      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/scheduled_meals';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getToken()}',
        },
        body: jsonEncode(meal.toFirestoreRest()),
      );

      if (response.statusCode == 200) {
        print('✅ Menü başarıyla planlandı');
        return true;
      } else {
        print('❌ Menü planlanamadı: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Schedule meal hatası: $e');
      return false;
    }
  }

  String _getToken() {
    return FirebaseRestService.instance.idToken ?? '';
  }
}
