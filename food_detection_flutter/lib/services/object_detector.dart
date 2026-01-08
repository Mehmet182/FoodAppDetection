import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// API tespit sonucu (görüntü boyutlarıyla birlikte)
class DetectionResponse {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;

  DetectionResponse({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });
}

/// API üzerinden nesne tespiti yapan servis
class ObjectDetector {
  String? _serverUrl;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  String? get serverUrl => _serverUrl;

  /// Firebase'den sunucu URL'sini al
  Future<void> initialize() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('server')
          .get();

      if (doc.exists && doc.data() != null) {
        _serverUrl = doc.data()!['url'] as String?;
        if (_serverUrl != null && _serverUrl!.isNotEmpty) {
          _isInitialized = true;
          print('✅ Sunucu URL: $_serverUrl');
        }
      }

      if (!_isInitialized) {
        print('⚠️ Firebase\'den sunucu URL alınamadı');
      }
    } catch (e) {
      print('❌ Firebase hatası: $e');
      _isInitialized = false;
    }
  }

  /// Görüntüyü sunucuya gönder ve tespit sonuçlarını al
  Future<DetectionResponse?> detectFromBytes(Uint8List imageBytes) async {
    if (!_isInitialized || _serverUrl == null) {
      print('Sunucu bağlantısı yok');
      return null;
    }

    try {
      final uri = Uri.parse('$_serverUrl/detect');
      
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'image.jpg',
      ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseResponse(data);
      } else {
        print('API Hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('İstek hatası: $e');
      return null;
    }
  }

  DetectionResponse _parseResponse(Map<String, dynamic> data) {
    final List<DetectionResult> results = [];
    
    final imageWidth = (data['image_width'] as num?)?.toInt() ?? 640;
    final imageHeight = (data['image_height'] as num?)?.toInt() ?? 480;
    
    if (data['detections'] != null) {
      for (final det in data['detections']) {
        results.add(DetectionResult(
          classId: det['class_id'] as int,
          label: det['label'] as String,
          confidence: (det['confidence'] as num).toDouble(),
          boundingBox: Rect.fromLTRB(
            (det['box']['x1'] as num).toDouble(),
            (det['box']['y1'] as num).toDouble(),
            (det['box']['x2'] as num).toDouble(),
            (det['box']['y2'] as num).toDouble(),
          ),
          price: (det['price'] as num).toDouble(),
          calories: (det['calories'] as num?)?.toInt() ?? 0,
        ));
      }
    }
    
    print('🍽️ ${results.length} tespit, görüntü: ${imageWidth}x$imageHeight');
    
    return DetectionResponse(
      detections: results,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  void dispose() {
    _serverUrl = null;
    _isInitialized = false;
  }
}
