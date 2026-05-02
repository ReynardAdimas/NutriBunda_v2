import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'secure_storage_service.dart';

/// Service untuk mengelola autentikasi biometrik
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
class BiometricService {
  final LocalAuthentication _localAuth;
  final SecureStorageService _secureStorage;

  // Key untuk menyimpan status biometric enabled
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _failedAttemptsKey = 'biometric_failed_attempts';
  static const String _lastFailedTimeKey = 'biometric_last_failed_time';

  // Konstanta
  static const int maxFailedAttempts = 3;
  static const int lockoutDurationMinutes = 5;

  BiometricService({
    LocalAuthentication? localAuth,
    required SecureStorageService secureStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage;

  /// Cek apakah perangkat mendukung biometrik
  /// Requirements: 2.1, 2.3 - Menawarkan opsi biometrik jika perangkat mendukung
  Future<bool> isDeviceSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Error checking biometric support: ${e.message}');
      return false;
    }
  }

  /// Cek apakah ada biometrik yang terdaftar di perangkat
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      debugPrint('Error checking biometric availability: ${e.message}');
      return false;
    }
  }

  /// Dapatkan daftar tipe biometrik yang tersedia
  /// (fingerprint, face, iris, dll)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Error getting available biometrics: ${e.message}');
      return [];
    }
  }

  /// Cek apakah biometric authentication sudah diaktifkan oleh user
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(_biometricEnabledKey);
    return enabled == 'true';
  }

  /// Aktifkan biometric authentication
  /// Requirements: 2.5 - Meminta konfirmasi password sebelum mengaktifkan
  Future<void> enableBiometric() async {
    await _secureStorage.write(_biometricEnabledKey, 'true');
    // Reset failed attempts saat enable
    await _resetFailedAttempts();
  }

  /// Nonaktifkan biometric authentication
  Future<void> disableBiometric() async {
    await _secureStorage.write(_biometricEnabledKey, 'false');
    await _resetFailedAttempts();
  }

  /// Cek apakah biometric sedang dalam status lockout
  /// Requirements: 2.4 - Menonaktifkan sementara setelah 3 kali gagal
  Future<bool> isLockedOut() async {
    final failedAttempts = await _getFailedAttempts();
    if (failedAttempts < maxFailedAttempts) {
      return false;
    }

    // Cek apakah lockout duration sudah lewat
    final lastFailedTimeStr = await _secureStorage.read(_lastFailedTimeKey);
    if (lastFailedTimeStr == null) {
      return false;
    }

    final lastFailedTime = DateTime.parse(lastFailedTimeStr);
    final now = DateTime.now();
    final difference = now.difference(lastFailedTime);

    if (difference.inMinutes >= lockoutDurationMinutes) {
      // Lockout period sudah lewat, reset counter
      await _resetFailedAttempts();
      return false;
    }

    return true;
  }

  /// Dapatkan sisa waktu lockout dalam menit
  Future<int> getRemainingLockoutMinutes() async {
    final lastFailedTimeStr = await _secureStorage.read(_lastFailedTimeKey);
    if (lastFailedTimeStr == null) {
      return 0;
    }

    final lastFailedTime = DateTime.parse(lastFailedTimeStr);
    final now = DateTime.now();
    final difference = now.difference(lastFailedTime);
    final remaining = lockoutDurationMinutes - difference.inMinutes;

    return remaining > 0 ? remaining : 0;
  }

  /// Authenticate menggunakan biometrik
  /// Requirements: 2.1, 2.2, 2.4 - Autentikasi biometrik dengan tracking failed attempts
  Future<BiometricAuthResult> authenticate({
    String localizedReason = 'Gunakan sidik jari atau Face ID untuk masuk',
  }) async {
    try {
      // Cek apakah device support biometric
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return BiometricAuthResult.notSupported;
      }

      // Cek apakah biometric tersedia (ada yang terdaftar)
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return BiometricAuthResult.notEnrolled;
      }

      // Cek apakah sedang dalam lockout
      if (await isLockedOut()) {
        final remainingMinutes = await getRemainingLockoutMinutes();
        return BiometricAuthResult.lockedOut(remainingMinutes);
      }

      // Lakukan autentikasi
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true
      );

      if (didAuthenticate) {
        // Reset failed attempts jika berhasil
        await _resetFailedAttempts();
        return BiometricAuthResult.success;
      } else {
        // Increment failed attempts
        await _incrementFailedAttempts();
        final failedAttempts = await _getFailedAttempts();

        if (failedAttempts >= maxFailedAttempts) {
          return BiometricAuthResult.lockedOut(lockoutDurationMinutes);
        }

        return BiometricAuthResult.failed;
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.code} - ${e.message}');

      // Handle specific error codes
      switch (e.code) {
        case 'NotAvailable':
          return BiometricAuthResult.notSupported;
        case 'NotEnrolled':
          return BiometricAuthResult.notEnrolled; 
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricAuthResult.lockedOut(lockoutDurationMinutes); 
        case 'PasscodeNotSet':
          return BiometricAuthResult.passcodeNotSet; 
        default:
          return BiometricAuthResult.cancelled;
      }
    } catch (e) {
      debugPrint('Unexpected biometric error: $e');
      return BiometricAuthResult.error;
    }
  }

  /// Dapatkan jumlah failed attempts
  Future<int> _getFailedAttempts() async {
    final attemptsStr = await _secureStorage.read(_failedAttemptsKey);
    if (attemptsStr == null) {
      return 0;
    }
    return int.tryParse(attemptsStr) ?? 0;
  }

  /// Increment failed attempts counter
  Future<void> _incrementFailedAttempts() async {
    final currentAttempts = await _getFailedAttempts();
    final newAttempts = currentAttempts + 1;
    await _secureStorage.write(_failedAttemptsKey, newAttempts.toString());
    await _secureStorage.write(_lastFailedTimeKey, DateTime.now().toIso8601String());
  }

  /// Reset failed attempts counter
  Future<void> _resetFailedAttempts() async {
    await _secureStorage.delete(_failedAttemptsKey);
    await _secureStorage.delete(_lastFailedTimeKey);
  }

  /// Dapatkan deskripsi biometric type yang user-friendly
  String getBiometricTypeDescription(List<BiometricType> types) {
    if (types.isEmpty) {
      return 'Biometrik';
    }

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Sidik Jari';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak)) {
      return 'Biometrik';
    }

    return 'Biometrik';
  }
}

