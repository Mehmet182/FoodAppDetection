import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

class ImageAnalysisScreen extends StatefulWidget {
  final String imagePath;

  const ImageAnalysisScreen({super.key, required this.imagePath});

  @override
  State<ImageAnalysisScreen> createState() => _ImageAnalysisScreenState();
}

class _ImageAnalysisScreenState extends State<ImageAnalysisScreen> {
  ObjectDetector? _detector;
  List<DetectionResult> _detections = [];
  double _totalPrice = 0;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String _statusText = 'Hazırlanıyor...';
  int _imageWidth = 640;
  int _imageHeight = 480;
  
  final _foodRecordService = FoodRecordService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _statusText = 'Sunucuya bağlanılıyor...';
    });

    _detector = ObjectDetector();
    await _detector!.initialize();

    if (_detector!.isInitialized) {
      await _analyzeImage();
    } else {
      setState(() {
        _isLoading = false;
        _statusText = 'Sunucu bağlantısı kurulamadı';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_detector == null || !_detector!.isInitialized) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Analiz ediliyor...';
    });

    try {
      final file = File(widget.imagePath);
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
          _isLoading = false;
          _isAnalyzing = false;
          _statusText = _detections.isEmpty
              ? 'Yemek tespit edilemedi'
              : '${_detections.length} yemek tespit edildi';
        });
      } else {
        setState(() {
          _isLoading = false;
          _isAnalyzing = false;
          _statusText = 'Analiz başarısız';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isAnalyzing = false;
        _statusText = 'Hata: $e';
      });
    }
  }

  @override
  void dispose() {
    _detector?.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_detections.isEmpty) return;
    
    setState(() => _isSaving = true);
    
    try {
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
      
      // Resmi yükle
      String? imageUrl;
      try {
        final file = File(widget.imagePath);
        final bytes = await file.readAsBytes();
        final imageUploadService = ImageUploadService();
        imageUrl = await imageUploadService.uploadImageBytes(bytes);
      } catch (e) {
        debugPrint('Resim yüklenemedi: $e');
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
        
        if (success) {
          Navigator.pop(context);
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analiz Sonucu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (!_isLoading && !_isAnalyzing)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _analyzeImage,
              tooltip: 'Tekrar Analiz',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(child: _buildImagePreview()),
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
          if (_isAnalyzing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_isLoading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFF6B35)),
              SizedBox(height: 16),
              Text(
                'Resim yükleniyor...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Resim
        Image.file(
          File(widget.imagePath),
          fit: BoxFit.contain,
        ),
        // Tespit kutuları overlay
        if (_detections.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              return DetectionOverlay(
                detections: _detections,
                previewSize: Size(
                  _imageWidth.toDouble(),
                  _imageHeight.toDouble(),
                ),
                screenSize: Size(constraints.maxWidth, constraints.maxHeight),
              );
            },
          ),
      ],
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
