import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/services/http_client_service.dart';
import '../../data/models/user_model.dart';

/// Provider untuk mengelola state profil pengguna
/// Requirements: 12.1, 12.2, 12.3, 12.4, 12.5 - Profile management
class ProfileProvider extends ChangeNotifier {
  final HttpClientService _httpClient;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  ProfileProvider({
    required HttpClientService httpClient,
  }) : _httpClient = httpClient;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch user profile dari backend
  /// Requirements: 12.1 - Menampilkan halaman profil
  Future<bool> fetchProfile() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _httpClient.get(ApiConstants.profile);

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

      _errorMessage = 'Gagal memuat profil';
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on UnauthorizedException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

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
      // Requirements: 12.4 - Validasi berat badan 30-200 kg
      if (weight != null && (weight < 30 || weight > 200)) {
        _errorMessage = 'Berat badan harus antara 30-200 kg';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Requirements: 12.4 - Validasi tinggi badan 100-250 cm
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
      if (isBreastfeeding != null) {
        updateData['is_breastfeeding'] = isBreastfeeding;
      }
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
      // Requirements: 12.5 - Menampilkan pesan kesalahan spesifik
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
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

  /// Upload profile image dengan kompresi
  /// Requirements: 12.2 - Memilih gambar dari galeri atau kamera
  /// Requirements: 12.3 - Mengompresi gambar ke maksimal 500 KB
  Future<bool> uploadProfileImage(File imageFile) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Compress image to max 500KB
      final compressedFile = await _compressImage(imageFile);

      if (compressedFile == null) {
        _errorMessage = 'Gagal mengompresi gambar';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Upload image
      final response = await _httpClient.uploadFile(
        ApiConstants.uploadImage,
        filePath: compressedFile.path,
        fieldName: 'image',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>?;

        if (userData != null) {
          _user = UserModel.fromJson(userData);
          _errorMessage = null;
          _isLoading = false;
          notifyListeners();

          // Clean up compressed file if it's different from original
          if (compressedFile.path != imageFile.path) {
            try {
              await compressedFile.delete();
            } catch (e) {
              debugPrint('Failed to delete compressed file: $e');
            }
          }

          return true;
        }
      }

      _errorMessage = 'Gagal mengunggah foto profil';
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final message = e.response?.data['message'] as String?;
        _errorMessage = message ?? 'Gambar tidak valid';
      } else if (e.response?.statusCode == 413) {
        _errorMessage = 'Ukuran gambar terlalu besar';
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

  /// Compress image to max 500KB
  /// Requirements: 12.3 - Mengompresi gambar ke maksimal 500 KB
  Future<File?> _compressImage(File imageFile) async {
    try {
      // Read image file
      final bytes = await imageFile.readAsBytes();
      final originalSize = bytes.length;

      // If already under 500KB, return original
      const maxSizeBytes = 500 * 1024; // 500 KB
      if (originalSize <= maxSizeBytes) {
        return imageFile;
      }

      // Decode image
      img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return null;
      }

      // Make a non-nullable copy for processing
      img.Image currentImage = decodedImage;

      // Calculate compression quality
      int quality = 95;
      List<int> compressedBytes;

      // Compress with decreasing quality until under 500KB
      do {
        compressedBytes = img.encodeJpg(currentImage, quality: quality);
        quality -= 5;

        // Prevent infinite loop
        if (quality < 10) {
          // If still too large, resize image
          final ratio = 0.8;
          final newWidth = (currentImage.width * ratio).round();
          final newHeight = (currentImage.height * ratio).round();
          currentImage = img.copyResize(
            currentImage,
            width: newWidth,
            height: newHeight,
          );
          quality = 85; // Reset quality after resize
        }
      } while (compressedBytes.length > maxSizeBytes && quality >= 10);

      // Save compressed image to temporary file
      final tempDir = imageFile.parent;
      final tempPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(tempPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Set user data (used by AuthProvider after login/register)
  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  /// Clear user data (used during logout)
  void clearUser() {
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}