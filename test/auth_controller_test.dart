import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/providers/auth_providers.dart';

void main() {
  test('starts unauthenticated when there is no active session', () {
    final repo = FakeAuthRepository();
    final container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    final state = container.read(authControllerProvider);

    expect(state.session, isNull);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('sign in trims credentials and updates the active session', () async {
    final repo = FakeAuthRepository();
    final container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: ' user@example.com ', password: ' password123 ');

    final state = container.read(authControllerProvider);

    expect(repo.signInEmail, 'user@example.com');
    expect(repo.signInPassword, 'password123');
    expect(state.session?.email, 'user@example.com');
    expect(state.errorMessage, isNull);
  });

  test('rejects blank sign-in fields before calling the repository', () async {
    final repo = FakeAuthRepository();
    final container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: '', password: '');

    final state = container.read(authControllerProvider);

    expect(repo.signInEmail, isNull);
    expect(state.errorMessage, 'Email and password are required.');
  });
}

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppAuthSession?>.broadcast();
  AppAuthSession? _session;

  String? signInEmail;
  String? signInPassword;

  @override
  AppAuthSession? get currentSession => _session;

  @override
  Stream<AppAuthSession?> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInEmail = email;
    signInPassword = password;
    _session = AppAuthSession(userId: 'user-1', email: email);
    _controller.add(_session);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _controller.add(null);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    _session = AppAuthSession(userId: 'user-1', email: email);
    _controller.add(_session);
  }

  void dispose() {
    _controller.close();
  }
}
