// import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/mockito.dart';
// import 'package:mockito/annotations.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:nutribunda/core/services/biometric_service.dart';
// import 'package:nutribunda/core/services/secure_storage_service.dart';

// import 'biometric_service_test.mocks.dart';

// @GenerateMocks([LocalAuthentication, SecureStorageService])
// void main() {
//   late BiometricService biometricService;
//   late MockLocalAuthentication mockLocalAuth;
//   late MockSecureStorageService mockSecureStorage;

//   setUp(() {
//     mockLocalAuth = MockLocalAuthentication();
//     mockSecureStorage = MockSecureStorageService();
//     biometricService = BiometricService(
//       localAuth: mockLocalAuth,
//       secureStorage: mockSecureStorage,
//     );
//   });

//   group('BiometricService - Device Support', () {
//     test('isDeviceSupported returns true when biometrics are supported', () async {
//       // Arrange
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
//       when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

//       // Act
//       final result = await biometricService.isDeviceSupported();

//       // Assert
//       expect(result, true);
//       verify(mockLocalAuth.canCheckBiometrics).called(1);
//     });

//     test('isDeviceSupported returns false when biometrics are not supported', () async {
//       // Arrange
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
//       when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

//       // Act
//       final result = await biometricService.isDeviceSupported();

//       // Assert
//       expect(result, false);
//     });

//     test('isBiometricAvailable returns true when biometrics are available', () async {
//       // Arrange
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);

//       // Act
//       final result = await biometricService.isBiometricAvailable();

//       // Assert
//       expect(result, true);
//       verify(mockLocalAuth.canCheckBiometrics).called(1);
//     });

//     test('getAvailableBiometrics returns list of biometric types', () async {
//       // Arrange
//       final expectedBiometrics = [BiometricType.fingerprint, BiometricType.face];
//       when(mockLocalAuth.getAvailableBiometrics()).thenAnswer((_) async => expectedBiometrics);

//       // Act
//       final result = await biometricService.getAvailableBiometrics();

//       // Assert
//       expect(result, expectedBiometrics);
//       verify(mockLocalAuth.getAvailableBiometrics()).called(1);
//     });
//   });

//   group('BiometricService - Enable/Disable', () {
//     test('isBiometricEnabled returns true when enabled', () async {
//       // Arrange
//       when(mockSecureStorage.read('biometric_enabled')).thenAnswer((_) async => 'true');

//       // Act
//       final result = await biometricService.isBiometricEnabled();

//       // Assert
//       expect(result, true);
//       verify(mockSecureStorage.read('biometric_enabled')).called(1);
//     });

//     test('isBiometricEnabled returns false when disabled', () async {
//       // Arrange
//       when(mockSecureStorage.read('biometric_enabled')).thenAnswer((_) async => 'false');

//       // Act
//       final result = await biometricService.isBiometricEnabled();

//       // Assert
//       expect(result, false);
//     });

//     test('enableBiometric sets enabled to true and resets failed attempts', () async {
//       // Arrange
//       when(mockSecureStorage.write('biometric_enabled', 'true')).thenAnswer((_) async => {});
//       when(mockSecureStorage.delete('biometric_failed_attempts')).thenAnswer((_) async => {});
//       when(mockSecureStorage.delete('biometric_last_failed_time')).thenAnswer((_) async => {});

//       // Act
//       await biometricService.enableBiometric();

//       // Assert
//       verify(mockSecureStorage.write('biometric_enabled', 'true')).called(1);
//       verify(mockSecureStorage.delete('biometric_failed_attempts')).called(1);
//       verify(mockSecureStorage.delete('biometric_last_failed_time')).called(1);
//     });

//     test('disableBiometric sets enabled to false and resets failed attempts', () async {
//       // Arrange
//       when(mockSecureStorage.write('biometric_enabled', 'false')).thenAnswer((_) async => {});
//       when(mockSecureStorage.delete('biometric_failed_attempts')).thenAnswer((_) async => {});
//       when(mockSecureStorage.delete('biometric_last_failed_time')).thenAnswer((_) async => {});

//       // Act
//       await biometricService.disableBiometric();

//       // Assert
//       verify(mockSecureStorage.write('biometric_enabled', 'false')).called(1);
//       verify(mockSecureStorage.delete('biometric_failed_attempts')).called(1);
//       verify(mockSecureStorage.delete('biometric_last_failed_time')).called(1);
//     });
//   });

//   group('BiometricService - Lockout Logic', () {
//     test('isLockedOut returns false when failed attempts is less than max', () async {
//       // Arrange
//       when(mockSecureStorage.read('biometric_failed_attempts')).thenAnswer((_) async => '2');

//       // Act
//       final result = await biometricService.isLockedOut();

//       // Assert
//       expect(result, false);
//     });

//     test('isLockedOut returns true when failed attempts equals max and within lockout period', () async {
//       // Arrange
//       final now = DateTime.now();
//       final lastFailedTime = now.subtract(const Duration(minutes: 2)); // 2 minutes ago
      
//       when(mockSecureStorage.read('biometric_failed_attempts')).thenAnswer((_) async => '3');
//       when(mockSecureStorage.read('biometric_last_failed_time'))
//           .thenAnswer((_) async => lastFailedTime.toIso8601String());

//       // Act
//       final result = await biometricService.isLockedOut();

//       // Assert
//       expect(result, true);
//     });

//     test('isLockedOut returns false when lockout period has passed', () async {
//       // Arrange
//       final now = DateTime.now();
//       final lastFailedTime = now.subtract(const Duration(minutes: 6)); // 6 minutes ago (past lockout)
      
