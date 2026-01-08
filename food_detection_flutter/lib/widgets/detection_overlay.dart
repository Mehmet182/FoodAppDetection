import 'package:flutter/material.dart';
import '../models/models.dart';

/// Kamera önizlemesi üzerine tespit sonuçlarını çizen widget
class DetectionOverlay extends StatelessWidget {
  final List<DetectionResult> detections;
  final Size previewSize;  // API'den gelen görüntü boyutu (örn: 480x640)
  final Size screenSize;   // Ekran boyutu

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: screenSize,
      painter: _DetectionPainter(
        detections: detections,
        previewSize: previewSize,
        screenSize: screenSize,
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size previewSize;
  final Size screenSize;

  static const List<Color> _colors = [
    Color(0xFFFF6B35), // Turuncu
    Color(0xFF4CAF50), // Yeşil
    Color(0xFF2196F3), // Mavi
    Color(0xFFE91E63), // Pembe
    Color(0xFF9C27B0), // Mor
    Color(0xFFFFEB3B), // Sarı
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Koyu turuncu
  ];

  _DetectionPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    // Aspect ratio koruyarak ölçekle
    final previewAspect = previewSize.width / previewSize.height;
    final screenAspect = screenSize.width / screenSize.height;
    
    double scaleX, scaleY, offsetX = 0, offsetY = 0;
    
    if (screenAspect > previewAspect) {
      // Ekran daha geniş - yanlarda boşluk var
      scaleY = screenSize.height / previewSize.height;
      scaleX = scaleY;
      offsetX = (screenSize.width - previewSize.width * scaleX) / 2;
    } else {
      // Ekran daha uzun - üst/alt boşluk var
      scaleX = screenSize.width / previewSize.width;
      scaleY = scaleX;
      offsetY = (screenSize.height - previewSize.height * scaleY) / 2;
    }

    for (final detection in detections) {
      final color = _colors[detection.classId % _colors.length];

      // Ölçeklenmiş ve offset'li bounding box
      final rect = Rect.fromLTRB(
        detection.boundingBox.left * scaleX + offsetX,
        detection.boundingBox.top * scaleY + offsetY,
        detection.boundingBox.right * scaleX + offsetX,
        detection.boundingBox.bottom * scaleY + offsetY,
      );

      // Box paint
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      // Draw rounded rect
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        boxPaint,
      );

      // Label
      final label = '${detection.label} ${detection.confidencePercent}%';
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Label background - üstte yer yoksa altta göster
      double labelY = rect.top - textPainter.height - 6;
      if (labelY < 0) {
        labelY = rect.bottom + 2;
      }

      final labelRect = Rect.fromLTWH(
        rect.left,
        labelY,
        textPainter.width + 10,
        textPainter.height + 6,
      );

      final labelBgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        labelBgPaint,
      );

      // Draw label text
      textPainter.paint(
        canvas,
        Offset(rect.left + 5, labelY + 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
