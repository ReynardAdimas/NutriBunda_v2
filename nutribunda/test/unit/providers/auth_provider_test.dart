import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import 'package:nutribunda/core/services/http_client_service.dart';
import 'package:nutribunda/core/services/secure_storage_service.dart';
import 'package:nutribunda/core/services/biometric_service.dart';
import 'package:nutribunda/presentation/providers/auth_provider.dart';

@GenerateMocks([HttpClientService, SecureStorageService, BiometricService])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockHttpClientService mockHttpClient;
  late MockSecureStorageService mockSecureStorage;
  late MockBiometricService mockBiometricService;
  late AuthProvider authProvider;

  setUp(() {
    mockHttpClient = MockHttpClientService();
    mockSecureStorage = MockSecureStorageService();
    mockBiometricService = MockBiometricService();
    authProvider = AuthProvider(
      httpClient: mockHttpClient,
      secureStorage: mockSecureStorage,
      biometricService: mockBiometricService,
    );
  });

  group('AuthProvider - initial state', () {
    test('state awal harus tidak terautentikasi', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
    });
  });

  group('AuthProvider.login — validasi input', () {
    test('harus gagal jika email kosong', () async {
      final result = await authProvider.login('', 'password123');

      expect(result, isFalse);
      expect(authProvider.errorMessage, contains('tidak boleh kosong'));
    });

    test('harus gagal jika password kosong', () async {
      final result = await authProvider.login('bunda@test.com', '');

      expect(result, isFalse);
      expect(authProvider.errorMessage, contains('tidak boleh kosong'));
    });

    test('harus gagal jika format email tidak valid', () async {
      final result = await authProvider.login('bukan-email', 'password123');

      expect(result, isFalse);
      expect(authProvider.errorMessage, contains('Format email tidak valid'));
    });
  });

  group('AuthProvider.login — sukses', () {
    test('harus berhasil login dengan kredensial valid', () async {
      // Arrange
      final userJson = {
        'id': 'user-123',
        'email': 'bunda@test.com',
        'full_name': 'Test Bunda',
        'is_breastfeeding': false,
        'activity_level': 'sedentary',
        'timezone': 'WIB',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      when(mockHttpClient.post(any, data: anyNamed('data')))
          .thenAnswer((_) async => Response(
                data: {'token': 'jwt-token-xyz', 'user': userJson},
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      when(mockSecureStorage.saveAccessToken(any))
          .thenAnswer((_) async => {});

      // Act
      final result = await authProvider.login('bunda@test.com', 'password123');

      // Assert
      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.token, equals('jwt-token-xyz'));
      expect(authProvider.user?.email, equals('bunda@test.com'));
    });
  });

  group('AuthProvider.login — gagal dari server', () {
    test('harus menyimpan error saat server mengembalikan error', () async {
      when(mockHttpClient.post(any, data: anyNamed('data')))
          .thenThrow(Exception('Unauthorized'));

      final result = await authProvider.login('bunda@test.com', 'wrongpass');

      expect(result, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, isNotNull);
    });
  });
}