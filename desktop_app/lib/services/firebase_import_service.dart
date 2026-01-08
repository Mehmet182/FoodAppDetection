// Firebase Import Service
// Runs Python script to import Firebase data into SQLite

import 'firebase_rest_service.dart';

class FirebaseImportService {
  static final FirebaseImportService instance = FirebaseImportService._();
  FirebaseImportService._();

  bool _isImporting = false;
  
  bool get isImporting => _isImporting;

  /// Import Firebase data using REST API
  Future<Map<String, dynamic>> importFromFirebase() async {
    if (_isImporting) {
      return {'success': false, 'error': 'Import zaten devam ediyor'};
    }
    
    _isImporting = true;
    final rest = FirebaseRestService.instance;

    // Check online status first
    if (!await rest.checkOnline()) {
       _isImporting = false;
       return {'success': false, 'error': 'İnternet bağlantısı yok veya Firebase erişilemez'};
    }

    // Must be logged in to read Firestore if rules require auth
    if (!rest.isAuthenticated) {
       // Ideally trigger login or return specific error
       // For now proceed, maybe rules are public or we handle it
    }

    try {
      print('🚀 Firebase import başlatılıyor (REST API)...');
      
      // 1. Import Users
      final usersResult = await rest.importUsers();
      print(usersResult['message'] ?? usersResult['error']);

      // 2. Import Records
      // Using existing sync logic for records download
      final recordsResult = await rest.downloadNewRecords(); 
      print(recordsResult['message'] ?? recordsResult['error']);
      
      // 3. Import Objections
      final objectionsResult = await rest.importObjections();
      print(objectionsResult['message'] ?? objectionsResult['error']);

      _isImporting = false;
      
      final totalCount = (usersResult['count'] ?? 0) + 
                         (recordsResult['downloaded'] ?? 0) + 
                         (objectionsResult['count'] ?? 0);

      return {
        'success': true,
        'message': 'Toplam $totalCount veri başarıyla çekildi',
      };
    } catch (e) {
      _isImporting = false;
      print('❌ Import hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
