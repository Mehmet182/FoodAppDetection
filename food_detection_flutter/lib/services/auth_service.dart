import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı modeli
class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'admin' veya 'user'
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'user',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Firebase Authentication servisi
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mevcut kullanıcı stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  /// Giriş yap
  Future<({bool success, String? error})> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: 'Bir hata oluştu: $e');
    }
  }

  /// Kayıt ol
  Future<({bool success, String? error})> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Firestore'a kullanıcı bilgilerini kaydet
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'email': email.trim(),
          'name': name.trim(),
          'role': 'user', // Varsayılan rol
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, error: _getErrorMessage(e.code));
    } catch (e) {
      return (success: false, error: 'Bir hata oluştu: $e');
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Kullanıcı bilgilerini al
  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Kullanıcı bilgisi alınamadı: $e');
      return null;
    }
  }

  /// Mevcut kullanıcının admin olup olmadığını kontrol et
  Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    
    final userData = await getUserData(user.uid);
    return userData?.isAdmin ?? false;
  }

  /// Tüm kullanıcıları getir (admin için)
  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      print('Kullanıcılar alınamadı: $e');
      return [];
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu email ile kayıtlı kullanıcı bulunamadı';
      case 'wrong-password':
        return 'Hatalı şifre';
      case 'email-already-in-use':
        return 'Bu email zaten kullanılıyor';
      case 'weak-password':
        return 'Şifre çok zayıf (en az 6 karakter)';
      case 'invalid-email':
        return 'Geçersiz email adresi';
      case 'invalid-credential':
        return 'Email veya şifre hatalı';
      default:
        return 'Bir hata oluştu: $code';
    }
  }
}
