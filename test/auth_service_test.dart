import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pulso/services/auth_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthResponse extends Mock implements AuthResponse {}

class MockUser extends Mock implements User {}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockGoTrue;
  late AuthService authService;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockGoTrue);
    authService = AuthService(client: mockClient);
  });

  group('AuthService.signUp', () {
    test('calls auth.signUp with correct credentials', () async {
      final response = MockAuthResponse();
      when(
        () => mockGoTrue.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => response);

      final result = await authService.signUp(
        email: 'test@example.com',
        password: 'secret123',
      );

      expect(result, response);
      verify(
        () => mockGoTrue.signUp(
          email: 'test@example.com',
          password: 'secret123',
        ),
      ).called(1);
    });
  });

  group('AuthService.signIn', () {
    test('calls auth.signInWithPassword with correct credentials', () async {
      final response = MockAuthResponse();
      when(
        () => mockGoTrue.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => response);

      final result = await authService.signIn(
        email: 'test@example.com',
        password: 'secret123',
      );

      expect(result, response);
      verify(
        () => mockGoTrue.signInWithPassword(
          email: 'test@example.com',
          password: 'secret123',
        ),
      ).called(1);
    });
  });

  group('AuthService.signOut', () {
    test('calls auth.signOut', () async {
      when(() => mockGoTrue.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockGoTrue.signOut()).called(1);
    });
  });

  group('AuthService.currentUser', () {
    test('returns null when no user is signed in', () {
      when(() => mockGoTrue.currentUser).thenReturn(null);

      expect(authService.currentUser, isNull);
    });

    test('returns user when signed in', () {
      final user = MockUser();
      when(() => mockGoTrue.currentUser).thenReturn(user);

      expect(authService.currentUser, user);
    });
  });

  group('AuthService session lifecycle', () {
    test('currentUser is set after signIn', () async {
      final user = MockUser();
      final response = MockAuthResponse();
      when(
        () => mockGoTrue.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => response);
      when(() => mockGoTrue.currentUser).thenReturn(user);

      await authService.signIn(
        email: 'test@example.com',
        password: 'secret123',
      );

      expect(authService.currentUser, isNotNull);
    });

    test('currentUser is null after signOut', () async {
      when(() => mockGoTrue.signOut()).thenAnswer((_) async {});
      when(() => mockGoTrue.currentUser).thenReturn(null);

      await authService.signOut();

      expect(authService.currentUser, isNull);
    });
  });
}
