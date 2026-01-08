import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/services.dart';
import '../services/scheduled_meal_service.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../data/food_data.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final _foodRecordService = FoodRecordService();
  final _objectionService = ObjectionService();
  final _authService = AuthService();
  final _imageUploadService = ImageUploadService();
  
  List<AppUser> _users = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final users = await _authService.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Admin Paneli',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B35),
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Kayıtlar'),
            Tab(icon: Icon(Icons.report_problem), text: 'İtirazlar'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Menü Planla'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecordsTab(),
          _buildObjectionsTab(),
          _buildMenuPlanTab(),
        ],
      ),
    );
  }

  // ==================== YENİ KAYIT TAB ====================
  Widget _buildNewRecordTab() {
    return _NewRecordWidget(
      users: _users,
      isLoadingUsers: _isLoadingUsers,
      foodRecordService: _foodRecordService,
      imageUploadService: _imageUploadService,
    );
  }

  // ==================== KAYITLAR TAB ====================
  Widget _buildRecordsTab() {
    return _RecordsListWidget(
      users: _users,
      isLoadingUsers: _isLoadingUsers,
      foodRecordService: _foodRecordService,
    );
  }

  // ==================== İTİRAZLAR TAB ====================
  Widget _buildObjectionsTab() {
    return _ObjectionsListWidget(objectionService: _objectionService);
  }

  // ==================== MENÜ PLANLA TAB ====================
  Widget _buildMenuPlanTab() {
    return _MenuPlanWidget(users: _users);
  }
}

// ==================== YENİ KAYIT WIDGET ====================
class _NewRecordWidget extends StatefulWidget {
  final List<AppUser> users;
  final bool isLoadingUsers;
  final FoodRecordService foodRecordService;
  final ImageUploadService imageUploadService;

  const _NewRecordWidget({
    required this.users,
    required this.isLoadingUsers,
    required this.foodRecordService,
    required this.imageUploadService,
  });

  @override
  State<_NewRecordWidget> createState() => _NewRecordWidgetState();
}

class _NewRecordWidgetState extends State<_NewRecordWidget> {
  final _imagePicker = ImagePicker();
  ObjectDetector? _detector;
  
