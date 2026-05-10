import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dogquest/services/supabase_auth_service.dart';

// --- Mocks ---

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthResponse extends Mock implements AuthResponse {}

class MockUser extends Mock implements User {}

class MockSession extends Mock implements Session {}

// --- Tests ---

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late SupabaseAuthService authService;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    authService = SupabaseAuthService(mockClient);
  });

  group('SupabaseAuthService', () {
    group('signUp', () {
      test('creates user with email, password, and metadata', () async {
        final mockUser = MockUser();
        final mockResponse = MockAuthResponse();
        when(() => mockResponse.user).thenReturn(mockUser);
        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await authService.signUp(
          email: 'test@example.com',
          password: 'password123',
          username: 'testuser',
          displayName: 'Test User',
        );

        expect(result.user, equals(mockUser));
        verify(
          () => mockAuth.signUp(
            email: 'test@example.com',
            password: 'password123',
            data: {'username': 'testuser', 'display_name': 'Test User'},
          ),
        ).called(1);
      });

      test('throws SupabaseAuthException on auth error', () async {
        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenThrow(const AuthException('User already registered'));

        expect(
          () => authService.signUp(
            email: 'existing@example.com',
            password: 'password123',
            username: 'taken',
          ),
          throwsA(isA<SupabaseAuthException>()),
        );
      });

      test('maps "user already registered" to friendly message', () async {
        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenThrow(const AuthException('User already registered'));

        try {
          await authService.signUp(
            email: 'x@x.com',
            password: '123456',
            username: 'u',
          );
          fail('Should have thrown');
        } on SupabaseAuthException catch (e) {
          expect(e.message, 'An account with this email already exists');
        }
      });
    });

    group('signIn', () {
      test('returns auth response with valid session', () async {
        final mockSession = MockSession();
        final mockUser = MockUser();
        final mockResponse = MockAuthResponse();
        when(() => mockResponse.user).thenReturn(mockUser);
        when(() => mockResponse.session).thenReturn(mockSession);
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await authService.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.session, equals(mockSession));
        expect(result.user, equals(mockUser));
      });

      test('throws SupabaseAuthException on invalid credentials', () async {
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const AuthException('Invalid login credentials'));

        try {
          await authService.signIn(email: 'x@x.com', password: 'wrong');
          fail('Should have thrown');
        } on SupabaseAuthException catch (e) {
          expect(e.message, 'Invalid email or password');
        }
      });
    });

    group('signOut', () {
      test('calls auth.signOut', () async {
        when(() => mockAuth.signOut()).thenAnswer((_) async {});

        await authService.signOut();

        verify(() => mockAuth.signOut()).called(1);
      });
    });

    group('resetPassword', () {
      test('sends password reset email', () async {
        when(() => mockAuth.resetPasswordForEmail(any()))
            .thenAnswer((_) async {});

        await authService.resetPassword('test@example.com');

        verify(() => mockAuth.resetPasswordForEmail('test@example.com'))
            .called(1);
      });
    });

    group('isAuthenticated', () {
      test('returns true when session exists', () {
        final mockSession = MockSession();
        when(() => mockAuth.currentSession).thenReturn(mockSession);

        expect(authService.isAuthenticated, isTrue);
      });

      test('returns false when no session', () {
        when(() => mockAuth.currentSession).thenReturn(null);

        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('onAuthStateChange', () {
      test('exposes auth state stream', () {
        final controller = StreamController<AuthState>.broadcast();
        when(() => mockAuth.onAuthStateChange)
            .thenAnswer((_) => controller.stream);

        expect(authService.onAuthStateChange, isA<Stream<AuthState>>());
        controller.close();
      });
    });
  });
}
