import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../database/models.dart';
import '../database/database_helper.dart';
import '../main.dart';
import '../services/firebase_rest_service.dart';
import '../services/detection_service.dart';
import '../services/scheduled_meal_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    try {
      final db = DatabaseHelper.instance;
      final records = await db.getRecords();
      final objections = await db.getObjections();
      final users = await db.getUsers();

      setState(() {
        _stats = {
          'records': records.length,
          'objections': objections.where((o) => o.status == 'pending').length,
          'users': users.where((u) => u.role != 'admin').length,
        };
        _loading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu, color: Color(0xFFFF6B35)),
            const SizedBox(width: 8),
            const Text(
              'Yemek Tespit Admin',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          // Bağlantı durumu göstergesi
          _buildConnectivityIndicator(),
          const SizedBox(width: 8),
          // Kullanıcı bilgisi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(
                  widget.user.name ?? widget.user.email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // Sync butonu
          _buildSyncButton(),
          // Çıkış butonu
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Çıkış Yap',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B35),
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.add_photo_alternate), text: 'Yeni Kayıt'),
            Tab(icon: Icon(Icons.history), text: 'Kayıtlar'),
            Tab(icon: Icon(Icons.report_problem), text: 'İtirazlar'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Menü Planla'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NewRecordTab(onRecordAdded: _loadStats, currentUser: widget.user),
          _RecordsTab(stats: _stats, onRefresh: _loadStats, currentUser: widget.user),
          _ObjectionsTab(onRefresh: _loadStats),
          const _MenuPlanTab(),
        ],
      ),
    );
  }

  Widget _buildConnectivityIndicator() {
    final appState = Provider.of<AppState>(context);
    final isOnline = appState.isOnline;
    final isSyncing = appState.syncing;
    
    return Tooltip(
      message: isOnline 
          ? (isSyncing ? 'Senkronize ediliyor...' : 'Çevrimiçi - Otomatik senkronizasyon aktif')
          : 'Çevrimdışı - Yerel veriler kullanılıyor',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isOnline ? const Color(0xFF4CAF50) : Colors.orange).withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isOnline ? const Color(0xFF4CAF50) : Colors.orange).withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4CAF50),
                ),
              )
            else
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? const Color(0xFF4CAF50) : Colors.orange,
                size: 16,
              ),
            const SizedBox(width: 6),
            Text(
              isSyncing ? 'Senkronize...' : (isOnline ? 'Çevrimiçi' : 'Çevrimdışı'),
              style: TextStyle(
                color: isOnline ? const Color(0xFF4CAF50) : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    final appState = Provider.of<AppState>(context);
    
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.cloud,
        color: appState.isAuthenticated ? const Color(0xFF4CAF50) : Colors.orange,
      ),
      tooltip: 'Firebase İşlemleri',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'import',
          enabled: !appState.importing,
          child: Row(
            children: [
              Icon(
                appState.importing ? Icons.sync : Icons.cloud_download,
                color: const Color(0xFF9C27B0),
              ),
              const SizedBox(width: 12),
              Text(appState.importing ? 'İndiriliyor...' : 'Firebase\'den Veri Çek'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          enabled: !appState.syncing,
          child: Row(
            children: [
              Icon(
                appState.syncing ? Icons.sync : Icons.cloud_upload,
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(width: 12),
              Text(appState.syncing ? 'Gönderiliyor...' : 'Firebase\'e Gönder'),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'import') {
          await _handleImport();
        } else if (value == 'export') {
          await _handleExport();
        }
      },
    );
  }

  Future<void> _handleImport() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (!appState.isAuthenticated) {
      final credentials = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _SyncCredentialsDialog(),
      );
      
      if (credentials == null || !mounted) return;
      
      final loginUid = await FirebaseRestService.instance.login(
        credentials['email']!,
        credentials['password']!,
      );
      
      if (loginUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Firebase giriş başarısız'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    final result = await appState.importFromFirebase();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] ? '✅ ${result['message']}' : '❌ ${result['error']}'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
      if (result['success']) _loadStats();
    }
  }

  Future<void> _handleExport() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    final credentials = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _SyncCredentialsDialog(),
    );
    
    if (credentials != null && mounted) {
      final result = await appState.firebaseSyncNow(
        credentials['email']!,
        credentials['password']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success'] ? '✅ Senkronizasyon başarılı' : '❌ ${result['error']}'),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

// ==================== KAYITLAR TAB ====================
class _RecordsTab extends StatefulWidget {
  final Map<String, int> stats;
  final VoidCallback onRefresh;
  final User currentUser;

  const _RecordsTab({required this.stats, required this.onRefresh, required this.currentUser});

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  List<User> _users = [];
  List<FoodRecord> _records = [];
  String? _selectedUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final db = DatabaseHelper.instance;
    final users = await db.getUsers();
    final records = await db.getRecords();
    
    setState(() {
      _users = users;
      _records = records;
      _isLoading = false;
    });
  }

  List<FoodRecord> get _filteredRecords {
    if (_selectedUserId == null) return _records;
    return _records.where((r) => r.userId == _selectedUserId).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
    }

    return Column(
      children: [
        // Özet kartları
        _buildSummaryCards(),
        
        // Kullanıcı filtresi
        _buildUserFilter(),
        
        // Kayıt listesi
        Expanded(
          child: _filteredRecords.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      childAspectRatio: 0.75, // Adjust for card height
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (context, index) => _buildRecordCard(_filteredRecords[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    double totalSpending = 0;
    for (final record in _filteredRecords) {
      totalSpending += record.totalPrice;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Kullanıcılar',
              value: '${widget.stats['users'] ?? 0}',
              icon: Icons.people,
              gradient: const [Color(0xFF2196F3), Color(0xFF03A9F4)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Kayıtlar',
              value: '${_filteredRecords.length}',
              icon: Icons.restaurant,
              gradient: const [Color(0xFF4CAF50), Color(0xFF8BC34A)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Toplam Harcama',
              value: '${totalSpending.toStringAsFixed(0)}₺',
              icon: Icons.attach_money,
              gradient: const [Color(0xFFFF6B35), Color(0xFFf7931e)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Colors.white54),
          const SizedBox(width: 12),
          const Text('Kullanıcı:', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedUserId,
                isExpanded: true,
                dropdownColor: const Color(0xFF2a2a3e),
                hint: const Text('Tüm Kullanıcılar', style: TextStyle(color: Colors.white70)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tüm Kullanıcılar', style: TextStyle(color: Colors.white)),
                  ),
                  ..._users.where((u) => u.role != 'admin' && u.email != widget.currentUser.email && u.firebaseId != null).map((user) => DropdownMenuItem<String>(
                    value: user.firebaseId!,
                    child: Text(user.name ?? user.email, style: const TextStyle(color: Colors.white)),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedUserId = value),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadData,
            tooltip: 'Yenile',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Kayıt bulunamadı',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
          ),
        ],
      ),
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
      child: Padding(
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
                      child: const Icon(Icons.person, color: Color(0xFFFF6B35), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.userName ?? 'Bilinmeyen',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          _formatDate(record.createdAt),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
                    style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            
            // Image Preview (if available)
            if (record.imagePath != null || (record.imageUrl != null && record.imageUrl!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black12,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: record.imagePath != null
                      ? Image.file(
                          File(record.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
                        )
                      : Image.network(
                          record.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
                          loadingBuilder: (context, child, loadingProgress) {
                             if (loadingProgress == null) return child;
                             return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
                          },
                        ),
                ),
              ),
            ],

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
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ==================== İTİRAZLAR TAB ====================
class _ObjectionsTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const _ObjectionsTab({required this.onRefresh});

  @override
  State<_ObjectionsTab> createState() => _ObjectionsTabState();
}

class _ObjectionsTabState extends State<_ObjectionsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FoodObjection> _objections = [];
  Map<int, FoodRecord> _objectionRecords = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final db = DatabaseHelper.instance;
    final objections = await db.getObjections();
    
    final Map<int, FoodRecord> recordsMap = {};
    for (final objection in objections) {
      if (objection.recordLocalId != null) {
        // Fetch record by local ID
        // Since we don't have a direct getRecord method, we might need to add one or use raw query.
        // Or get all records and filter (inefficient but easier for now if getRecords supports filtering by IDs?)
        // DatabaseHelper seems to have getRecords()
        
        // Better: Add getRecordById to DatabaseHelper or just use raw query here if needed,
        // but checking available methods: getRecords({userId, limit}) checks by user.
        // We need by ID.
        // Let's defer to a helper method we can add, OR just inline fetch if we can.
        // Actually, let's assume we can fetch all records for now or assume we update DatabaseHelper.
        // Wait, I can't update DatabaseHelper in the same step easily.
        // I will check if I can use existing getRecords or if I need to add a method.
        // The most robust way is to fetch the record directly.
        // `db.database` is async. I can access it via specific query.
        
        // Let's try to query manually here or update DatabaseHelper first?
        // Updating DatabaseHelper is cleaner. But let's see if I can do it in one go or if I should assume getRecords is enough.
        // I will stick to adding logic here using the database instance if accessible, or update helper.
        
        // Actually, viewing DatabaseHelper again:
        // getRecords returns List.
        // I should update DatabaseHelper to support getRecordById. 
        // But for now, to save turns, I'll use a raw query if I can access the db object? 
        // `DatabaseHelper.instance.database` gives the db.
        
        // Let's do this:
        final database = await db.database;
        final List<Map<String, dynamic>> maps = await database.query(
          'food_records',
          where: 'local_id = ?',
          whereArgs: [objection.recordLocalId],
          limit: 1,
        );
        
        if (maps.isNotEmpty) {
           recordsMap[objection.localId!] = FoodRecord.fromMap(maps.first);
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _objections = objections;
        _objectionRecords = recordsMap;
        _isLoading = false;
      });
    }
  }

  List<FoodObjection> get _pendingObjections => _objections.where((o) => o.status == 'pending').toList();
  List<FoodObjection> get _resolvedObjections => _objections.where((o) => o.status != 'pending').toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
    }

    return Column(
      children: [
        // Alt tab bar
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
            tabs: [
              Tab(text: 'Aktif (${_pendingObjections.length})', icon: const Icon(Icons.hourglass_empty, size: 18)),
              Tab(text: 'Çözüldü (${_resolvedObjections.length})', icon: const Icon(Icons.done_all, size: 18)),
            ],
          ),
        ),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildObjectionList(_pendingObjections, 'Aktif itiraz yok', true),
              _buildObjectionList(_resolvedObjections, 'Çözülmüş itiraz yok', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildObjectionList(List<FoodObjection> objections, String emptyMessage, bool showActions) {
    if (objections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(emptyMessage, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 450,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: objections.length,
        itemBuilder: (context, index) => _buildObjectionCard(objections[index], showActions),
      ),
    );
  }

  Widget _buildObjectionCard(FoodObjection objection, bool showActions) {
    final statusColor = _getStatusColor(objection.status);
    final record = _objectionRecords[objection.localId];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
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
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  objection.status == 'pending' ? Icons.hourglass_empty
                      : objection.status == 'approved' ? Icons.check_circle : Icons.cancel,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      objection.userName ?? 'Bilinmeyen',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _getStatusText(objection.status),
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(objection.createdAt),
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Image Preview (if available)
          if (record != null && (record.imagePath != null || record.imageUrl != null)) ...[
            Container(
              height: 150,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: record.imagePath != null
                    ? Image.file(
                        File(record.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54),
                      )
                    : (record.imageUrl != null && record.imageUrl!.isNotEmpty)
                        ? Image.network(
                            record.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54),
                          )
                        : const SizedBox(),
              ),
            ),
          ],

          // İtiraz nedeni
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(objection.reason, style: const TextStyle(color: Colors.white70)),
          ),
          
          // Aksiyon butonları (sadece pending için)
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleObjection(objection, 'approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleObjection(objection, 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Admin yanıtı (çözülmüş için)
          if (!showActions && objection.adminResponse != null && objection.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Yanıtı:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(objection.adminResponse!, style: TextStyle(color: statusColor)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleObjection(FoodObjection objection, String newStatus) async {
    final response = await showDialog<String>(
      context: context,
      builder: (context) => _AdminResponseDialog(
        isApproved: newStatus == 'approved',
      ),
    );

    if (response == null) return;

    final db = DatabaseHelper.instance;
    await db.updateObjectionStatus(
      localId: objection.localId!,
      status: newStatus,
      adminResponse: response,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İtiraz ${newStatus == 'approved' ? 'onaylandı' : 'reddedildi'}'),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        ),
      );
      _loadData();
      widget.onRefresh();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ==================== ADMIN YANIT DİYALOĞU ====================
class _AdminResponseDialog extends StatefulWidget {
  final bool isApproved;

  const _AdminResponseDialog({required this.isApproved});

  @override
  State<_AdminResponseDialog> createState() => _AdminResponseDialogState();
}

class _AdminResponseDialogState extends State<_AdminResponseDialog> {
  final _responseController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            widget.isApproved ? Icons.check_circle : Icons.cancel,
            color: widget.isApproved ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(
            widget.isApproved ? 'İtirazı Onayla' : 'İtirazı Reddet',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _responseController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Admin yanıtı (opsiyonel)...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _responseController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isApproved ? Colors.green : Colors.red,
          ),
          child: Text(widget.isApproved ? 'Onayla' : 'Reddet'),
        ),
      ],
    );
  }
}

// ==================== SYNC DİYALOĞU ====================
class _SyncCredentialsDialog extends StatefulWidget {
  @override
  State<_SyncCredentialsDialog> createState() => _SyncCredentialsDialogState();
}

class _SyncCredentialsDialogState extends State<_SyncCredentialsDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.cloud, color: Color(0xFFFF6B35)),
          SizedBox(width: 12),
          Text('Firebase Giriş', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.email, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Şifre',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.lock, color: Colors.white54),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white54,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
          child: const Text('Bağlan'),
        ),
      ],
    );
  }
}

// ==================== YENİ KAYIT TAB ====================
class _NewRecordTab extends StatefulWidget {
  final VoidCallback onRecordAdded;
  final User currentUser;

  const _NewRecordTab({required this.onRecordAdded, required this.currentUser});

  @override
  State<_NewRecordTab> createState() => _NewRecordTabState();
}

class _NewRecordTabState extends State<_NewRecordTab> {
  final DetectionService _detectionService = DetectionService();
  
  List<User> _users = [];
  bool _isLoadingUsers = true;
  
  Uint8List? _imageBytes;
  String? _imagePath;
  List<Map<String, dynamic>> _detections = [];
  double _totalPrice = 0;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final db = DatabaseHelper.instance;
    final users = await db.getUsers();
    
    // print('👥 Yüklenen toplam kullanıcı: ${users.length}');
    // for (var u in users) {
    //   print('👤 Kullanıcı: ${u.name} (${u.email}), Rol: ${u.role}');
    // }

    if (mounted) {
      setState(() {
        // Sadece normal kullanıcıları listele (Adminleri ve şu anki kullanıcıyı gizle)
        _users = users.where((u) {
          final isCurrentUser = u.email == widget.currentUser.email;
          final isAdmin = u.role.toLowerCase().trim() == 'admin';
          return !isAdmin && !isCurrentUser;
        }).toList();
        
        // print('✅ Filtrelenen son kullanıcı sayısı: ${_users.length}');
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imagePath = file.path;
            _detections = [];
            _totalPrice = 0;
          });
          
          // Otomatik analiz başlat
          await _analyzeImage();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resim seçilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_imagePath == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final file = File(_imagePath!);
      final result = await _detectionService.detectFood(file);
      
      if (result.success && mounted) {
        setState(() {
          _detections = result.detections.map((d) => {
            'label': d.label,
            'confidence': d.confidence,
            'price': d.price,
            'calories': d.calories,
            'box': d.box,
          }).toList();
          
          _totalPrice = result.totalPrice;
        });
      } else if (result.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${result.error}'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('Detection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tespit hatası: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _removeDetection(int index) {
    setState(() {
      final removed = _detections.removeAt(index);
      _totalPrice -= (removed['price'] as num?)?.toDouble() ?? 0;
    });
  }

  Future<void> _saveRecord() async {
    if (_detections.isEmpty || _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen yemek tespit edin ve kullanıcı seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = DatabaseHelper.instance;
      
      // Seçilen kullanıcıyı bul
      final selectedUser = _users.firstWhere(
        (u) => u.localId.toString() == _selectedUserId || u.firebaseId == _selectedUserId,
        orElse: () => User(email: 'unknown', name: 'Bilinmeyen'),
      );

      // FoodItem listesi oluştur
      final items = _detections.map((d) => FoodItem(
        name: d['label'] as String? ?? 'Bilinmeyen',
        count: 1,
        price: (d['price'] as num?)?.toDouble() ?? 0,
        total: (d['price'] as num?)?.toDouble() ?? 0,
        calories: (d['calories'] as num?)?.toInt() ?? 0,
      )).toList();

      // Toplam kalori hesapla
      int totalCalories = 0;
      for (final item in items) {
        totalCalories += item.calories;
      }

      // Resmi kalıcı klasöre kopyala
      String? permanentImagePath;
      if (_imagePath != null) {
        try {
          // Use current directory for images too
          final String appDir = Directory.current.path;
          final String imagesDir = path.join(appDir, 'local_storage', 'images');
          await Directory(imagesDir).create(recursive: true);
          
          final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(_imagePath!)}';
          final String newPath = path.join(imagesDir, fileName);
          
          await File(_imagePath!).copy(newPath);
          permanentImagePath = newPath;
          print('✅ Resim kopyalandı (Yeni Konum): $permanentImagePath');
        } catch (e) {
          print('❌ Resim kopyalama hatası: $e');
          // Hata olsa bile devam et, geçici path kullan (veya null)
          permanentImagePath = _imagePath; 
        }
      }

      // 1. Önce geçici kayıt nesnesi oluştur (Upload için)
      final tempRecord = FoodRecord(
        userFirebaseId: selectedUser.firebaseId ?? selectedUser.localId.toString(),
        userName: selectedUser.name ?? selectedUser.email,
        items: items,
        totalPrice: _totalPrice,
        totalCalories: totalCalories,
        imagePath: permanentImagePath,
        synced: false,
      );

      // 2. Online ise Firebase'e gönder
      String? firebaseId;
      bool isSynced = false;
      final appState = Provider.of<AppState>(context, listen: false);
      
      if (appState.isOnline) {
        try {
          // Resmi yükle (Geliştirilebilir: Storage upload)
          // Şimdilik sadece veriyi gönderiyoruz
          firebaseId = await FirebaseRestService.instance.createRecord(tempRecord);
          if (firebaseId != null) {
            isSynced = true;
          }
        } catch (e) {
          print('Anlık yükleme başarısız: $e');
        }
      }

      // 3. Final kaydı oluştur ve yerel veritabanına kaydet
      final finalRecord = FoodRecord(
        firebaseId: firebaseId,
        userFirebaseId: tempRecord.userFirebaseId,
        userName: tempRecord.userName,
        items: tempRecord.items,
        totalPrice: tempRecord.totalPrice,
        totalCalories: tempRecord.totalCalories,
        imagePath: tempRecord.imagePath,
        synced: isSynced,
      );

      await db.addRecord(finalRecord);

      if (mounted) {
        final message = isSynced 
            ? '✅ Kayıt eklendi ve Firebase\'e gönderildi!' 
            : '✅ Kayıt eklendi (Çevrimdışı - Sıraya alındı)';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isSynced ? Colors.green : Colors.orange,
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
        
        widget.onRecordAdded();
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
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sol panel - Resim ve analiz
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yeni Yemek Kaydı Ekle',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Resim seçin, yemekleri tespit edin ve bir kullanıcıya atayın',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),
                
                // Resim seçme alanı
                _buildImageSection(),
              ],
            ),
          ),
          
          const SizedBox(width: 24),
          
          // Sağ panel - Kullanıcı seçimi ve tespitler
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 400,
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
                  child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isAnalyzing ? null : _analyzeImage,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
                        tooltip: 'Tekrar Analiz Et',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() {
                          _imageBytes = null;
                          _imagePath = null;
                          _detections = [];
                          _totalPrice = 0;
                        }),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.red),
                        tooltip: 'Kaldır',
                      ),
                    ],
                  ),
                ),
                if (_isAnalyzing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFFF6B35)),
                          SizedBox(height: 16),
                          Text('Yemekler tespit ediliyor...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_photo_alternate, color: Color(0xFFFF6B35), size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Resim Seçmek İçin Tıklayın',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'JPG, PNG formatları desteklenir',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUserSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Color(0xFFFF6B35)),
              SizedBox(width: 8),
              Text(
                'Kullanıcı Seç',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingUsers
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
              : _users.isEmpty
                  ? Text('Kullanıcı bulunamadı', style: TextStyle(color: Colors.white.withOpacity(0.5)))
                  : DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedUserId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2a2a3e),
                          hint: const Text('Kullanıcı seçin...', style: TextStyle(color: Colors.white54)),
                          items: _users.map((user) => DropdownMenuItem(
                            value: user.firebaseId ?? user.localId.toString(),
                            child: Text(user.name ?? user.email, style: const TextStyle(color: Colors.white)),
                          )).toList(),
                          onChanged: (value) => setState(() => _selectedUserId = value),
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildDetectionsPanel() {
    return Container(
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
                  const Icon(Icons.restaurant, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  Text(
                    'Tespit Edilen Yemekler (${_detections.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                  '${_totalPrice.toStringAsFixed(2)} TL',
                  style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isAnalyzing)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          else if (_detections.isEmpty)
            Text('Yemek tespit edilemedi', style: TextStyle(color: Colors.white.withOpacity(0.5)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _detections.length,
              itemBuilder: (context, index) {
                final d = _detections[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['label'] as String? ?? 'Bilinmeyen',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${((d['confidence'] as num?)?.toDouble() ?? 0) * 100}% güven',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(d['price'] as num?)?.toStringAsFixed(0) ?? '0'} TL',
                        style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _removeDetection(index),
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                        tooltip: 'Kaldır',
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save, color: Colors.white),
        label: Text(
          _isSaving ? 'Kaydediliyor...' : 'Kayıt Ekle (Offline)',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ==================== MENÜ PLANLA TAB ====================
class _MenuPlanTab extends StatefulWidget {
  const _MenuPlanTab();

  @override
  State<_MenuPlanTab> createState() => _MenuPlanTabState();
}

class _MenuPlanTabState extends State<_MenuPlanTab> {
  final ScheduledMealService _mealService = ScheduledMealService.instance;
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<MealItem> _selectedItems = [];
  bool _isSaving = false;
  bool _isLoading = true;
  List<ScheduledMeal> _scheduledMeals = [];

  // Yemek verileri (Android ile aynı)
  static const List<String> _foodItems = [
    'ana-yemek', 'cay', 'cikolata', 'corba', 'ekmek', 'gozleme',
    'haslanmis-yumurta', 'kek', 'menemen', 'meyvesuyu', 'meze',
    'patates-kizartmasi', 'patates-sosis', 'peynir', 'pogoca',
    'su-sisesi', 'yan-yemek', 'zeytin',
  ];

  static const Map<String, double> _foodPrices = {
    'ana-yemek': 55.0, 'cay': 10.0, 'cikolata': 15.0, 'corba': 35.0,
    'ekmek': 5.0, 'gozleme': 45.0, 'haslanmis-yumurta': 8.0, 'kek': 25.0,
    'menemen': 40.0, 'meyvesuyu': 20.0, 'meze': 30.0, 'patates-kizartmasi': 25.0,
    'patates-sosis': 35.0, 'peynir': 20.0, 'pogoca': 12.0, 'su-sisesi': 10.0,
    'yan-yemek': 30.0, 'zeytin': 15.0,
  };

  static const Map<String, int> _foodCalories = {
    'ana-yemek': 450, 'cay': 2, 'cikolata': 220, 'corba': 150,
    'ekmek': 80, 'gozleme': 350, 'haslanmis-yumurta': 78, 'kek': 280,
    'menemen': 200, 'meyvesuyu': 120, 'meze': 180, 'patates-kizartmasi': 320,
    'patates-sosis': 380, 'peynir': 110, 'pogoca': 180, 'su-sisesi': 0,
    'yan-yemek': 200, 'zeytin': 50,
  };

  @override
  void initState() {
    super.initState();
    _loadScheduledMeals();
  }

  Future<void> _loadScheduledMeals() async {
    setState(() => _isLoading = true);
    final meals = await _mealService.getAllScheduledMeals();
    setState(() {
      _scheduledMeals = meals;
      _isLoading = false;
    });
  }

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

  String _formatFoodName(String name) {
    return name
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}' 
            : '')
        .join(' ');
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
      builder: (context) => _FoodSelectionDialogDesktop(
        foodItems: _foodItems,
        foodPrices: _foodPrices,
        foodCalories: _foodCalories,
        formatFoodName: _formatFoodName,
      ),
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
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (!appState.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Bu özellik için internet bağlantısı gerekli'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!FirebaseRestService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Önce Firebase\'e giriş yapmalısınız'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      final success = await _mealService.scheduleMeal(
        date: _selectedDate,
        items: _selectedItems,
        createdByName: 'Admin (Desktop)',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Menü başarıyla planlandı!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
          setState(() {
            _selectedItems = [];
            _selectedDate = DateTime.now().add(const Duration(days: 1));
          });
          _loadScheduledMeals();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Menü planlanamadı'),
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
    final appState = Provider.of<AppState>(context);
    final isOnline = appState.isOnline;

    if (!isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'İnternet Bağlantısı Gerekli',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Menü planlama özelliği için internet bağlantısı gereklidir',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Sol panel - Menü oluşturma
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month, color: Color(0xFFFF6B35)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Yeni Menü Planla',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Tarih seçimi
                  const Text('Tarih Seç', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                          const Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getDayName(_selectedDate),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Yemek ekle butonu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Menü Öğeleri', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Henüz yemek eklenmedi',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                                const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _formatFoodName(item.name),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                Text(
                                  '${item.price.toStringAsFixed(0)}₺',
                                  style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  onPressed: () => _removeItem(index),
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Toplam', style: TextStyle(color: Colors.white70)),
                              Text(
                                '${_totalPrice.toStringAsFixed(0)}₺ • $_totalCalories kcal',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

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
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Kaydediliyor...' : 'Menüyü Kaydet',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Sağ panel - Planlanmış menüler
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Planlanan Menüler',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: _loadScheduledMeals,
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                      : _scheduledMeals.isEmpty
                          ? Center(
                              child: Text(
                                'Henüz planlanmış menü yok',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _scheduledMeals.length,
                              itemBuilder: (context, index) {
                                final meal = _scheduledMeals[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
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
                                                  style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
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
                                            _formatFoodName(item.name),
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Food selection dialog for desktop
class _FoodSelectionDialogDesktop extends StatefulWidget {
  final List<String> foodItems;
  final Map<String, double> foodPrices;
  final Map<String, int> foodCalories;
  final String Function(String) formatFoodName;

  const _FoodSelectionDialogDesktop({
    required this.foodItems,
    required this.foodPrices,
    required this.foodCalories,
    required this.formatFoodName,
  });

  @override
  State<_FoodSelectionDialogDesktop> createState() => _FoodSelectionDialogDesktopState();
}

class _FoodSelectionDialogDesktopState extends State<_FoodSelectionDialogDesktop> {
  String? _selectedFood;
  final _searchController = TextEditingController();
  late List<String> _filteredFoods;

  @override
  void initState() {
    super.initState();
    _filteredFoods = widget.foodItems;
    _searchController.addListener(_filterFoods);
  }

  void _filterFoods() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFoods = widget.foodItems
          .where((food) => widget.formatFoodName(food).toLowerCase().contains(query))
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
        width: 400,
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
                  final price = widget.foodPrices[food] ?? 0;
                  final calories = widget.foodCalories[food] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF6B35).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: const Color(0xFFFF6B35)) : null,
                    ),
                    child: ListTile(
                      onTap: () => setState(() => _selectedFood = food),
                      leading: const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 20),
                      title: Text(widget.formatFoodName(food), style: const TextStyle(color: Colors.white)),
                      subtitle: Text('$calories kcal', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: Text('${price.toStringAsFixed(0)}₺', style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
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
          onPressed: _selectedFood == null
              ? null
              : () => Navigator.pop(context, {
                    'name': _selectedFood,
                    'price': widget.foodPrices[_selectedFood] ?? 0,
                    'calories': widget.foodCalories[_selectedFood] ?? 0,
                  }),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), disabledBackgroundColor: Colors.grey[700]),
          child: const Text('Ekle', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
