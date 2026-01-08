import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/services.dart';
import 'screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final _authService = AuthService();
  AppUser? _currentUser;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      if (mounted) {
        setState(() {
          _currentUser = userData;
          _isAdmin = userData?.isAdmin ?? false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Çıkış yapmak istediğinizden emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _openLiveStream() async {
    // Kamera izni kontrol
    final cameraStatus = await Permission.camera.request();
    
    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Canlı akış için kamera izni gerekli'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Kameraları al
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kamera bulunamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScreen(cameras: cameras),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kamera hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openImageSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImageSelectionScreen(),
      ),
    );
  }

  void _openAdminPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminPanelScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Üst bar - kullanıcı bilgisi ve çıkış
                _buildTopBar(),
                const SizedBox(height: 20),
                // Logo ve başlık
                _buildHeader(),
                const SizedBox(height: 40),
                // Seçim kartları
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Admin için: Canlı akış ve resim seçenekleri
                        if (_isAdmin) ...[
                          _buildOptionCard(
                            icon: Icons.videocam_rounded,
                            title: 'Canlı Akış',
                            subtitle: 'Kameradan gerçek zamanlı tespit',
                            gradient: const [Color(0xFFFF6B35), Color(0xFFf7931e)],
                            onTap: _openLiveStream,
                          ),
                          const SizedBox(height: 20),
                          _buildOptionCard(
                            icon: Icons.photo_library_rounded,
                            title: 'Resim Seç',
                            subtitle: 'Galeriden veya kameradan resim seç',
                            gradient: const [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                            onTap: _openImageSelection,
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Yemek geçmişim butonu - sadece kullanıcılar için (admin değilse)
                        if (!_isAdmin) ...[
                          _buildOptionCard(
                            icon: Icons.history,
                            title: 'Yemek Geçmişim',
                            subtitle: 'Kaydettiğin yemekleri ve kalorileri gör',
                            gradient: const [Color(0xFF2196F3), Color(0xFF03A9F4)],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MyRecordsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          // Gelecek yemekler butonu - kullanıcılar için
                          _buildOptionCard(
                            icon: Icons.calendar_today,
                            title: 'Gelecek Yemekler',
                            subtitle: 'Önümüzdeki günlerin menüsünü gör',
                            gradient: const [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UpcomingMealsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          // İtirazlarım butonu - sadece kullanıcılar için
                          _buildOptionCard(
                            icon: Icons.report_problem_outlined,
                            title: 'İtirazlarım',
                            subtitle: 'İtiraz durumunu takip et',
                            gradient: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MyObjectionsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                        // Admin paneli butonu
                        if (_isAdmin) ...[
                          const SizedBox(height: 20),
                          _buildOptionCard(
                            icon: Icons.admin_panel_settings,
                            title: 'Admin Paneli',
                            subtitle: 'Kayıtları ve itirazları yönet',
                            gradient: const [Color(0xFF9C27B0), Color(0xFFE040FB)],
                            onTap: _openAdminPanel,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Kullanıcı bilgisi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  _currentUser?.name ?? 'Yükleniyor...',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (_isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          // Çıkış butonu
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_menu,
            size: 60,
            color: Color(0xFFFF6B35),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Yemek Tespit',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Yemeklerinizi otomatik tanımlayın',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Arka plan pattern
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 100,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            // İçerik
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
