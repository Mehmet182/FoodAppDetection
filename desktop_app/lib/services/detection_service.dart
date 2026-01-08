// Detection Service - Python Bridge
// Communicates with FastAPI detection service

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class DetectionResult {
  final int classId;
  final String label;
  final double confidence;
  final double price;
  final int calories;
  final Map<String, double> box;

  DetectionResult({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.price,
    required this.calories,
    required this.box,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      classId: json['class_id'] as int,
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      calories: json['calories'] as int,
      box: {
        'x1': (json['box']['x1'] as num).toDouble(),
        'y1': (json['box']['y1'] as num).toDouble(),
        'x2': (json['box']['x2'] as num).toDouble(),
        'y2': (json['box']['y2'] as num).toDouble(),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'label': label,
      'confidence': confidence,
      'price': price,
      'calories': calories,
      'box': box,
    };
  }
}

class DetectionResponse {
  final bool success;
  final int count;
  final int imageWidth;
  final int imageHeight;
  final List<DetectionResult> detections;
  final String? error;

  DetectionResponse({
    required this.success,
    required this.count,
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    this.error,
  });

  factory DetectionResponse.fromJson(Map<String, dynamic> json) {
    List<DetectionResult> results = [];
    if (json['detections'] != null) {
      results = (json['detections'] as List)
          .map((e) => DetectionResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return DetectionResponse(
      success: json['success'] ?? false,
      count: json['count'] ?? 0,
      imageWidth: json['image_width'] ?? 0,
      imageHeight: json['image_height'] ?? 0,
      detections: results,
      error: json['error'] as String?,
    );
  }

  // Aggregate detections by label
  Map<String, DetectionAggregation> get aggregatedResults {
    final Map<String, DetectionAggregation> aggregated = {};
    
    for (var detection in detections) {
      if (!aggregated.containsKey(detection.label)) {
        aggregated[detection.label] = DetectionAggregation(
          label: detection.label,
          count: 0,
          unitPrice: detection.price,
          unitCalories: detection.calories,
        );
      }
      aggregated[detection.label]!.count++;
    }
    
    return aggregated;
  }

  double get totalPrice {
    return aggregatedResults.values
        .fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int get totalCalories {
    return aggregatedResults.values
        .fold(0, (sum, item) => sum + item.totalCalories);
  }
}

class DetectionAggregation {
  final String label;
  int count;
  final double unitPrice;
  final int unitCalories;

  DetectionAggregation({
    required this.label,
    required this.count,
    required this.unitPrice,
    required this.unitCalories,
  });

  double get totalPrice => unitPrice * count;
  int get totalCalories => unitCalories * count;

  Map<String, dynamic> toJson() {
    return {
      'name': label,
      'count': count,
      'price': unitPrice,
      'total': totalPrice,
      'calories': totalCalories,
    };
  }
}

class DetectionService {
  static const String baseUrl = 'http://localhost:8000';
  static const Duration timeout = Duration(seconds: 30);

  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Start the Python detection service (hidden, no terminal)
  Future<bool> startDetectionService() async {
    if (_isRunning) {
      print('⚠️ Detection service zaten çalışıyor');
      return false;
    }

    try {
      String serviceDir;
      // Uygulamanın olduğu dizini bul
      final executableDir = path.dirname(Platform.resolvedExecutable);
      
      // Development mode?
      // Eğer projenin içindeysek (örn: desktop_app), bir üst dizindeki detection_service'i bul
      final currentDir = Directory.current.path;
      if (currentDir.contains('desktop_app') && !executableDir.contains('Release')) {
        serviceDir = path.join(currentDir, '..', 'detection_service');
      } else {
        // Release mode: Executable'ın yanındaki detection_service klasörü
        serviceDir = path.join(executableDir, 'detection_service');
      }

      final exePath = path.join(serviceDir, 'detection_service.exe');
      final scriptPath = path.join(serviceDir, 'main.py');
      
      print('📂 Detection service dizini: $serviceDir');

      // 1. Önce EXE kontrolü
      if (await File(exePath).exists()) {
        print('🚀 Detection Service (EXE) başlatılıyor...');
        _process = await Process.start(
          exePath,
          [],
          workingDirectory: serviceDir,
          mode: ProcessStartMode.detached,
        );
      } 
      // 2. Script kontrolü
      else if (await File(scriptPath).exists()) {
        print('🚀 Detection Service (Python Script) başlatılıyor...');
        if (Platform.isWindows) {
          _process = await Process.start(
            'pythonw',
            ['main.py'],
            workingDirectory: serviceDir,
            mode: ProcessStartMode.detached,
          );
        } else {
          _process = await Process.start(
            'python3',
            ['main.py'],
            workingDirectory: serviceDir,
            mode: ProcessStartMode.detached,
          );
        }
      } else {
        print('❌ Detection service bulunamadı! (Ne exe ne main.py var)');
        print('Aranan yollar:\n$exePath\n$scriptPath');
        return false;
      }

      _isRunning = true;
      print('✅ Service başlatıldı (PID: ${_process!.pid})');

      // Wait for service to start
      await Future.delayed(const Duration(seconds: 4));

      // Check if service is healthy
      final isHealthy = await checkHealth();
      if (!isHealthy) {
        print('⚠️ Detection service başladı ama health check yanıt vermedi. Bekleniyor...');
      } else {
        print('✅ Detection service hazır! (http://localhost:8000)\n');
      }

      return _isRunning;
    } catch (e) {
      print('❌ Servis başlatma hatası: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Stop the detection service
  Future<void> stopDetectionService() async {
    if (!_isRunning && _process == null) {
      return;
    }

    try {
      print('🛑 Detection service kapatılıyor...');

      if (Platform.isWindows) {
        if (_process != null) {
          Process.run('taskkill', ['/F', '/PID', '${_process!.pid}', '/T']);
        }
        // Genel temizlik
        Process.run('taskkill', ['/F', '/IM', 'detection_service.exe']);
        Process.run('taskkill', ['/F', '/IM', 'pythonw.exe', '/FI', 'WINDOWTITLE eq *']);
      } else {
        _process?.kill();
      }

      _isRunning = false;
      _process = null;
      print('✅ Detection service kapatıldı\n');
    } catch (e) {
      print('❌ Hata: $e');
      _isRunning = false;
    }
  }

  /// Check if service is healthy
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy' && data['model_loaded'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Detect food items in image
  Future<DetectionResponse> detectFood(File imageFile) async {
    try {
      // Check if service is running
      if (!await checkHealth()) {
        return DetectionResponse(
          success: false,
          count: 0,
          imageWidth: 0,
          imageHeight: 0,
          detections: [],
          error: 'Detection service çalışmıyor',
        );
      }

      // Prepare multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect'),
      );

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Send request
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DetectionResponse.fromJson(data);
      } else {
        return DetectionResponse(
          success: false,
          count: 0,
          imageWidth: 0,
          imageHeight: 0,
          detections: [],
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return DetectionResponse(
        success: false,
        count: 0,
        imageWidth: 0,
        imageHeight: 0,
        detections: [],
        error: 'Hata: $e',
      );
    }
  }

  void dispose() {
    stopDetectionService();
  }
}
