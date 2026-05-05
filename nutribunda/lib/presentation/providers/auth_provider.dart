import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/services/http_client_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/biometric_service.dart';
import '../../data/models/user_model.dart';

/// Provider untuk mengelola state autentikasi
/// Requirements: 1.1, 1.5, 1.7, 2.1, 2.2, 2.3, 2.4, 2.5
class AuthProvider extends ChangeNotifier {
  final HttpClientService _httpClient;
  final SecureStorageService _secureStorage;
  final BiometricService _biometricService;

  UserModel? _user;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({
    required HttpClientService httpClient,
    required SecureStorageService secureStorage,
    required BiometricService biometricService,
  })  : _httpClient = httpClient,
        _secureStorage = secureStorage,
        _biometricService = biometricService;

  // Getters
  UserModel? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initialize auth state dari secure storage
  /// Dipanggil saat aplikasi pertama kali dibuka
  Future<void> initializeAuth() async {
    try {
      _isLoading = true;
      notifyListeners();

      final token = await _secureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        _token = token;
        // Verify token dengan backend dan ambil user data
        await _fetchUserProfile();
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize authentication';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login dengan email dan password
  /// Requirements: 1.1 - Auth_Service menerima email dan password
  /// Requirements: 1.5 - Mengembalikan pesan kesalahan yang deskriptif
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validasi input
      if (email.isEmpty || password.isEmpty) {
        _errorMessage = 'Email dan password tidak boleh kosong';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validasi format email
      if (!_isValidEmail(email)) {
        _errorMessage = 'Format email tidak valid';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Call login API
      final response = await _httpClient.post(
        ApiConstants.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Extract token dan user data
        _token = data['token'] as String?;
        if (_token == null) {
          _errorMessage = 'Token tidak ditemukan dalam response';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Parse user data
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          _user = UserModel.fromJson(userData);
        }

        // Simpan token ke secure storage
        // Requirements: 1.4 - JWT disimpan di penyimpanan terenkripsi
        await _secureStorage.saveAccessToken(_token!);
        await _secureStorage.saveUserEmail(email);
        if (_user != null) {
          await _secureStorage.saveUserId(_user!.id);
        }

        _isAuthenticated = true;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Login gagal. Silakan coba lagi.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on ValidationException catch (e) {
      // Requirements: 1.5 - Pesan kesalahan yang deskriptif
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on UnauthorizedException {
      _errorMessage = 'Email atau password salah';
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException {
      _errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _errorMessage = 'Email atau password salah';
      } else if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] as String?;
        _errorMessage = message ?? 'Data login tidak valid';
      } else {
        _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan yang tidak terduga: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register pengguna baru
  /// Requirements: 1.1 - Auth_Service menerima nama lengkap, email, dan password
  Future<bool> register(String fullName, String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validasi input
      if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
        _errorMessage = 'Semua field harus diisi';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validasi format email
      if (!_isValidEmail(email)) {
        _errorMessage = 'Format email tidak valid';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validasi password strength
      final passwordValidation = _validatePassword(password);
      if (passwordValidation != null) {
        _errorMessage = passwordValidation;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Call register API
      final response = await _httpClient.post(
        ApiConstants.register,
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        
        // Extract token dan user data
        _token = data['token'] as String?;
        if (_token == null) {
          _errorMessage = 'Token tidak ditemukan dalam response';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Parse user data
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          _user = UserModel.fromJson(userData);
        }

        // Simpan token ke secure storage
        await _secureStorage.saveAccessToken(_token!);
        await _secureStorage.saveUserEmail(email);
        if (_user != null) {
          await _secureStorage.saveUserId(_user!.id);
        }

        _isAuthenticated = true;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Registrasi gagal. Silakan coba lagi.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException {
      _errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] as String?;
        _errorMessage = message ?? 'Data registrasi tidak valid';
      } else if (e.response?.statusCode == 409) {
        _errorMessage = 'Email sudah terdaftar';
      } else {
        _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan yang tidak terduga: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout pengguna
  /// Requirements: 1.7 - Menghapus JWT dari storage dan redirect ke login
  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Call logout API (optional, untuk invalidate token di server)
      try {
        await _httpClient.post(ApiConstants.logout);
      } catch (e) {
        // Ignore error dari logout API, tetap lanjutkan logout lokal
        debugPrint('Logout API error: $e');
      }

      // Hapus token dari secure storage
      await _secureStorage.deleteTokens();
      await _secureStorage.clearAll();

      // Reset state
      _user = null;
      _token = null;
      _isAuthenticated = false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Gagal logout: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login dengan biometric authentication
  /// Requirements: 2.1, 2.2, 2.4 - Autentikasi biometrik dengan fallback
  Future<bool> loginWithBiometric() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Cek apakah biometric enabled
      final isBiometricEnabled = await _biometricService.isBiometricEnabled();
      if (!isBiometricEnabled) {
        _errorMessage = 'Autentikasi biometrik belum diaktifkan';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Cek apakah ada token tersimpan
      final storedToken = await _secureStorage.getAccessToken();
      if (storedToken == null || storedToken.isEmpty) {
        _errorMessage = 'Tidak ada sesi tersimpan. Silakan login dengan email dan password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Lakukan autentikasi biometrik
      final authResult = await _biometricService.authenticate(
        localizedReason: 'Gunakan sidik jari atau Face ID untuk masuk ke NutriBunda',
      );

      if (authResult.isSuccess) {
        // Requirements: 2.2 - Mengambil JWT dari Secure_Storage dan melanjutkan sesi
        _token = storedToken;

        // Verify token dengan backend
        final isValid = await _verifyToken(storedToken);
        if (isValid) {
          _isAuthenticated = true;
          _errorMessage = null;
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          // Token expired atau invalid
          _errorMessage = 'Sesi telah berakhir. Silakan login dengan email dan password.';
          await _secureStorage.deleteTokens();
          _token = null;
          _isAuthenticated = false;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else if (authResult.isLockedOut) {
        // Requirements: 2.4 - Menonaktifkan sementara setelah 3 kali gagal
        _errorMessage = authResult.message;
        _isLoading = false;
        notifyListeners();
        return false;
      } else if (authResult.isNotSupported || authResult.isNotEnrolled) {
        // Requirements: 2.3 - Menonaktifkan opsi biometrik jika tidak didukung
        _errorMessage = authResult.message;
        _isLoading = false;
        notifyListeners();
        return false;
      } else {
        // Failed, cancelled, or other errors
        _errorMessage = authResult.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan saat autentikasi biometrik: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify token dengan backend
  Future<bool> _verifyToken(String token) async {
    try {
      // Set token temporarily untuk request
      _token = token;
      
      // Fetch user profile untuk verify token
      final response = await _httpClient.get(ApiConstants.profile);
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>?;
        
        if (userData != null) {
          _user = UserModel.fromJson(userData);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Token verification failed: $e');
      return false;
    }
  }

  /// Fetch user profile dari backend
  Future<void> _fetchUserProfile() async {
    try {
      final response = await _httpClient.get(ApiConstants.profile);
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>?;
        
        if (userData != null) {
          _user = UserModel.fromJson(userData);
          _isAuthenticated = true;
        }
      }
    } catch (e) {
      // Token mungkin expired atau invalid
      await _secureStorage.deleteTokens();
      _token = null;
      _isAuthenticated = false;
    }
  }

  /// Cek apakah biometric authentication tersedia dan enabled
  Future<bool> isBiometricAvailable() async {
    final isSupported = await _biometricService.isDeviceSupported();
    final isEnabled = await _biometricService.isBiometricEnabled();
    return isSupported && isEnabled;
  }

  /// Dapatkan BiometricService untuk digunakan di settings
  BiometricService get biometricService => _biometricService;

  /// Update user profile
  /// Requirements: 12.4 - Validasi dan update data profil
  Future<bool> updateProfile({
    String? fullName,
    double? weight,
    double? height,
    int? age,
    bool? isBreastfeeding,
    String? activityLevel,
    String? timezone,
    DateTime? babyBirthDate,
    double? babyWeightKg,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validasi data
      if (weight != null && (weight < 30 || weight > 200)) {
        _errorMessage = 'Berat badan harus antara 30-200 kg';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (height != null && (height < 100 || height > 250)) {
        _errorMessage = 'Tinggi badan harus antara 100-250 cm';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (age != null && (age < 15 || age > 60)) {
        _errorMessage = 'Usia harus antara 15-60 tahun';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Prepare update data
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (weight != null) updateData['weight'] = weight;
      if (height != null) updateData['height'] = height;
      if (age != null) updateData['age'] = age;
      if (isBreastfeeding != null) updateData['is_breastfeeding'] = isBreastfeeding;
      if (activityLevel != null) updateData['activity_level'] = activityLevel;
      if (timezone != null) updateData['timezone'] = timezone;
      if (babyBirthDate != null) {
        updateData['baby_birth_date'] =
            babyBirthDate.toIso8601String().substring(0, 10);
      }
      if (babyWeightKg != null) updateData['baby_weight_kg'] = babyWeightKg;

      // Call update profile API
      final response = await _httpClient.put(
        ApiConstants.profile,
        data: updateData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>?;
        
        if (userData != null) {
          _user = UserModel.fromJson(userData);
          _errorMessage = null;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _errorMessage = 'Gagal memperbarui profil';
      _isLoading = false;
      notifyListeners();
      return false;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException {
      _errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] as String?;
        _errorMessage = message ?? 'Data profil tidak valid';
      } else {
        _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan yang tidak terduga: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== Validation Helpers ====================

  /// Validasi format email
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validasi password strength
  /// Return null jika valid, return error message jika tidak valid
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password minimal 8 karakter';
    }
    
    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password harus mengandung minimal 1 huruf besar';
    }
    
    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password harus mengandung minimal 1 huruf kecil';
    }
    
    // Check for at least one digit
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password harus mengandung minimal 1 angka';
    }
    
    return null; // Valid
  }
}