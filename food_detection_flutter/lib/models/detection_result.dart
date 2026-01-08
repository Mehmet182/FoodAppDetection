import 'dart:ui';

/// Tespit sonucunu temsil eden model
class DetectionResult {
  final int classId;
  final String label;
  final double confidence;
  final Rect boundingBox;
  final double price;
  final int calories;

  const DetectionResult({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.price,
    this.calories = 0,
  });

  int get confidencePercent => (confidence * 100).round();
}

/// Aynı yemekten birden fazla tespit edildiğinde toplayan model
class AggregatedDetection {
  final String name;
  final double unitPrice;
  final int unitCalories;
  int count;
  double totalPrice;
  int totalCalories;
  int avgConfidence;

  AggregatedDetection({
    required this.name,
    required this.unitPrice,
    this.unitCalories = 0,
    this.count = 0,
    this.totalPrice = 0,
    this.totalCalories = 0,
    this.avgConfidence = 0,
  });

  void addDetection(int confidencePercent) {
    avgConfidence = ((avgConfidence * count) + confidencePercent) ~/ (count + 1);
    count++;
    totalPrice = unitPrice * count;
    totalCalories = unitCalories * count;
  }

  static List<AggregatedDetection> aggregate(List<DetectionResult> detections) {
    final Map<int, AggregatedDetection> map = {};

    for (final detection in detections) {
      if (!map.containsKey(detection.classId)) {
        map[detection.classId] = AggregatedDetection(
          name: detection.label,
          unitPrice: detection.price,
          unitCalories: detection.calories,
        );
      }
      map[detection.classId]!.addDetection(detection.confidencePercent);
    }

    return map.values.toList();
  }
}
