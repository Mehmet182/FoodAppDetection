import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/food_data.dart';

/// Tespit edilen yemekleri gösteren yatay liste kartı
class DetectionCard extends StatelessWidget {
  final AggregatedDetection detection;
  final VoidCallback? onRemove;

  const DetectionCard({
    super.key,
    required this.detection,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yemek adı
              Text(
                detection.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              // Adet
              Text(
                'x${detection.count}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              
              // Confidence bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: detection.avgConfidence / 100,
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              
              // Fiyat
              Text(
                '₺${detection.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Silme butonu
          if (onRemove != null)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Yemek ekleme kartı
class AddFoodCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddFoodCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.5),
            width: 2,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Color(0xFFFF6B35),
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'Yemek Ekle',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yemek ekleme diyaloğu
class AddFoodDialog extends StatefulWidget {
  const AddFoodDialog({super.key});

  @override
  State<AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<AddFoodDialog> {
  String? _selectedFood;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Yemek Ekle',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Eklemek istediğiniz yemeği seçin:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: foodItems.length,
                itemBuilder: (context, index) {
                  final food = foodItems[index];
                  final price = foodPrices[food] ?? 0;
                  final calories = foodCalories[food] ?? 0;
                  final isSelected = food == _selectedFood;
                  
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFood = food),
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
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              formatFoodName(food),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₺${price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$calories kcal',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
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
          onPressed: _selectedFood == null
              ? null
              : () => Navigator.pop(context, _selectedFood),
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

/// Alt panel - Toplam fiyat ve tespit listesi
class BottomPanel extends StatelessWidget {
  final List<DetectionResult> detections;
  final double totalPrice;
  final VoidCallback? onSave;
  final bool isSaving;
  final Function(List<DetectionResult>)? onDetectionsChanged;

  const BottomPanel({
    super.key,
    required this.detections,
    required this.totalPrice,
    this.onSave,
    this.isSaving = false,
    this.onDetectionsChanged,
  });

  void _removeDetection(BuildContext context, String label) {
    if (onDetectionsChanged == null) return;
    
    // İlk eşleşen tespiti bul ve kaldır
    final newList = List<DetectionResult>.from(detections);
    final index = newList.indexWhere((d) => d.label == label);
    if (index != -1) {
      newList.removeAt(index);
      onDetectionsChanged!(newList);
    }
  }

  Future<void> _showAddFoodDialog(BuildContext context) async {
    if (onDetectionsChanged == null) return;
    
    final selectedFood = await showDialog<String>(
      context: context,
      builder: (context) => const AddFoodDialog(),
    );
    
    if (selectedFood != null) {
      final price = foodPrices[selectedFood] ?? 30.0;
      final calories = foodCalories[selectedFood] ?? 200;
      
      // Yeni tespit oluştur
      final newDetection = DetectionResult(
        classId: foodItems.indexOf(selectedFood),
        label: selectedFood,
        confidence: 1.0, // Manuel eklenen için %100
        boundingBox: Rect.zero, // Manuel eklemede box yok
        price: price,
        calories: calories,
      );
      
      final newList = List<DetectionResult>.from(detections)..add(newDetection);
      onDetectionsChanged!(newList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aggregated = AggregatedDetection.aggregate(detections);
    final isEditable = onDetectionsChanged != null;

    // Toplam fiyatı hesapla
    double calculatedTotal = 0;
    for (final d in detections) {
      calculatedTotal += d.price;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tespit Edilen Yemekler',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isEditable)
                Text(
                  'Düzenlemek için dokunun',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Detection list
          SizedBox(
            height: 120,
            child: aggregated.isEmpty && !isEditable
                ? Center(
                    child: Text(
                      'Yemek tespit edilmedi',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: aggregated.length + (isEditable ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Son item yemek ekleme kartı
                      if (isEditable && index == aggregated.length) {
                        return AddFoodCard(
                          onTap: () => _showAddFoodDialog(context),
                        );
                      }
                      
                      return DetectionCard(
                        detection: aggregated[index],
                        onRemove: isEditable
                            ? () => _removeDetection(context, aggregated[index].name)
                            : null,
                      );
                    },
                  ),
          ),
          
          const Divider(color: Color(0xFF2D2D2D), height: 32),
          
          // Total price ve kaydet butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Toplam Tutar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₺${calculatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Kaydet butonu
              if (onSave != null && detections.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isSaving 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
