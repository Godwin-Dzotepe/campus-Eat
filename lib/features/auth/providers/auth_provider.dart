import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../../../models/user_model.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

/// Watches Firebase Auth state and fetches the Firestore user document.
final authProvider = StreamProvider<UserModel?>((ref) async* {
  final repo = ref.read(authRepositoryProvider);
  await for (final fbUser in FirebaseAuth.instance.authStateChanges()) {
    if (fbUser == null) {
      yield null;
    } else {
      final model = await repo.currentUserModel();
      yield model;
    }
  }
});

/// Convenience notifier for login / register / logout actions.
final authActionsProvider = Provider((ref) => AuthActions(ref));

class AuthActions {
  final Ref _ref;
  AuthActions(this._ref);

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  Future<String?> login(String email, String password) =>
      _repo.login(email, password);

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? brandName,
    String? contactNumber,
  }) =>
      _repo.register(
        name: name,
        email: email,
        password: password,
        role: role,
        brandName: brandName,
        contactNumber: contactNumber,
      );

  Future<void> logout() => _repo.logout();
}
