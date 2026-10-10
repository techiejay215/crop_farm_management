import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

// Stream of auth state (logged in vs logged out)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Fetches the user's Firestore doc — used for role, name, photoUrl, etc.
final userDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(authRepositoryProvider).getUserData(user.uid);
});

// ---- Convenience: is the current user an admin? ----
final isAdminProvider = Provider<bool>((ref) {
  final userData = ref.watch(userDataProvider).value;
  return userData?['role'] == 'admin';
});