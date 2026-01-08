import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../database/models.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  static const String _keyCurrentUser = 'current_user';
  static const String _keyLastSync = 'last_sync_time';
  static const String _keyFirebaseEnabled = 'firebase_enabled';

  /// Save current user details to SharedPreferences
  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toMap()));
  }

  /// Get current user from SharedPreferences
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_keyCurrentUser);
    if (userStr == null) return null;
    try {
      return User.fromMap(jsonDecode(userStr));
    } catch (e) {
      return null;
    }
  }

  /// Clear user session
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
  }

  /// Save last sync time
  Future<void> saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, time.toIso8601String());
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_keyLastSync);
    if (timeStr == null) return null;
    return DateTime.parse(timeStr);
  }

  /// Set Firebase sync enabled/disabled
  Future<void> setFirebaseEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirebaseEnabled, enabled);
  }

  /// Check if Firebase sync is enabled
  Future<bool> isFirebaseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirebaseEnabled) ?? true;
  }
}