/// Result dari biometric authentication
class BiometricAuthResult {
  final BiometricAuthStatus status;
  final int? lockoutMinutes;

  const BiometricAuthResult._(this.status, [this.lockoutMinutes]);

  static const BiometricAuthResult success = BiometricAuthResult._(BiometricAuthStatus.success);
  static const BiometricAuthResult failed = BiometricAuthResult._(BiometricAuthStatus.failed);
  static const BiometricAuthResult cancelled = BiometricAuthResult._(BiometricAuthStatus.cancelled);
  static const BiometricAuthResult notSupported = BiometricAuthResult._(BiometricAuthStatus.notSupported);
  static const BiometricAuthResult notEnrolled = BiometricAuthResult._(BiometricAuthStatus.notEnrolled);
  static const BiometricAuthResult passcodeNotSet = BiometricAuthResult._(BiometricAuthStatus.passcodeNotSet);
  static const BiometricAuthResult error = BiometricAuthResult._(BiometricAuthStatus.error);

  factory BiometricAuthResult.lockedOut(int minutes) {
    return BiometricAuthResult._(BiometricAuthStatus.lockedOut, minutes);
  }

  bool get isSuccess => status == BiometricAuthStatus.success;
  bool get isFailed => status == BiometricAuthStatus.failed;
  bool get isCancelled => status == BiometricAuthStatus.cancelled;
  bool get isLockedOut => status == BiometricAuthStatus.lockedOut;
  bool get isNotSupported => status == BiometricAuthStatus.notSupported;
  bool get isNotEnrolled => status == BiometricAuthStatus.notEnrolled;
  bool get isPasscodeNotSet => status == BiometricAuthStatus.passcodeNotSet;
  bool get isError => status == BiometricAuthStatus.error;

  String get message {
    switch (status) {
      case BiometricAuthStatus.success:
        return 'Autentikasi berhasil';
      case BiometricAuthStatus.failed:
        return 'Autentikasi gagal. Silakan coba lagi.';
      case BiometricAuthStatus.cancelled:
        return 'Autentikasi dibatalkan';
      case BiometricAuthStatus.notSupported:
        return 'Perangkat tidak mendukung autentikasi biometrik';
      case BiometricAuthStatus.notEnrolled:
        return 'Tidak ada biometrik yang terdaftar. Silakan daftarkan sidik jari atau Face ID di pengaturan perangkat.';
      case BiometricAuthStatus.passcodeNotSet:
        return 'Passcode perangkat belum diatur. Silakan atur passcode terlebih dahulu.';
      case BiometricAuthStatus.lockedOut:
        return 'Terlalu banyak percobaan gagal. Silakan coba lagi dalam $lockoutMinutes menit atau gunakan password.';
      case BiometricAuthStatus.error:
        return 'Terjadi kesalahan saat autentikasi';
    }
  }
}

/// Status dari biometric authentication
enum BiometricAuthStatus {
  success,
  failed,
  cancelled,
  notSupported,
  notEnrolled,
  passcodeNotSet,
  lockedOut,
  error,
}
