import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/providers/auth_providers.dart';

import 'package:pulso/main.dart';
import 'package:pulso/screens/auth_screen.dart';

void main() {
  testWidgets('shows setup guidance when Supabase is not configured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.text('Connect Supabase'), findsOneWidget);
  });

  testWidgets('shows sign-in form when no user is signed in', (
    WidgetTester tester,
  ) async {
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MyApp(),
      ),
    );

    expect(find.text('Welcome to Pulso'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('calls sign in with entered credentials', (
    WidgetTester tester,
  ) async {
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MyApp(),
      ),
    );

    await tester.enterText(find.byKey(AuthKeys.emailField), 'user@example.com');
    await tester.enterText(find.byKey(AuthKeys.passwordField), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(repo.signInEmail, 'user@example.com');
    expect(repo.signInPassword, 'password123');
  });

  testWidgets('calls sign up with entered credentials', (
    WidgetTester tester,
  ) async {
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MyApp(),
      ),
    );

    await tester.enterText(find.byKey(AuthKeys.emailField), 'new@example.com');
    await tester.enterText(find.byKey(AuthKeys.passwordField), 'password123');
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(repo.signUpEmail, 'new@example.com');
    expect(repo.signUpPassword, 'password123');
  });
}

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppAuthSession?>.broadcast();
  AppAuthSession? _session;

  String? signInEmail;
  String? signInPassword;
  String? signUpEmail;
  String? signUpPassword;

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
    signUpEmail = email;
    signUpPassword = password;
    _session = AppAuthSession(userId: 'user-1', email: email);
    _controller.add(_session);
  }

  void dispose() {
    _controller.close();
  }
}
