import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/food_data.dart';

/// Yemek düzenleme diyaloğu - kaydetmeden önce yemek ekle/çıkar
class FoodEditDialog extends StatefulWidget {
  final List<DetectionResult> detections;
  final double totalPrice;
  
  const FoodEditDialog({
    super.key,
    required this.detections,
    required this.totalPrice,
  });

  @override
  State<FoodEditDialog> createState() => _FoodEditDialogState();
}

class _FoodEditDialogState extends State<FoodEditDialog> {
  late List<DetectionResult> _detections;
  late double _totalPrice;

  @override
  void initState() {
    super.initState();
    _detections = List.from(widget.detections);
    _totalPrice = widget.totalPrice;
  }

  void _recalculateTotal() {
    double total = 0;
    for (final d in _detections) {
      total += d.price;
    }
    setState(() => _totalPrice = total);
  }

  void _removeItem(int index) {
    setState(() {
      _detections.removeAt(index);
      _recalculateTotal();
    });
  }

  void _addItem() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _AddFoodItemDialog(),
    );
    
    if (result != null) {
      final price = foodPrices[result] ?? 0;
      final calories = foodCalories[result] ?? 0;
      
      final newDetection = DetectionResult(
        classId: foodItems.indexOf(result),
        label: result,
        confidence: 1.0,
        boundingBox: Rect.zero,
        price: price,
        calories: calories,
      );
      
      setState(() {
        _detections.add(newDetection);
        _recalculateTotal();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Yemekleri Düzenle',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fiyat özeti
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payments, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Toplam: ${_totalPrice.toStringAsFixed(0)}₺',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Yemek listesi
            Flexible(
              child: _detections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Yemek eklenmedi',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Kayıt için en az bir yemek ekleyin',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _detections.length,
                      itemBuilder: (context, index) {
                        final item = _detections[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatFoodName(item.label),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${item.price.toStringAsFixed(0)}₺ • ${item.calories} kcal',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeItem(index),
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 12),
            
            // Yemek ekle butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, color: Color(0xFFFF6B35)),
                label: const Text(
                  'Yemek Ekle',
                  style: TextStyle(color: Color(0xFFFF6B35)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF6B35)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
          onPressed: _detections.isEmpty
              ? null
              : () => Navigator.pop(context, {
                    'detections': _detections,
                    'totalPrice': _totalPrice,
                  }),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            disabledBackgroundColor: Colors.grey[700],
          ),
          child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

/// Yemek ekleme diyaloğu
class _AddFoodItemDialog extends StatefulWidget {
  const _AddFoodItemDialog();

  @override
  State<_AddFoodItemDialog> createState() => _AddFoodItemDialogState();
}

class _AddFoodItemDialogState extends State<_AddFoodItemDialog> {
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
      title: const Text(
        'Yemek Ekle',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: [
            // Arama
            TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Yemek ara...',
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
            const SizedBox(height: 12),
            
            // Yemek listesi
            Expanded(
              child: ListView.builder(
                itemCount: _filteredFoods.length,
                itemBuilder: (context, index) {
                  final food = _filteredFoods[index];
                  final isSelected = food == _selectedFood;
                  final price = foodPrices[food] ?? 0;
                  final calories = foodCalories[food] ?? 0;
                  
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
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatFoodName(food),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${price.toStringAsFixed(0)}₺ • $calories kcal',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