  Uint8List? _imageBytes;
  String? _imagePath;
  List<DetectionResult> _detections = [];
  double _totalPrice = 0;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    _detector = ObjectDetector();
    await _detector!.initialize();
  }

  @override
  void dispose() {
    _detector?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imagePath = image.path;
          _detections = [];
          _totalPrice = 0;
        });
        
        await _analyzeImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resim alınamadı: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null || _detector == null || !_detector!.isInitialized) {
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final response = await _detector!.detectFromBytes(_imageBytes!);
      
      if (response != null && mounted) {
        double total = 0;
        for (final d in response.detections) {
          total += d.price;
        }
        
        setState(() {
          _detections = response.detections;
          _totalPrice = total;
        });
      }
    } catch (e) {
      // Hata sessizce geç
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _updateDetections(List<DetectionResult> newDetections) {
    double total = 0;
    for (final d in newDetections) {
      total += d.price;
    }
    setState(() {
      _detections = newDetections;
      _totalPrice = total;
    });
  }

  Future<void> _saveRecord() async {
    if (_detections.isEmpty || _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen yemek ve kullanıcı seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Resmi yükle (Storage yoksa null olarak devam et)
      String? imageUrl;
      if (_imageBytes != null) {
        try {
          imageUrl = await widget.imageUploadService.uploadImageBytes(_imageBytes!);
        } catch (e) {
          // Storage hatası - resim olmadan devam et
          debugPrint('Resim yüklenemedi: $e');
        }
      }

      // Seçilen kullanıcının adını bul
      final selectedUser = widget.users.firstWhere(
        (u) => u.uid == _selectedUserId,
        orElse: () => AppUser(uid: '', email: '', name: 'Bilinmeyen', role: 'user', createdAt: DateTime.now()),
      );

      // Kalori hesapla
      int totalCalories = 0;
      for (final d in _detections) {
        totalCalories += d.calories;
      }

      final success = await widget.foodRecordService.addRecord(
        detections: _detections,
        totalPrice: _totalPrice,
        totalCalories: totalCalories,
        userName: selectedUser.name,
        imageUrl: imageUrl,
        targetUserId: _selectedUserId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarıyla eklendi!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
          
          // Formu temizle
          setState(() {
            _imageBytes = null;
            _imagePath = null;
            _detections = [];
            _totalPrice = 0;
            _selectedUserId = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt eklenemedi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resim seçme kartı
          _buildImageCard(),
          const SizedBox(height: 16),
          
          // Kullanıcı seçimi
          _buildUserSelector(),
          const SizedBox(height: 16),
          
          // Tespit edilen yemekler
          if (_detections.isNotEmpty || _isAnalyzing)
            _buildDetectionsPanel(),
          
          const SizedBox(height: 16),
          
          // Kaydet butonu
          if (_detections.isNotEmpty && _selectedUserId != null)
            _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: _imageBytes != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => setState(() {
                      _imageBytes = null;
                      _imagePath = null;
                      _detections = [];
                      _totalPrice = 0;
                    }),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
                if (_isAnalyzing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                    ),
                  ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildImageButton(
                      icon: Icons.camera_alt,
                      label: 'Kamera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 24),
                    _buildImageButton(
                      icon: Icons.photo_library,
                      label: 'Galeri',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildImageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF6B35), size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kullanıcı Seç',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          widget.isLoadingUsers
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedUserId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2a2a3e),
                    hint: const Text(
                      'Kullanıcı seçin...',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: widget.users.map((user) => DropdownMenuItem(
                          value: user.uid,
                          child: Text(
                            user.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                        )).toList(),
                    onChanged: (value) => setState(() => _selectedUserId = value),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDetectionsPanel() {
    return BottomPanel(
      detections: _detections,
      totalPrice: _totalPrice,
      onDetectionsChanged: _updateDetections,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.save, color: Colors.white),
        label: Text(
          _isSaving ? 'Kaydediliyor...' : 'Kaydet',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

// ==================== KAYITLAR LİSTESİ WIDGET ====================
class _RecordsListWidget extends StatefulWidget {
  final List<AppUser> users;
  final bool isLoadingUsers;
  final FoodRecordService foodRecordService;

  const _RecordsListWidget({
    required this.users,
    required this.isLoadingUsers,
    required this.foodRecordService,
  });

  @override
  State<_RecordsListWidget> createState() => _RecordsListWidgetState();
}

class _RecordsListWidgetState extends State<_RecordsListWidget> {
  String? _selectedUserId;

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Kullanıcı filtresi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kullanıcı Filtresi',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: widget.isLoadingUsers
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedUserId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2a2a3e),
                          hint: const Text(
                            'Tüm Kullanıcılar',
                            style: TextStyle(color: Colors.white70),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'Tüm Kullanıcılar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            ...widget.users
                                .where((u) => !u.isAdmin)
                                .map((user) => DropdownMenuItem<String>(
                                  value: user.uid,
                                  child: Text(
                                    user.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedUserId = value);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Kayıtlar listesi
        Expanded(
          child: StreamBuilder<List<FoodRecord>>(
            stream: _selectedUserId != null
                ? widget.foodRecordService.getRecordsByUserId(_selectedUserId!)
                : widget.foodRecordService.getAllRecords(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                );
              }

              final records = snapshot.data ?? [];

              if (records.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kayıt bulunamadı',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Toplam hesapla
              double totalSpending = 0;
              for (final record in records) {
                totalSpending += record.totalPrice;
              }

              return Column(
                children: [
                  // Toplam özet
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Toplam Harcama',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalSpending.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Kayıt Sayısı',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${records.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Kayıt listesi
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return _buildRecordCard(record);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(FoodRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Resim
          if (record.imageUrl != null)
            GestureDetector(
              onTap: () => _showFullImage(record.imageUrl!),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  record.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık satırı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFFF6B35),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDate(record.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${record.totalPrice.toStringAsFixed(2)} ₺',
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                // Yemek listesi
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: record.items.map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item.label} - ${item.price.toStringAsFixed(0)}₺',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )).toList(),
                ),
                
                // 5 dakika düzenleme butonu
                if (widget.foodRecordService.canEditRecord(record)) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditDialog(record),
                      icon: const Icon(Icons.edit, color: Color(0xFFFF6B35), size: 18),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Düzenle',
                            style: TextStyle(color: Color(0xFFFF6B35)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${5 - DateTime.now().difference(record.createdAt).inMinutes} dk',
                              style: const TextStyle(
                                color: Color(0xFFFF6B35),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF6B35)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(FoodRecord record) async {
    // Mevcut yemekleri DetectionResult'a çevir
    final detections = record.items.map((item) => DetectionResult(
      classId: 0,
      label: item.label,
      confidence: item.confidence,
      boundingBox: Rect.zero,
      price: item.price,
      calories: item.calories,
    )).toList();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FoodEditDialog(
        detections: detections,
        totalPrice: record.totalPrice,
      ),
    );
    
    if (result == null) return;
    
    final editedDetections = result['detections'] as List<DetectionResult>;
    final editedPrice = result['totalPrice'] as double;
    
    // FoodItem'a çevir
    final items = editedDetections.map((d) => FoodItem(
      label: d.label,
      price: d.price,
      confidence: d.confidence,
      calories: d.calories,
    )).toList();
    
    int totalCalories = 0;
    for (final d in editedDetections) {
      totalCalories += d.calories;
    }
    
    final success = await widget.foodRecordService.updateRecord(
      recordId: record.id,
      items: items,
      totalPrice: editedPrice,
      totalCalories: totalCalories,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Kayıt güncellendi!' : 'Güncelleme başarısız (5 dk geçmiş olabilir)'),
          backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ==================== İTİRAZLAR LİSTESİ WIDGET ====================
class _ObjectionsListWidget extends StatefulWidget {
  final ObjectionService objectionService;

  const _ObjectionsListWidget({required this.objectionService});

  @override
  State<_ObjectionsListWidget> createState() => _ObjectionsListWidgetState();
}

class _ObjectionsListWidgetState extends State<_ObjectionsListWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _foodRecordService = FoodRecordService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(ObjectionStatus status) {
    switch (status) {
      case ObjectionStatus.approved:
        return const Color(0xFF4CAF50);
      case ObjectionStatus.rejected:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(ObjectionStatus status) {
    switch (status) {
      case ObjectionStatus.approved:
        return 'Onaylandı';
      case ObjectionStatus.rejected:
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sekme başlıkları
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF6B35),
            labelColor: const Color(0xFFFF6B35),
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Aktif', icon: Icon(Icons.hourglass_empty, size: 18)),
              Tab(text: 'Çözüldü', icon: Icon(Icons.done_all, size: 18)),
            ],
          ),
        ),
        
        // Sekme içerikleri
        Expanded(
          child: StreamBuilder<List<FoodObjection>>(
            stream: widget.objectionService.getAllObjections(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                );
              }

              final objections = snapshot.data ?? [];
              final pending = objections.where((o) => o.status == ObjectionStatus.pending).toList();
              final resolved = objections.where((o) => o.status != ObjectionStatus.pending).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildObjectionList(pending, 'Aktif itiraz yok'),
                  _buildObjectionList(resolved, 'Çözülmüş itiraz yok'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildObjectionList(List<FoodObjection> objections, String emptyMessage) {
    if (objections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: objections.length,
      itemBuilder: (context, index) {
        final objection = objections[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getStatusColor(objection.status).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(objection.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      objection.status == ObjectionStatus.pending
                          ? Icons.hourglass_empty
                          : objection.status == ObjectionStatus.approved
                              ? Icons.check_circle
                              : Icons.cancel,
                      color: _getStatusColor(objection.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          objection.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_getStatusText(objection.status)}${objection.appealCount > 1 ? " (${objection.appealCount}. itiraz)" : ""}',
                          style: TextStyle(
                            color: _getStatusColor(objection.status),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // >>>>>>>> RESİM GÖSTERİMİ (YENİ EKLENDİ) <<<<<<<<
              FutureBuilder<FoodRecord?>(
                future: _foodRecordService.getRecordById(objection.recordId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }
                  final record = snapshot.data!;
                  final hasUrl = record.imageUrl != null && record.imageUrl!.isNotEmpty;
                  final hasPath = record.imagePath != null && record.imagePath!.isNotEmpty;
                  
                  if (!hasUrl && !hasPath) {
                    return const SizedBox.shrink();
                  }
                  
                  return Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: hasPath
                          ? Image.file(
                              File(record.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            )
                          : Image.network(
                              record.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.white.withOpacity(0.05),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF6B35),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white.withOpacity(0.05),
                                  child: const Icon(Icons.broken_image, color: Colors.white24),
                                );
                              },
                            ),
                    ),
                  );
                },
              ),
              // >>>>>>>> RESİM GÖSTERİMİ SONU <<<<<<<<

              // İtiraz nedeni
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  objection.reason,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Tarih
              Text(
                _formatDate(objection.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              
              // Bekleyen itirazlar için detay butonu
              if (objection.status == ObjectionStatus.pending) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showObjectionDetailDialog(context, objection),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Detayları Görüntüle ve Değerlendir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              
              // Çözülmüş itirazlar için admin yanıtı
              if (objection.status != ObjectionStatus.pending && objection.adminResponse != null && objection.adminResponse!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(objection.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(objection.status).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Yanıtı:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        objection.adminResponse!,
                        style: TextStyle(color: _getStatusColor(objection.status)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showObjectionDetailDialog(BuildContext context, FoodObjection objection) async {
    // İlgili kaydı al
    final foodRecordService = FoodRecordService();
    final record = await foodRecordService.getRecordById(objection.recordId);
    
    if (!context.mounted) return;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ObjectionReviewDialog(
        objection: objection,
        record: record,
      ),
    );
    
    if (result == null) return;
    
    final status = result['status'] as ObjectionStatus;
    final response = result['response'] as String?;
    final items = result['items'] as List<FoodItem>?;
    final totalPrice = result['totalPrice'] as double?;
    
    // Yemek düzenlemesi yapıldıysa ve onaylandıysa kaydı güncelle
    if (status == ObjectionStatus.approved && items != null && record != null) {
      int totalCalories = 0;
      for (final item in items) {
        totalCalories += item.calories;
      }
      
      await foodRecordService.updateRecord(
        recordId: record.id,
        items: items,
        totalPrice: totalPrice ?? 0,
        totalCalories: totalCalories,
      );
    }
    
    final success = await widget.objectionService.updateObjectionStatus(
      objectionId: objection.id,
      status: status,
      adminResponse: response,
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'İtiraz ${status == ObjectionStatus.approved ? 'onaylandı' : 'reddedildi'}${items != null ? ' ve kayıt güncellendi' : ''}'
              : 'İşlem başarısız'),
          backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// İtiraz değerlendirme diyaloğu
class _ObjectionReviewDialog extends StatefulWidget {
  final FoodObjection objection;
  final FoodRecord? record;
  
  const _ObjectionReviewDialog({
    required this.objection,
    this.record,
  });

  @override
  State<_ObjectionReviewDialog> createState() => _ObjectionReviewDialogState();
}

class _ObjectionReviewDialogState extends State<_ObjectionReviewDialog> {
  final _responseController = TextEditingController();
  late List<FoodItem> _editedItems;
  late double _editedPrice;
  bool _hasEdited = false;

  @override
  void initState() {
    super.initState();
    _editedItems = widget.record?.items.toList() ?? [];
    _editedPrice = widget.record?.totalPrice ?? 0;
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  void _recalculateTotal() {
    double total = 0;
    for (final item in _editedItems) {
      total += item.price;
    }
    setState(() => _editedPrice = total);
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _editedItems.removeAt(index);
      _hasEdited = true;
      _recalculateTotal();
    });
  }

  void _addItem() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _AddFoodDialog(),
    );
    
    if (result != null) {
      final price = foodPrices[result] ?? 0;
      final calories = foodCalories[result] ?? 0;
      
      setState(() {
        _editedItems.add(FoodItem(
          label: result,
          price: price,
          confidence: 1.0,
          calories: calories,
        ));
        _hasEdited = true;
        _recalculateTotal();
      });
    }
  }

  String _getResolutionSummary() {
    if (!_hasEdited) return _responseController.text.trim();
    
    final original = widget.record?.items.map((e) => e.label).toList() ?? [];
    final edited = _editedItems.map((e) => e.label).toList();
    
    final removed = original.where((e) => !edited.contains(e)).toList();
    final added = edited.where((e) => !original.contains(e)).toList();
    
    String summary = '';
    if (removed.isNotEmpty) summary += 'Çıkarılan: ${removed.join(", ")}. ';
    if (added.isNotEmpty) summary += 'Eklenen: ${added.join(", ")}. ';
    if (_responseController.text.trim().isNotEmpty) {
      summary += _responseController.text.trim();
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  const Icon(Icons.report_problem, color: Color(0xFFFF6B35), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'İtiraz Değerlendirme',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Kullanıcı
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white54),
                    const SizedBox(width: 8),
                    Text(
                      widget.objection.userName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // İtiraz nedeni
              const Text('İtiraz Nedeni', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(widget.objection.reason, style: const TextStyle(color: Colors.orange, fontSize: 13)),
              ),
              const SizedBox(height: 12),
              
              // Kayıt görseli
              if (widget.record != null && (widget.record!.imageUrl != null || widget.record!.imagePath != null)) ...[
                const Text('Kayıt Görseli', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    if (widget.record!.imageUrl != null && widget.record!.imageUrl!.isNotEmpty) {
                      _showFullImage(widget.record!.imageUrl!);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.record!.imagePath != null && widget.record!.imagePath!.isNotEmpty
                        ? Image.file(
                            File(widget.record!.imagePath!),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          )
                        : Image.network(
                            widget.record!.imageUrl!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 80,
                              color: Colors.grey[800],
                              child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54)),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Düzenlenebilir yemek listesi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Yemekler (${_editedPrice.toStringAsFixed(0)}₺)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, color: Color(0xFF4CAF50), size: 16),
                    label: const Text('Ekle', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _editedItems.length,
                  itemBuilder: (context, index) {
                    final item = _editedItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${formatFoodName(item.label)} - ${item.price.toStringAsFixed(0)}₺',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _removeItem(index),
                            child: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_hasEdited)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 8),
                      Text('Yemekler düzenlendi', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              
              // Admin yanıtı
              const Text('Yanıtınız', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _responseController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Yanıtınızı yazın...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, {
                        'status': ObjectionStatus.rejected,
                        'response': _responseController.text.trim(),
                        'items': null,
                      }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Reddet', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                        'status': ObjectionStatus.approved,
                        'response': _getResolutionSummary(),
                        'items': _hasEdited ? _editedItems : null,
                        'totalPrice': _editedPrice,
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Onayla', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yemek ekleme diyaloğu
class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog();

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  String? _selectedFood;
  String _searchQuery = '';

  List<String> get _filteredFoods {
    if (_searchQuery.isEmpty) return foodItems;
    return foodItems.where((f) => 
        formatFoodName(f).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Yemek Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Yemek ara...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredFoods.length,
                itemBuilder: (context, index) {
                  final food = _filteredFoods[index];
                  final isSelected = food == _selectedFood;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFood = food),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent),
                      ),
                      child: Text(
                        '${formatFoodName(food)} - ${(foodPrices[food] ?? 0).toStringAsFixed(0)}₺',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _selectedFood == null ? null : () => Navigator.pop(context, _selectedFood),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), disabledBackgroundColor: Colors.grey[700]),
          child: const Text('Ekle', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ==================== MENÜ PLANLA WIDGET ====================
class _MenuPlanWidget extends StatefulWidget {
  final List<AppUser> users;

  const _MenuPlanWidget({required this.users});

  @override
  State<_MenuPlanWidget> createState() => _MenuPlanWidgetState();
}

class _MenuPlanWidgetState extends State<_MenuPlanWidget> {
  final ScheduledMealService _mealService = ScheduledMealService();
  final AuthService _authService = AuthService();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<MealItem> _selectedItems = [];
  bool _isSaving = false;

  double get _totalPrice {
    double total = 0;
    for (var item in _selectedItems) {
      total += item.price * item.count;
    }
    return total;
  }

  int get _totalCalories {
    int total = 0;
    for (var item in _selectedItems) {
      total += item.calories * item.count;
    }
    return total;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF6B35),
              surface: Color(0xFF1a1a2e),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addFoodItem() {
    showDialog(
      context: context,
      builder: (context) => _FoodSelectionDialog(),
    ).then((selectedFood) {
      if (selectedFood != null && selectedFood is Map<String, dynamic>) {
        setState(() {
          _selectedItems.add(MealItem(
            name: selectedFood['name'],
            price: selectedFood['price'],
            calories: selectedFood['calories'],
            count: 1,
          ));
        });
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  Future<void> _saveMeal() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir yemek ekleyin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = _authService.currentUser;
      final userData = currentUser != null 
          ? await _authService.getUserData(currentUser.uid) 
          : null;
      
      final success = await _mealService.scheduleMeal(
        date: _selectedDate,
        items: _selectedItems,
        createdByName: userData?.name ?? 'Admin',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menü başarıyla planlandı!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
          setState(() {
            _selectedItems = [];
            _selectedDate = DateTime.now().add(const Duration(days: 1));
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menü planlanamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bilgi kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withOpacity(0.2),
                  const Color(0xFFFF6B35).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.info_outline, color: Color(0xFFFF6B35)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menü Planlama',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'İlerideki günler için menü planlayın. Kullanıcılar bu menüleri görebilir.',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tarih seçimi
          const Text(
            'Tarih Seç',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDayName(_selectedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Yemek ekleme
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Menü Öğeleri',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _addFoodItem,
                icon: const Icon(Icons.add, color: Color(0xFFFF6B35), size: 18),
                label: const Text('Yemek Ekle', style: TextStyle(color: Color(0xFFFF6B35))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Eklenen yemekler
          if (_selectedItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.restaurant_menu, size: 48, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz yemek eklenmedi',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ..._selectedItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatFoodName(item.name),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${item.calories} kcal',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.price.toStringAsFixed(0)}₺',
                          style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeItem(index),
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // Toplam
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Toplam',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_totalPrice.toStringAsFixed(0)}₺',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_totalCalories kcal',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Kaydet butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving || _selectedItems.isEmpty ? null : _saveMeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                disabledBackgroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Kaydediliyor...' : 'Menüyü Kaydet',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Planlanan menüler
          const Text(
            'Planlanan Menüler',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ScheduledMeal>>(
            stream: _mealService.getAllScheduledMeals(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  ),
                );
              }

              final meals = snapshot.data ?? [];
              
              if (meals.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Henüz planlanmış menü yok',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                );
              }

              return Column(
                children: meals.map((meal) => _buildScheduledMealCard(meal)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledMealCard(ScheduledMeal meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${meal.scheduledDate.day}',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDayName(meal.scheduledDate),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(meal.scheduledDate),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${meal.totalPrice.toStringAsFixed(0)}₺',
                  style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: meal.items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatFoodName(item.name),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Bugün';
    if (dateOnly == tomorrow) return 'Yarın';

    const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return days[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Food selection dialog for menu planning
class _FoodSelectionDialog extends StatefulWidget {
  @override
  State<_FoodSelectionDialog> createState() => _FoodSelectionDialogState();
}

class _FoodSelectionDialogState extends State<_FoodSelectionDialog> {
  String? _selectedFood;
  final _searchController = TextEditingController();
  List<String> _filteredFoods = foodItems;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterFoods);
  }

  void _filterFoods() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFoods = foodItems
          .where((food) => formatFoodName(food).toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Yemek Seç', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ara...',
                hintStyle: const TextStyle(color: Colors.white54),
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
            Expanded(
              child: ListView.builder(
                itemCount: _filteredFoods.length,
                itemBuilder: (context, index) {
                  final food = _filteredFoods[index];
                  final isSelected = _selectedFood == food;
                  final price = foodPrices[food] ?? 0;
                  final calories = foodCalories[food] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF6B35).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: const Color(0xFFFF6B35))
                          : null,
                    ),
                    child: ListTile(
                      onTap: () => setState(() => _selectedFood = food),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 20),
                      ),
                      title: Text(
                        formatFoodName(food),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '$calories kcal',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Text(
                        '${price.toStringAsFixed(0)}₺',
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                        ),
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
          onPressed: _selectedFood == null
              ? null
              : () => Navigator.pop(context, {
                    'name': _selectedFood,
                    'price': foodPrices[_selectedFood] ?? 0,
                    'calories': foodCalories[_selectedFood] ?? 0,
                  }),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            disabledBackgroundColor: Colors.grey[700],
          ),
          child: const Text('Ekle', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

