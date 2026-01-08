import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

/// Firebase Storage'a resim yükleme servisi
class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Dosyadan resim yükle
  Future<String?> uploadImage(File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final ref = _storage.ref().child('food_images/$fileName');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('✅ Resim yüklendi: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Resim yüklenemedi: $e');
      return null;
    }
  }

  /// Byte dizisinden resim yükle
  Future<String?> uploadImageBytes(Uint8List bytes, {String? fileName}) async {
    try {
      final name = fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('food_images/$name');
      
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('✅ Resim yüklendi: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Resim yüklenemedi: $e');
      return null;
    }
  }

  /// Resmi sil
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Resim silindi');
      return true;
    } catch (e) {
      print('❌ Resim silinemedi: $e');
      return false;
    }
  }
}
