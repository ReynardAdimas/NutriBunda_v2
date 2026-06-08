import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service untuk mengelola penyimpanan terenkripsi menggunakan flutter_secure_storage
/// Digunakan untuk menyimpan JWT token dan data sensitif lainnya
class SecureStorageService {
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyLastSyncTime = 'last_sync_time';

  SecureStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  // ==================== Token Management ====================

  /// Menyimpan access token ke secure storage
  /// Requirements: 1.4 - JWT harus disimpan di penyimpanan terenkripsi
  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(key: _keyAccessToken, value: token);
    } catch (e) {
      throw Exception('Failed to save access token: $e');
    }
  }

  /// Mengambil access token dari secure storage
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _keyAccessToken);
    } catch (e) {
      throw Exception('Failed to get access token: $e');
    }
  }

  /// Menyimpan refresh token ke secure storage
  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _keyRefreshToken, value: token);
    } catch (e) {
      throw Exception('Failed to save refresh token: $e');
    }
  }

  /// Mengambil refresh token dari secure storage
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _keyRefreshToken);
    } catch (e) {
      throw Exception('Failed to get refresh token: $e');
    }
  }

  /// Menghapus semua token dari secure storage
  Future<void> deleteTokens() async {
    try {
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
    } catch (e) {
      throw Exception('Failed to delete tokens: $e');
    }
  }

  /// Memeriksa apakah user memiliki token yang valid
  Future<bool> hasValidToken() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==================== User Data Management ====================

  /// Menyimpan user ID
  Future<void> saveUserId(String userId) async {
    try {
      await _secureStorage.write(key: _keyUserId, value: userId);
    } catch (e) {
      throw Exception('Failed to save user ID: $e');
    }
  }

  /// Mengambil user ID
  Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _keyUserId);
    } catch (e) {
      throw Exception('Failed to get user ID: $e');
    }
  }

  /// Menyimpan user email
  Future<void> saveUserEmail(String email) async {
    try {
      await _secureStorage.write(key: _keyUserEmail, value: email);
    } catch (e) {
      throw Exception('Failed to save user email: $e');
    }
  }

  /// Mengambil user email
  Future<String?> getUserEmail() async {
    try {
      return await _secureStorage.read(key: _keyUserEmail);
    } catch (e) {
      throw Exception('Failed to get user email: $e');
    }
  }

  // ==================== Biometric Settings ====================

  /// Menyimpan status biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _keyBiometricEnabled,
        value: enabled.toString(),
      );
    } catch (e) {
      throw Exception('Failed to save biometric setting: $e');
    }
  }

  /// Mengambil status biometric authentication
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _secureStorage.read(key: _keyBiometricEnabled);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  // ==================== Sync Management ====================

  /// Menyimpan waktu sinkronisasi terakhir
  /// Requirements: 3.5, 4.1, 7.4 - Track last sync time for incremental sync
  Future<void> setLastSyncTime(String timestamp) async {
    try {
      await _secureStorage.write(key: _keyLastSyncTime, value: timestamp);
    } catch (e) {
      throw Exception('Failed to save last sync time: $e');
    }
  }

  /// Mengambil waktu sinkronisasi terakhir
  /// Returns RFC3339 timestamp string or null if never synced
  Future<String?> getLastSyncTime() async {
    try {
      return await _secureStorage.read(key: _keyLastSyncTime);
    } catch (e) {
      return null;
    }
  }

  /// Menghapus waktu sinkronisasi terakhir
  Future<void> clearLastSyncTime() async {
    try {
      await _secureStorage.delete(key: _keyLastSyncTime);
    } catch (e) {
      throw Exception('Failed to clear last sync time: $e');
    }
  }

  // ==================== Clear All Data ====================

  /// Menghapus semua data dari secure storage
  /// Digunakan saat logout atau reset aplikasi
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw Exception('Failed to clear secure storage: $e');
    }
  }

  // ==================== Utility Methods ====================

  /// Menyimpan data custom ke secure storage
  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      throw Exception('Failed to write to secure storage: $e');
    }
  }

  /// Membaca data custom dari secure storage
  Future<String?> read(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      throw Exception('Failed to read from secure storage: $e');
    }
  }

  /// Menghapus data custom dari secure storage
  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      throw Exception('Failed to delete from secure storage: $e');
    }
  }

  /// Memeriksa apakah key tertentu ada di secure storage
  Future<bool> containsKey(String key) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      return false;
    }
  }

  /// Mendapatkan semua keys yang tersimpan
  Future<Map<String, String>> readAll() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      throw Exception('Failed to read all from secure storage: $e');
    }
  }
}
