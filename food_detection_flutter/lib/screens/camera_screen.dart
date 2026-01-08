import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  ObjectDetector? _detector;
  
  List<DetectionResult> _detections = [];
  double _totalPrice = 0;
  bool _isServerConnected = false;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _isSaving = false;
  String _statusText = 'Başlatılıyor...';
  
  // API'den gelen görüntü boyutları (bbox ölçekleme için)
  int _imageWidth = 640;
  int _imageHeight = 480;

  Timer? _detectionTimer;
  
  final _foodRecordService = FoodRecordService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeDetector();
    await _initializeCamera();
  }

  Future<void> _initializeDetector() async {
    setState(() => _statusText = 'Sunucuya bağlanılıyor...');
    
    _detector = ObjectDetector();
    await _detector!.initialize();
    
    if (mounted) {
      setState(() {
        _isServerConnected = _detector!.isInitialized;
        _statusText = _isServerConnected 
            ? 'Sunucu bağlandı' 
            : 'Sunucu bağlantısı yok';
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _statusText = 'Kamera bulunamadı');
      return;
    }

    setState(() => _statusText = 'Kamera başlatılıyor...');

    final camera = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.low,  // Hızlı upload için düşük çözünürlük
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusText = _isServerConnected ? 'Hazır' : 'Sunucu bekleniyor...';
        });

        if (_isServerConnected) {
          _startDetectionLoop();
        }
      }
    } catch (e) {
      setState(() => _statusText = 'Kamera hatası: $e');
    }
  }

  void _startDetectionLoop() {
    // Sürekli tespit döngüsü başlat
    _continuousDetection();
  }

  Future<void> _continuousDetection() async {
    while (mounted && _isServerConnected && _isCameraInitialized) {
      await _captureAndDetect();
      // Sunucu yükünü azaltmak için 2 saniye bekle
      await Future.delayed(const Duration(milliseconds: 2000));
    }
  }

  Future<void> _captureAndDetect() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _detector == null || 
        !_detector!.isInitialized) {
      return;
    }

    if (!mounted) return;

    _isDetecting = true;

    try {
      final XFile file = await _cameraController!.takePicture();
      final Uint8List bytes = await file.readAsBytes();

      final response = await _detector!.detectFromBytes(bytes);

      if (response != null && mounted) {
        double total = 0;
        for (final d in response.detections) {
          total += d.price;
        }

        setState(() {
          _detections = response.detections;
          _totalPrice = total;
          _imageWidth = response.imageWidth;
          _imageHeight = response.imageHeight;
          if (response.detections.isNotEmpty) {
            _statusText = '${response.detections.length} yemek tespit edildi';
          }
        });
      }
    } catch (e) {
      // Sessizce devam et
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _detectionTimer?.cancel();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    _detector?.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_detections.isEmpty) return;
    
    setState(() => _isSaving = true);
    
    try {
      // Önce resim çek
      Uint8List? imageBytes;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          final XFile file = await _cameraController!.takePicture();
          imageBytes = await file.readAsBytes();
        } catch (e) {
          debugPrint('Resim çekilemedi: $e');
        }
      }
      
      // Kullanıcı listesini al (adminleri hariç tut)
      final allUsers = await _authService.getAllUsers();
      final users = allUsers.where((u) => !u.isAdmin).toList();
      
      if (!mounted) return;
      
      // Kullanıcı seçim diyaloğunu göster
      final selectedUser = await showDialog<AppUser>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _UserSelectionDialog(users: users),
      );
      
      if (selectedUser == null) {
        // Kullanıcı iptal etti
        setState(() => _isSaving = false);
        return;
      }
      
      if (!mounted) return;
      
      // Yemek düzenleme diyaloğunu göster
      final editResult = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => FoodEditDialog(
          detections: _detections,
          totalPrice: _totalPrice,
        ),
      );
      
      if (editResult == null) {
        // Kullanıcı iptal etti
        setState(() => _isSaving = false);
        return;
      }
      
      final editedDetections = editResult['detections'] as List<DetectionResult>;
      final editedPrice = editResult['totalPrice'] as double;
      
      if (editedDetections.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('En az bir yemek eklemelisiniz'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
      
      // Resmi yükle (Storage varsa)
      String? imageUrl;
      if (imageBytes != null) {
        try {
          final imageUploadService = ImageUploadService();
          imageUrl = await imageUploadService.uploadImageBytes(imageBytes);
        } catch (e) {
          debugPrint('Resim yüklenemedi: $e');
        }
      }
      
      // Toplam kaloriyi hesapla
      int totalCalories = 0;
      for (final d in editedDetections) {
        totalCalories += d.calories;
      }
      
      final success = await _foodRecordService.addRecord(
        detections: editedDetections,
        totalPrice: editedPrice,
        totalCalories: totalCalories,
        userName: selectedUser.name,
        imageUrl: imageUrl,
        targetUserId: selectedUser.uid,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '${selectedUser.name} için kayıt eklendi!' 
                : 'Kayıt eklenemedi'),
            backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
          ),
        );
        
        // Tespitleri temizle
        if (success) {
          setState(() {
            _detections = [];
            _totalPrice = 0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Canlı Akış'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            Expanded(child: _buildCameraPreview()),
            BottomPanel(
              detections: _detections,
              totalPrice: _totalPrice,
              onSave: _handleSave,
              isSaving: _isSaving,
              onDetectionsChanged: (newDetections) {
                double total = 0;
                for (final d in newDetections) {
                  total += d.price;
                }
                setState(() {
                  _detections = newDetections;
                  _totalPrice = total;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black.withOpacity(0.5),
      child: Row(
        children: [
          const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusText,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isServerConnected 
                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                  : const Color(0xFFF44336).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isServerConnected 
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isServerConnected ? 'API' : 'Offline',
                  style: TextStyle(
                    color: _isServerConnected 
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFF6B35)),
              SizedBox(height: 16),
              Text('Kamera başlatılıyor...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewAreaSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            ),
            
            if (_detections.isNotEmpty)
              DetectionOverlay(
                detections: _detections,
                // API'den gelen görüntü boyutlarını kullan
                previewSize: Size(
                  _imageWidth.toDouble(),
                  _imageHeight.toDouble(),
                ),
                // Kamera önizleme alanının gerçek boyutunu kullan, tüm ekran değil
                screenSize: previewAreaSize,
              ),
          ],
        );
      },
    );
  }
}

/// Kullanıcı seçim diyaloğu
class _UserSelectionDialog extends StatefulWidget {
  final List<AppUser> users;
  
  const _UserSelectionDialog({required this.users});

  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  String? _selectedUserId;
  String _searchQuery = '';

  List<AppUser> get _filteredUsers {
    if (_searchQuery.isEmpty) return widget.users;
    return widget.users.where((u) => 
        u.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Kullanıcı Seç',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arama alanı
            TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Kullanıcı ara...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Kullanıcı listesi
            Flexible(
              child: _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        'Kullanıcı bulunamadı',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final isSelected = user.uid == _selectedUserId;
                        
                        return GestureDetector(
                          onTap: () => setState(() => _selectedUserId = user.uid),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF6B35).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFF6B35)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF2196F3),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    user.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFFF6B35),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _selectedUserId == null
              ? null
              : () {
                  final user = widget.users.firstWhere((u) => u.uid == _selectedUserId);
                  Navigator.pop(context, user);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            disabledBackgroundColor: Colors.grey[700],
          ),
          child: const Text('Seç', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
