import 'package:flutter/material.dart';

/// İtiraz gönderme diyaloğu
class ObjectionDialog extends StatefulWidget {
  final String recordId;
  
  const ObjectionDialog({super.key, required this.recordId});

  @override
  State<ObjectionDialog> createState() => _ObjectionDialogState();
}

class _ObjectionDialogState extends State<ObjectionDialog> {
  final _reasonController = TextEditingController();
  String? _selectedReason;
  
  final List<String> _commonReasons = [
    'Yanlış yemek tespit edildi',
    'Bu yemeği almadım',
    'Diğer',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.report_problem, color: Color(0xFFFF6B35)),
          SizedBox(width: 12),
          Text(
            'İtiraz Et',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İtiraz nedeninizi seçin:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...List.generate(_commonReasons.length, (index) {
              final reason = _commonReasons[index];
              final isSelected = _selectedReason == reason;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? const Color(0xFFFF6B35) : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            
            // Diğer seçiliyse açıklama alanı göster
            if (_selectedReason == 'Diğer') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'İtiraz nedeninizi açıklayın...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  final reason = _selectedReason == 'Diğer' 
                      ? _reasonController.text.trim()
                      : _selectedReason!;
                  if (reason.isNotEmpty) {
                    Navigator.pop(context, reason);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            disabledBackgroundColor: Colors.grey[700],
          ),
          child: const Text('Gönder', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
