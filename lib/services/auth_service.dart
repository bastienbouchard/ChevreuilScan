import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Sur le web, Firebase n'est jamais initialisé (voir main.dart) — chaque
// membre protège donc son accès à FirebaseAuth.instance avec kIsWeb pour ne
// jamais planter les vérifications visuelles de cette app mobile sur web.
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static bool get isLoggedIn => !kIsWeb && _auth.currentUser != null;
  static String? get uid => kIsWeb ? null : _auth.currentUser?.uid;
  static String? get email => kIsWeb ? null : _auth.currentUser?.email;

  static Future<void> createWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _auth.currentUser?.sendEmailVerification();
  }

  static Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
    await user.delete();
  }

  static Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email);

  static Future<void> ensureUserDoc() async {
    if (kIsWeb) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static String friendlyError(Object e) {
    if (e is! FirebaseAuthException) return e.toString();
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Aucun compte avec cet email ou mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères min)';
      case 'invalid-email':
        return 'Email invalide';
      case 'too-many-requests':
        return 'Trop de tentatives — réessaie plus tard';
      case 'network-request-failed':
        return 'Pas de connexion internet';
      default:
        return e.message ?? e.code;
    }
  }
}
