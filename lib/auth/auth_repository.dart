import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthSession {
  const AppAuthSession({required this.userId, required this.email});

  final String userId;
  final String? email;
}

abstract class AuthRepository {
  AppAuthSession? get currentSession;

  Stream<AppAuthSession?> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AppAuthSession? get currentSession =>
      _mapSession(_client.auth.currentSession);

  @override
  Stream<AppAuthSession?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) => _mapSession(state.session));

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  AppAuthSession? _mapSession(Session? session) {
    final user = session?.user;
    if (user == null) {
      return null;
    }

    return AppAuthSession(userId: user.id, email: user.email);
  }
}
