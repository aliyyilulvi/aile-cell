import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Kullanıcı adı + şifre yaklaşımı: Firebase Auth e-posta/şifre altyapısını
/// kullanır. Kullanıcı adını sahte bir e-postaya çeviririz
/// (ornek: "ahmet" -> "ahmet@chatapp.local"). Böylece telefon numarası
/// paylaşmadan basit bir kullanıcı adı sistemi elde edilir.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  String _usernameToEmail(String username) =>
      '${username.trim().toLowerCase()}@chatapp.local';

  Future<String?> register({
    required String username,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _usernameToEmail(username),
        password: password,
      );

      await _db.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'username': username.trim().toLowerCase(),
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'online': true,
      });

      notifyListeners();
      return null; // hata yok
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<String?> login({
    required String username,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _usernameToEmail(username),
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<void> logout() async {
    if (currentUser != null) {
      await _db.collection('users').doc(currentUser!.uid).update({
        'online': false,
      });
    }
    await _auth.signOut();
    notifyListeners();
  }

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu kullanıcı adı zaten alınmış.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Kullanıcı adı veya şifre hatalı.';
      default:
        return 'Bir hata oluştu: $code';
    }
  }
}
