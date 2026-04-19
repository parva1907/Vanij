import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/providers/firebase_providers.dart';

/// Repository responsible for all Firebase Auth interactions.
///
/// Kept as a thin wrapper so presentation layers never import the Firebase
/// SDK directly.
class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String shopName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'Sign up returned no user.',
      );
    }
    await _ensureMerchantDoc(uid: uid, shopName: shopName);
  }

  Future<void> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google sign-in did not return an ID token.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCred = await _auth.signInWithCredential(credential);
    final uid = userCred.user?.uid;
    if (uid != null) {
      await _ensureMerchantDoc(
        uid: uid,
        shopName: userCred.user?.displayName ?? 'My Shop',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore — user may never have used Google sign-in on this device.
    }
    await _auth.signOut();
  }

  /// Creates `merchants/{uid}` on first sign-up. Idempotent.
  Future<void> _ensureMerchantDoc({
    required String uid,
    required String shopName,
  }) async {
    final ref = _firestore.collection('merchants').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'ownerUid': uid,
      'shopName': shopName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});
