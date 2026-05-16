import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_providers.dart';
import 'auth_repository.dart';

class AuthState {
  const AuthState({
    required this.isConfigured,
    required this.isLoading,
    this.session,
    this.errorMessage,
    this.infoMessage,
  });

  const AuthState.configMissing()
    : isConfigured = false,
      isLoading = false,
      session = null,
      errorMessage = null,
      infoMessage = null;

  const AuthState.ready({this.session})
    : isConfigured = true,
      isLoading = false,
      errorMessage = null,
      infoMessage = null;

  final bool isConfigured;
  final bool isLoading;
  final AppAuthSession? session;
  final String? errorMessage;
  final String? infoMessage;

  bool get isSignedIn => session != null;

  AuthState copyWith({
    bool? isConfigured,
    bool? isLoading,
    AppAuthSession? session,
    String? errorMessage,
    String? infoMessage,
    bool clearSession = false,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return AuthState(
      isConfigured: isConfigured ?? this.isConfigured,
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : session ?? this.session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearInfo ? null : infoMessage ?? this.infoMessage,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthRepository? _repository;
  StreamSubscription<AppAuthSession?>? _authSubscription;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    final repository = _repository;
    _authSubscription?.cancel();

    if (repository == null) {
      return const AuthState.configMissing();
    }

    _authSubscription = repository.authStateChanges.listen((session) {
      state = state.copyWith(
        session: session,
        clearSession: session == null,
        isLoading: false,
        clearError: true,
      );
    });
    ref.onDispose(() => _authSubscription?.cancel());

    return AuthState.ready(session: repository.currentSession);
  }

  Future<void> signIn({required String email, required String password}) {
    return _runAuthAction(
      email: email,
      password: password,
      action: (repository, cleanEmail, cleanPassword) =>
          repository.signIn(email: cleanEmail, password: cleanPassword),
    );
  }

  Future<void> signUp({required String email, required String password}) {
    return _runAuthAction(
      email: email,
      password: password,
      successMessage:
          'Account created. Check your email if confirmation is enabled.',
      action: (repository, cleanEmail, cleanPassword) =>
          repository.signUp(email: cleanEmail, password: cleanPassword),
    );
  }

  Future<void> signOut() async {
    final repository = _repository;
    if (repository == null) {
      state = state.copyWith(errorMessage: 'Supabase is not configured.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      await repository.signOut();
      state = state.copyWith(isLoading: false, clearSession: true);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: _message(error));
    }
  }

  Future<void> _runAuthAction({
    required String email,
    required String password,
    required Future<void> Function(AuthRepository, String, String) action,
    String? successMessage,
  }) async {
    final repository = _repository;
    if (repository == null) {
      state = state.copyWith(errorMessage: 'Supabase is not configured.');
      return;
    }

    final cleanEmail = email.trim();
    final cleanPassword = password.trim();
    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Email and password are required.',
        clearInfo: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      await action(repository, cleanEmail, cleanPassword);
      state = AuthState(
        isConfigured: true,
        isLoading: false,
        session: repository.currentSession,
        infoMessage: successMessage,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: _message(error));
    }
  }

  String _message(Object error) {
    if (error is AuthException) return error.message;
    final message = error.toString();
    final match = RegExp(r'message: ([^,)]+)').firstMatch(message);
    return match != null ? match.group(1)! : message;
  }
}
