import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'services/sync_service.dart';
import 'services/detection_service.dart';
import 'services/firebase_import_service.dart';
import 'services/firebase_rest_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Window manager'ı başlat
  await windowManager.ensureInitialized();
  
  // Pencere ayarları
  const windowOptions = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(1200, 700),
    center: true,
    backgroundColor: Color(0xFF0f172a),
    title: '🍽️ Yemek Tespit Admin Paneli',
    titleBarStyle: TitleBarStyle.normal,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  print('🚀 Uygulama başlatıldı: Online-First (İnternet varken senkronize)');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        title: 'Yemek Tespit Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3b82f6),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Segoe UI',
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr', 'TR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('tr', 'TR'),
        home: const LoginScreen(),
      ),
    );
  }
}

class AppState with ChangeNotifier {
  final DetectionService _detectionService = DetectionService();
  final SyncService _syncService = SyncService.instance;
  final FirebaseImportService _importService = FirebaseImportService.instance;
  
  bool _detectionServiceRunning = false;
  bool _syncing = false;
  bool _importing = false;
  bool _initialized = false;
  bool _isOnline = false;

  bool get detectionServiceRunning => _detectionServiceRunning;
  bool get syncing => _syncing;
  bool get importing => _importing;
  bool get initialized => _initialized;
  bool get isOnline => _isOnline;
  bool get isAuthenticated => FirebaseRestService.instance.isAuthenticated;
  DetectionService get detectionService => _detectionService;
  SyncService get syncService => _syncService;
  DateTime? get lastSyncTime => _syncService.lastSyncTime;

  /// Initialize app - auto-start detection service and sync
  Future<void> initialize() async {
    if (_initialized) return;
    
    print('🚀 Uygulama başlatılıyor...');
    
    // Auto-start detection service
    await startDetectionService();
    
    // Setup sync service callbacks
    _syncService.onConnectivityChanged = (online) {
      _isOnline = online;
      notifyListeners();
      
      // Update window title based on connectivity
      _updateWindowTitle();
    };
    
    _syncService.onSyncStateChanged = (syncing) {
      _syncing = syncing;
      notifyListeners();
    };
    
    // Initialize sync service (will auto-sync if online)
    await _syncService.initialize();
    _isOnline = _syncService.isOnlineNow;
    
    _initialized = true;
    _updateWindowTitle();
    notifyListeners();
  }

  void _updateWindowTitle() {
    final status = _isOnline ? 'Çevrimiçi' : 'Çevrimdışı';
    windowManager.setTitle('🍽️ Yemek Tespit Admin Paneli ($status)');
  }

  Future<void> startDetectionService() async {
    if (_detectionServiceRunning) {
      print('⚠️ Detection service zaten çalışıyor');
      return;
    }
    
    _detectionServiceRunning = await _detectionService.startDetectionService();
    notifyListeners();
  }

  Future<void> stopDetectionService() async {
    await _detectionService.stopDetectionService();
    _detectionServiceRunning = false;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    
    _syncing = true;
    notifyListeners();
    
    await _syncService.fullSync();
    
    _syncing = false;
    notifyListeners();
  }

  /// Sync with Firebase using REST API
  Future<Map<String, dynamic>> firebaseSyncNow(String email, String password) async {
    if (_syncing) {
      return {
        'success': false,
        'error': 'Sync zaten devam ediyor',
      };
    }
    
    _syncing = true;
    notifyListeners();
    
    final result = await FirebaseRestService.instance.fullSync(email, password);
    
    _syncing = false;
    notifyListeners();
    
    return result;
  }

  /// Import data from Firebase
  Future<Map<String, dynamic>> importFromFirebase() async {
    if (_importing) {
      return {
        'success': false,
        'error': 'Import zaten devam ediyor',
      };
    }
    
    _importing = true;
    notifyListeners();
    
    final result = await _importService.importFromFirebase();
    
    _importing = false;
    notifyListeners();
    
    return result;
  }

  void startBackgroundSync() {
    _syncService.startBackgroundSync();
  }

  void stopBackgroundSync() {
    _syncService.stopBackgroundSync();
  }

  @override
  void dispose() {
    _detectionService.dispose();
    _syncService.dispose();
    super.dispose();
  }
}
