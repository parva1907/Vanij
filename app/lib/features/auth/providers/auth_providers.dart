import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/auth_repository.dart';

/// Streams the currently signed-in user (or `null` when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Convenience: `true` when a user is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.asData?.value != null;
});

/// Controller backing the sign-in / sign-up screens.
///
/// Presentation layers do not call `FirebaseAuth.instance` directly — they
/// call methods on this controller via
/// `ref.read(authControllerProvider.notifier)`.
class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _repo = ref.read(authRepositoryProvider);

  @override
  Future<void> build() async {
    // Stateless — this controller just exposes mutation methods.
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String shopName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.signUpWithEmail(
        email: email,
        password: password,
        shopName: shopName,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.signInWithGoogle);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.signOut);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
