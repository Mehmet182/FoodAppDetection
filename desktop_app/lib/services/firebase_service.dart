import '../database/models.dart' as models;
import 'firebase_rest_service.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final FirebaseRestService _rest = FirebaseRestService.instance;

  bool get isInitialized => _rest.isOnline;

  /// Initialize Firebase
  Future<bool> initialize(String credentialsPath) async {
    return await _rest.checkOnline();
  }

  /// Login
  Future<models.User?> login(String email, String password) async {
    final uid = await _rest.login(email, password);
    if (uid != null) {
      String role = 'user'; // Default
      String name = email.split('@').first;
      String firebaseId = uid;

      // Fetch actual user details from Firestore
      final details = await _rest.getUserDetails(uid);
      if (details != null) {
        if (details['role'] != null) role = details['role'];
        if (details['name'] != null) name = details['name'];
        // Note: details might keys might vary, ensured safety in REST service
      }

      return models.User(
        firebaseId: firebaseId,
        email: email,
        name: name,
        role: role,
        passwordHash: password, // Store password (or hash) for local verification
      );
    }
    return null;
  }

  /// Logout
  Future<void> logout() async {
    // Implement token clearing if necessary in FirebaseRestService
  }

  /// Get users (delegated to REST if needed)
  Future<List<models.User>> getUsers() async {
    return []; // REST API implementation for listing users needs to be added to FirebaseRestService if required
  }

  /// Get records
  Future<List<models.FoodRecord>> getRecords({String? userId, int? limit}) async {
    final result = await _rest.downloadNewRecords();
    if (result['success'] == true) {
      // Data is already saved to DB by REST service
      return []; 
    }
    return [];
  }

  /// Add record
  Future<String?> addRecord(models.FoodRecord record) async {
    final result = await _rest.uploadUnsyncedRecords();
    return result['success'] == true ? 'synced' : null;
  }

  /// Update record
  Future<bool> updateRecord(String firebaseId, models.FoodRecord record) async {
    // REST API update logic
    return false;
  }

  /// Delete record
  Future<bool> deleteRecord(String firebaseId) async {
    // REST API delete logic
    return false;
  }

  /// Get objections
  Future<List<models.FoodObjection>> getObjections({String? status}) async {
    return [];
  }

  /// Add objection
  Future<String?> addObjection(models.FoodObjection objection) async {
    return null;
  }

  /// Update objection
  Future<bool> updateObjection(String firebaseId, models.FoodObjection objection) async {
    return false;
  }
}
