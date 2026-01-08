// Sync Service - Bidirectional Firebase <-> SQLite Sync
// Enhanced with online-first mode and connectivity monitoring

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../database/models.dart';
import 'firebase_service.dart';
import 'firebase_rest_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final FirebaseService _firebase = FirebaseService.instance;
  
  Timer? _backgroundTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  bool _isOnline = false;
  
  // Callbacks for UI updates
  Function(bool)? onConnectivityChanged;
  Function(bool)? onSyncStateChanged;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isOnlineNow => _isOnline;

  /// Check if online
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _isOnline = false;
        return false;
      }

      // Try to ping a server to confirm
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      return _isOnline;
    } catch (e) {
      _isOnline = false;
      return false;
    }
  }

  /// Initialize service with auto-sync if online
  Future<void> initialize() async {
    print('🚀 SyncService başlatılıyor...');
    
    // Check initial connectivity
    _isOnline = await isOnline();
    print('🌐 İlk bağlantı durumu: ${_isOnline ? "Çevrimiçi" : "Çevrimdışı"}');
    
    // Start listening to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (result) async {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        
        // Verify with actual internet check
        if (_isOnline) {
          _isOnline = await isOnline();
        }
        
        print('🌐 Bağlantı değişti: ${_isOnline ? "Çevrimiçi" : "Çevrimdışı"}');
        onConnectivityChanged?.call(_isOnline);
        
        // Auto-sync when coming online
        if (_isOnline && !wasOnline) {
          print('📶 İnternet bağlandı, otomatik sync başlatılıyor...');
          await fullSync();
        }
      },
    );
    
    // If online, do initial sync
    if (_isOnline) {
      print('📶 Çevrimiçi mod: Otomatik sync başlatılıyor...');
      await fullSync();
    }
    
    // Start background sync (every 2 minutes when online)
    startBackgroundSync();
  }

  /// Start background sync (every 2 minutes)
  void startBackgroundSync() {
    stopBackgroundSync();
    
    _backgroundTimer = Timer.periodic(
      const Duration(minutes: 2),
      (timer) async {
        if (!_isSyncing && await isOnline()) {
          print('⏰ Periyodik sync başlatılıyor...');
          await fullSync();
        }
      },
    );
    
    print('✅ Background sync başlatıldı (her 2 dakika)');
  }

  /// Stop background sync
  void stopBackgroundSync() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    print('🛑 Background sync durduruldu');
  }

  /// Full bidirectional sync
  Future<Map<String, dynamic>> fullSync() async {
    if (_isSyncing) return {'success': false, 'error': 'Sync already in progress'};
    
    _isSyncing = true;
    onSyncStateChanged?.call(true);
    print('🔄 Sync başlatılıyor...');

    try {
      final rest = FirebaseRestService.instance;
      
      // Check online
      if (!await isOnline()) {
        _isSyncing = false;
        onSyncStateChanged?.call(false);
        return {'success': false, 'error': 'İnternet bağlantısı yok'};
      }

      // Ensure we're authenticated
      if (!rest.isAuthenticated) {
        // Try to get saved credentials from secure storage or prompt login
        print('⚠️ Kimlik doğrulama gerekli, sync atlanıyor');
        _isSyncing = false;
        onSyncStateChanged?.call(false);
        return {'success': false, 'error': 'Kimlik doğrulama gerekli'};
      }

      // Synchronize - upload first, then download
      final uploadResult = await rest.uploadUnsyncedRecords();
      final downloadResult = await rest.downloadNewRecords();
      final objectionsResult = await rest.importObjections();
      
      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      onSyncStateChanged?.call(false);
      
      print('✅ Sync tamamlandı: ${uploadResult['uploaded']} kayıt yüklendi, ${downloadResult['downloaded']} kayıt indirildi, ${objectionsResult['count']} itiraz güncellendi');
      
      return {
        'success': uploadResult['success'] && downloadResult['success'] && (objectionsResult['success'] ?? false),
        'uploaded': uploadResult['uploaded'],
        'downloaded': downloadResult['downloaded'],
        'objections': objectionsResult['count'],
        'message': 'Sync başarılı',
      };
    } catch (e) {
      _isSyncing = false;
      onSyncStateChanged?.call(false);
      print('❌ Sync hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    final stats = await _db.getSyncStats();
    final online = await isOnline();
    
    return {
      'online': online,
      'syncing': _isSyncing,
      'last_sync': _lastSyncTime?.toIso8601String(),
      'unsynced_records': stats.unsyncedRecords,
      'unsynced_objections': stats.unsyncedObjections,
      'queue_count': stats.queueCount,
    };
  }

  void dispose() {
    stopBackgroundSync();
    _connectivitySubscription?.cancel();
  }
}
