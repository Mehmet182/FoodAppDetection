import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/services.dart';

/// Kullanıcının kendi itirazlarını ve durumlarını gösteren ekran
class MyObjectionsScreen extends StatefulWidget {
  const MyObjectionsScreen({super.key});

  @override
  State<MyObjectionsScreen> createState() => _MyObjectionsScreenState();
}

class _MyObjectionsScreenState extends State<MyObjectionsScreen> with SingleTickerProviderStateMixin {
  final _objectionService = ObjectionService();
  final _foodRecordService = FoodRecordService();
  late TabController _tabController;

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

  IconData _getStatusIcon(ObjectionStatus status) {
    switch (status) {
      case ObjectionStatus.approved:
        return Icons.check_circle;
      case ObjectionStatus.rejected:
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  void _showReAppealDialog(FoodObjection objection) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tekrar İtiraz Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lütfen itiraz nedeninizi tekrar açıklayın:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'İtiraz nedeniniz...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Not: Bu son itiraz hakkınız.',
              style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context);
              
              final success = await _objectionService.reAppeal(
                objectionId: objection.id,
                newReason: reasonController.text.trim(),
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'İtiraz tekrar gönderildi!' : 'İtiraz gönderilemedi'),
                    backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
            child: const Text('Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'İtirazlarım',
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
            Tab(text: 'Bekleyen', icon: Icon(Icons.hourglass_empty, size: 20)),
            Tab(text: 'Tamamlanmış', icon: Icon(Icons.done_all, size: 20)),
          ],
        ),
      ),
      body: StreamBuilder<List<FoodObjection>>(
        stream: _objectionService.getUserObjections(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Hata: ${snapshot.error}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final objections = snapshot.data ?? [];
          final pending = objections.where((o) => o.status == ObjectionStatus.pending).toList();
          final completed = objections.where((o) => o.status != ObjectionStatus.pending).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // Bekleyen tab
              _buildObjectionList(pending, 'Bekleyen itiraz yok'),
              // Tamamlanmış tab
              _buildObjectionList(completed, 'Tamamlanmış itiraz yok'),
            ],
          );
        },
      ),
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
      padding: const EdgeInsets.all(16),
      itemCount: objections.length,
      itemBuilder: (context, index) {
        final objection = objections[index];
        return _buildObjectionCard(objection);
      },
    );
  }

  Widget _buildObjectionCard(FoodObjection objection) {
    final statusColor = _getStatusColor(objection.status);
    final statusText = _getStatusText(objection.status);
    final statusIcon = _getStatusIcon(objection.status);

    return FutureBuilder<FoodRecord?>(
      future: _foodRecordService.getRecordById(objection.recordId),
      builder: (context, recordSnapshot) {
        final record = recordSnapshot.data;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Durum başlığı
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(objection.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // İlgili kayıt bilgisi
              if (record != null) ...[
                // Kayıt görseli (varsa)
                if (record.imageUrl != null)
                  ClipRRect(
                    child: Image.network(
                      record.imageUrl!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 60,
                        color: Colors.grey[800],
                        child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54)),
                      ),
                    ),
                  ),
                
                // Kayıtlı yemekler
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.restaurant, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'İtiraz Edilen Kayıt (${record.totalPrice.toStringAsFixed(0)}₺)',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: record.items.map((item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.label,
                            style: const TextStyle(color: Color(0xFF2196F3), fontSize: 11),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],
              
              // İçerik
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İtiraz nedeni
                    const Text(
                      'İtiraz Nedeni',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        objection.reason,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                    
                    // Admin yanıtı (varsa)
                    if (objection.adminResponse != null && objection.adminResponse!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Admin Yanıtı',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          objection.adminResponse!,
                          style: TextStyle(color: statusColor),
                        ),
                      ),
                    ],
                    
                    // Tekrar itiraz butonu (reddedilmiş ve 2'den az itiraz)
                    if (objection.canReAppeal) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showReAppealDialog(objection),
                          icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFFF6B35)),
                          label: Text(
                            'Tekrar İtiraz Et (${2 - objection.appealCount} hak kaldı)',
                            style: const TextStyle(color: Color(0xFFFF6B35)),
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
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