//       when(mockSecureStorage.read('biometric_failed_attempts')).thenAnswer((_) async => '3');
//       when(mockSecureStorage.read('biometric_last_failed_time'))
//           .thenAnswer((_) async => lastFailedTime.toIso8601String());
//       when(mockSecureStorage.delete('biometric_failed_attempts')).thenAnswer((_) async => {});
//       when(mockSecureStorage.delete('biometric_last_failed_time')).thenAnswer((_) async => {});

//       // Act
//       final result = await biometricService.isLockedOut();

//       // Assert
//       expect(result, false);
//       verify(mockSecureStorage.delete('biometric_failed_attempts')).called(1);
//       verify(mockSecureStorage.delete('biometric_last_failed_time')).called(1);
//     });

//     test('getRemainingLockoutMinutes returns correct remaining time', () async {
//       // Arrange
//       final now = DateTime.now();
//       final lastFailedTime = now.subtract(const Duration(minutes: 2)); // 2 minutes ago
      
//       when(mockSecureStorage.read('biometric_last_failed_time'))
//           .thenAnswer((_) async => lastFailedTime.toIso8601String());

//       // Act
//       final result = await biometricService.getRemainingLockoutMinutes();

//       // Assert
//       expect(result, 3); // 5 minutes lockout - 2 minutes passed = 3 minutes remaining
//     });
//   });

//   group('BiometricService - Authentication', () {
//     test('authenticate returns success when authentication succeeds', () async {
//       // Arrange
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
//       when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
//       when(mockSecureStorage.read('biometric_failed_attempts')).thenAnswer((_) async => '0');
//       when(mockLocalAuth.authenticate(
//         localizedReason: anyNamed('localizedReason'),
//         options: anyNamed('options'),
//       )).thenAnswer((_) async => true);
//       when(mockSecureStorage.delete('biometric_failed_attempts')).thenAnswer((_) async => {});
//       when(mockSecureStorage.delete('biometric_last_failed_time')).thenAnswer((_) async => {});

//       // Act
//       final result = await biometricService.authenticate();

//       // Assert
//       expect(result.isSuccess, true);
//       verify(mockLocalAuth.authenticate(
//         localizedReason: anyNamed('localizedReason'),
//         options: anyNamed('options'),
//       )).called(1);
//     });

//     test('authenticate returns notSupported when device does not support biometrics', () async {
//       // Arrange
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
//       when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

//       // Act
//       final result = await biometricService.authenticate();

//       // Assert
//       expect(result.isNotSupported, true);
//       verifyNever(mockLocalAuth.authenticate(
//         localizedReason: anyNamed('localizedReason'),
//         options: anyNamed('options'),
//       ));
//     });

//     test('authenticate returns notEnrolled when no biometrics are enrolled', () async {
//       // Arrange
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
//       when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

//       // Act
//       final result = await biometricService.authenticate();

//       // Assert
//       expect(result.isNotEnrolled, true);
//     });

//     test('authenticate returns lockedOut when max failed attempts reached', () async {
//       // Arrange
//       final now = DateTime.now();
//       final lastFailedTime = now.subtract(const Duration(minutes: 2));
      
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
//       when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
//       when(mockSecureStorage.read('biometric_failed_attempts')).thenAnswer((_) async => '3');
//       when(mockSecureStorage.read('biometric_last_failed_time'))
//           .thenAnswer((_) async => lastFailedTime.toIso8601String());

//       // Act
//       final result = await biometricService.authenticate();

//       // Assert
//       expect(result.isLockedOut, true);
//       expect(result.lockoutMinutes, 3);
//     });

//     test('authenticate increments failed attempts on failure', () async {
//       // Arrange
//       when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
//       when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
//       when(mockSecureStorage.read('biometric_failed_attempts')).thenAnswer((_) async => '1');
//       when(mockLocalAuth.authenticate(
//         localizedReason: anyNamed('localizedReason'),
//         options: anyNamed('options'),
//       )).thenAnswer((_) async => false);
//       when(mockSecureStorage.write('biometric_failed_attempts', '2')).thenAnswer((_) async => {});
//       when(mockSecureStorage.write('biometric_last_failed_time', any)).thenAnswer((_) async => {});

//       // Act
//       final result = await biometricService.authenticate();

//       // Assert
//       expect(result.isFailed, true);
//       verify(mockSecureStorage.write('biometric_failed_attempts', '2')).called(1);
//     });
//   });

//   group('BiometricService - Biometric Type Description', () {
//     test('getBiometricTypeDescription returns "Face ID" for face biometric', () {
//       // Arrange
//       final types = [BiometricType.face];

//       // Act
//       final result = biometricService.getBiometricTypeDescription(types);

//       // Assert
//       expect(result, 'Face ID');
//     });

//     test('getBiometricTypeDescription returns "Sidik Jari" for fingerprint biometric', () {
//       // Arrange
//       final types = [BiometricType.fingerprint];

//       // Act
//       final result = biometricService.getBiometricTypeDescription(types);

//       // Assert
//       expect(result, 'Sidik Jari');
//     });

//     test('getBiometricTypeDescription returns "Iris" for iris biometric', () {
//       // Arrange
//       final types = [BiometricType.iris];

//       // Act
//       final result = biometricService.getBiometricTypeDescription(types);

//       // Assert
//       expect(result, 'Iris');
//     });

//     test('getBiometricTypeDescription returns "Biometrik" for empty list', () {
//       // Arrange
//       final types = <BiometricType>[];

//       // Act
//       final result = biometricService.getBiometricTypeDescription(types);

//       // Assert
//       expect(result, 'Biometrik');
//     });
//   });
// }
