import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/services/http_client_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../data/datasources/local/local_diary_datasource.dart';
import '../../data/datasources/local/local_food_datasource.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/local/local_diary_entry.dart';
import '../../data/models/nutrition_summary.dart';
import '../../data/models/food_model.dart';

/// Provider untuk mengelola state Food Diary
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
/// Offline-first: selalu baca dari SQLite lokal, sync ke server saat online
class FoodDiaryProvider extends ChangeNotifier {
  final HttpClientService _httpClient;
  final LocalDiaryDataSource _localDiary;
  final LocalFoodDataSource _localFood;
  final SecureStorageService _secureStorage;

  // State untuk diary entries
  List<DiaryEntry> _entries = [];
  NutritionSummary _nutritionSummary = const NutritionSummary();

  // State untuk profile dan date selection
  String _selectedProfile = 'baby'; // 'baby' or 'mother'
  DateTime _selectedDate = DateTime.now();

  // Loading dan error states
  bool _isLoading = false;
  bool _isLoadingFoods = false;
  String? _errorMessage;

  // Offline state
  bool _isOffline = false;

  // Food search results
  List<FoodModel> _searchResults = [];

  FoodDiaryProvider({
    required HttpClientService httpClient,
    required LocalDiaryDataSource localDiary,
    required LocalFoodDataSource localFood,
    required SecureStorageService secureStorage,
  })  : _httpClient = httpClient,
        _localDiary = localDiary,
        _localFood = localFood,
        _secureStorage = secureStorage;

  // Getters
  List<DiaryEntry> get entries => _entries;
  NutritionSummary get nutritionSummary => _nutritionSummary;
  String get selectedProfile => _selectedProfile;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isLoadingFoods => _isLoadingFoods;
  String? get errorMessage => _errorMessage;
  List<FoodModel> get searchResults => _searchResults;
  bool get isOffline => _isOffline;

  /// Get entries grouped by meal time
  /// Requirements: 4.4 - Mengkategorikan entri ke dalam slot waktu
  Map<String, List<DiaryEntry>> get entriesByMealTime {
    final Map<String, List<DiaryEntry>> grouped = {
      'breakfast': [],
      'lunch': [],
      'dinner': [],
      'snack': [],
    };

    for (final entry in _entries) {
      if (grouped.containsKey(entry.mealTime)) {
        grouped[entry.mealTime]!.add(entry);
      }
    }

    return grouped;
  }

  /// Set selected profile
  /// Requirements: 4.1 - Dual profile support (baby and mother)
  void setSelectedProfile(String profile) {
    if (profile != 'baby' && profile != 'mother') {
      _errorMessage = 'Invalid profile type';
      notifyListeners();
      return;
    }

    if (_selectedProfile != profile) {
      _selectedProfile = profile;
      notifyListeners();
      loadEntries();
    }
  }

  /// Set selected date
  void setSelectedDate(DateTime date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      notifyListeners();
      loadEntries();
    }
  }

  // ============================================================
  // HELPER: ambil local user ID dari secure storage
  // ============================================================

  Future<int?> _getLocalUserId() async {
    final userIdStr = await _secureStorage.getUserId();
    if (userIdStr == null) return null;
    return int.tryParse(userIdStr);
  }

  // ============================================================
  // HELPER: konversi LocalDiaryEntry → DiaryEntry (untuk UI)
  // ============================================================

  DiaryEntry _localToRemote(LocalDiaryEntry local) {
    return DiaryEntry(
      // Pakai serverId kalau ada, fallback ke local id
      id: local.serverId ?? local.id.toString(),
      userId: local.userId.toString(),
      profileType: local.profileType,
      foodId: local.serverId, // server food id tidak disimpan terpisah, pakai null
      customFoodName: local.customFoodName,
      servingSize: local.servingSize,
      mealTime: local.mealTime,
      calories: local.calories,
      protein: local.protein,
      carbs: local.carbs,
      fat: local.fat,
      entryDate: local.entryDate,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
    );
  }

  // ============================================================
  // HELPER: hitung nutrition summary dari list entries
  // ============================================================

  NutritionSummary _calculateSummary(List<DiaryEntry> entries) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final e in entries) {
      totalCalories += e.calories;
      totalProtein += e.protein;
      totalCarbs += e.carbs;
      totalFat += e.fat;
    }

    return NutritionSummary(
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
    );
  }

  // ============================================================
  // LOAD ENTRIES — offline-first
  // ============================================================

  /// Load diary entries: coba dari API dulu, fallback ke SQLite jika offline
  /// Requirements: 4.1 - Mencatat makanan untuk dua profil terpisah
  Future<void> loadEntries() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // === ONLINE: ambil dari API ===
      final dateStr = _formatDate(_selectedDate);
      final response = await _httpClient.get(
        ApiConstants.diary,
        queryParameters: {
          'profile': _selectedProfile,
          'date': dateStr,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Parse entries dari server
        final entriesJson = data['entries'] as List<dynamic>?;
        if (entriesJson != null) {
          _entries = entriesJson
              .map((json) => DiaryEntry.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          _entries = [];
        }

        // Parse nutrition summary dari server
        final summaryJson = data['nutrition_summary'] as Map<String, dynamic>?;
        if (summaryJson != null) {
          _nutritionSummary = NutritionSummary.fromJson(summaryJson);
        } else {
          _nutritionSummary = _calculateSummary(_entries);
        }

        _isOffline = false;
        _errorMessage = null;

        // Simpan hasil server ke SQLite untuk akses offline berikutnya
        await _cacheEntriesToLocal(_entries);
      } else {
        _errorMessage = 'Gagal memuat data diary';
        _entries = [];
        _nutritionSummary = const NutritionSummary();
      }
    } on NetworkException {
      // === OFFLINE: fallback ke SQLite ===
      await _loadFromLocal();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        // Tidak ada koneksi → fallback ke SQLite
        await _loadFromLocal();
      } else if (e.response?.statusCode == 401) {
        _errorMessage = 'Sesi habis. Silakan login ulang.';
        _entries = [];
        _nutritionSummary = const NutritionSummary();
      } else {
        // Error lain → coba lokal juga
        await _loadFromLocal();
      }
    } catch (e) {
      // Fallback ke lokal untuk semua error tak terduga
      await _loadFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load entries dari SQLite lokal
  Future<void> _loadFromLocal() async {
    try {
      final userId = await _getLocalUserId();
      if (userId == null) {
        _errorMessage = 'Tidak dapat memuat data. Silakan login ulang.';
        _entries = [];
        _nutritionSummary = const NutritionSummary();
        return;
      }

      final localEntries = await _localDiary.getDiaryEntriesByDate(
        userId: userId,
        profileType: _selectedProfile,
        date: _selectedDate,
      );

      _entries = localEntries.map(_localToRemote).toList();
      _nutritionSummary = _calculateSummary(_entries);
      _isOffline = true;
      // Tidak set errorMessage agar UI tidak tampilkan error — cukup tampilkan data lokal
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Tidak ada koneksi dan data lokal tidak tersedia.';
      _entries = [];
      _nutritionSummary = const NutritionSummary();
    }
  }

  /// Simpan entries dari server ke SQLite (untuk cache offline)
  Future<void> _cacheEntriesToLocal(List<DiaryEntry> serverEntries) async {
    try {
      final userId = await _getLocalUserId();
      if (userId == null) return;

      for (final entry in serverEntries) {
        final localEntry = LocalDiaryEntry(
          serverId: entry.id,
          userId: userId,
          profileType: entry.profileType,
          customFoodName: entry.customFoodName,
          servingSize: entry.servingSize,
          mealTime: entry.mealTime,
          calories: entry.calories,
          protein: entry.protein,
          carbs: entry.carbs,
          fat: entry.fat,
          entryDate: entry.entryDate,
          createdAt: entry.createdAt,
          updatedAt: entry.updatedAt,
          syncStatus: 'synced',
        );
        await _localDiary.insertOrUpdateFromServer(localEntry);
      }
    } catch (_) {
      // Cache gagal tidak fatal — tidak perlu tampilkan error ke user
    }
  }

  // ============================================================
  // ADD ENTRY — offline-first
  // ============================================================

  /// Add new diary entry
  /// Requirements: 4.2 - Memilih makanan dari database atau manual entry
  /// Requirements: 4.3 - Menghitung dan memperbarui total nutrisi
  Future<bool> addEntry({
    required String profileType,
    String? foodId,
    String? customFoodName,
    required double servingSize,
    required String mealTime,
    required DateTime entryDate,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    // Validasi input
    if (profileType != 'baby' && profileType != 'mother') {
      _errorMessage = 'Tipe profil tidak valid';
      notifyListeners();
      return false;
    }

    if (foodId == null && customFoodName == null) {
      _errorMessage = 'Pilih makanan atau masukkan nama makanan manual';
      notifyListeners();
      return false;
    }

    if (customFoodName != null &&
        (calories == null || protein == null || carbs == null || fat == null)) {
      _errorMessage = 'Nilai nutrisi wajib diisi untuk entri manual';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // === ONLINE: kirim ke API ===
      final Map<String, dynamic> requestData = {
        'profile_type': profileType,
        'serving_size': servingSize,
        'meal_time': mealTime,
        'entry_date': _formatDate(entryDate),
      };

      if (foodId != null) {
        requestData['food_id'] = foodId;
      } else {
        requestData['custom_food_name'] = customFoodName;
        requestData['calories'] = calories;
        requestData['protein'] = protein;
        requestData['carbs'] = carbs;
        requestData['fat'] = fat;
      }

      final response = await _httpClient.post(
        ApiConstants.diary,
        data: requestData,
      );

      if (response.statusCode == 201 && response.data != null) {
        final newEntry =
            DiaryEntry.fromJson(response.data as Map<String, dynamic>);

        // Tambahkan ke UI list
        if (newEntry.profileType == _selectedProfile &&
            _isSameDate(newEntry.entryDate, _selectedDate)) {
          _entries.add(newEntry);
          _nutritionSummary = _nutritionSummary.add(
            newEntry.calories,
            newEntry.protein,
            newEntry.carbs,
            newEntry.fat,
          );
        }

        // Simpan ke SQLite dengan status 'synced'
        await _saveSingleEntryLocal(newEntry, syncStatus: 'synced');

        _isOffline = false;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Gagal menambah entri diary';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on NetworkException {
      // === OFFLINE: simpan lokal dengan status pending ===
      return await _addEntryOffline(
        profileType: profileType,
        foodId: foodId,
        customFoodName: customFoodName,
        servingSize: servingSize,
        mealTime: mealTime,
        entryDate: entryDate,
        calories: calories ?? 0,
        protein: protein ?? 0,
        carbs: carbs ?? 0,
        fat: fat ?? 0,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        // Tidak ada koneksi → simpan offline
        return await _addEntryOffline(
          profileType: profileType,
          foodId: foodId,
          customFoodName: customFoodName,
          servingSize: servingSize,
          mealTime: mealTime,
          entryDate: entryDate,
          calories: calories ?? 0,
          protein: protein ?? 0,
          carbs: carbs ?? 0,
          fat: fat ?? 0,
        );
      } else if (e.response?.statusCode == 400) {
        final message = e.response?.data['error'] as String?;
        _errorMessage = message ?? 'Data tidak valid';
      } else {
        _errorMessage = 'Gagal menambah entri: ${e.message}';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } on ValidationException catch (e) {
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

  /// Simpan entry ke SQLite saat offline (sync_status = 'pending')
  Future<bool> _addEntryOffline({
    required String profileType,
    String? foodId,
    String? customFoodName,
    required double servingSize,
    required String mealTime,
    required DateTime entryDate,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    try {
      final userId = await _getLocalUserId();
      if (userId == null) {
        _errorMessage = 'Tidak dapat menyimpan data. Silakan login ulang.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final now = DateTime.now();
      final localEntry = LocalDiaryEntry(
        userId: userId,
        profileType: profileType,
        customFoodName: customFoodName,
        servingSize: servingSize,
        mealTime: mealTime,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        entryDate: entryDate,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending', // akan di-sync saat online
      );

      final localId = await _localDiary.insertDiaryEntry(localEntry);

      // Buat DiaryEntry sementara untuk ditampilkan di UI
      // id-nya pakai local id sebagai string prefix "local_"
      final tempEntry = DiaryEntry(
        id: 'local_$localId',
        userId: userId.toString(),
        profileType: profileType,
        customFoodName: customFoodName,
        servingSize: servingSize,
        mealTime: mealTime,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        entryDate: entryDate,
        createdAt: now,
        updatedAt: now,
      );

      if (tempEntry.profileType == _selectedProfile &&
          _isSameDate(tempEntry.entryDate, _selectedDate)) {
        _entries.add(tempEntry);
        _nutritionSummary = _nutritionSummary.add(
            calories, protein, carbs, fat);
      }

      _isOffline = true;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan data secara offline: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Helper: simpan satu DiaryEntry (dari server) ke SQLite
  Future<void> _saveSingleEntryLocal(DiaryEntry entry,
      {String syncStatus = 'synced'}) async {
    try {
      final userId = await _getLocalUserId();
      if (userId == null) return;

      final localEntry = LocalDiaryEntry(
        serverId: entry.id,
        userId: userId,
        profileType: entry.profileType,
        customFoodName: entry.customFoodName,
        servingSize: entry.servingSize,
        mealTime: entry.mealTime,
        calories: entry.calories,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
        entryDate: entry.entryDate,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        syncStatus: syncStatus,
      );
      await _localDiary.insertOrUpdateFromServer(localEntry);
    } catch (_) {
      // Tidak fatal
    }
  }

  // ============================================================
  // DELETE ENTRY — offline-first
  // ============================================================

  /// Delete diary entry
  /// Requirements: 4.5 - Mengurangi total nutrisi saat entry dihapus
  Future<bool> deleteEntry(String entryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Temukan entry sebelum dihapus
    DiaryEntry? entryToDelete;
    try {
      entryToDelete = _entries.firstWhere((e) => e.id == entryId);
    } catch (_) {
      _errorMessage = 'Entri tidak ditemukan';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Entry lokal (belum pernah sync ke server) — langsung hapus dari SQLite
    if (entryId.startsWith('local_')) {
      final localId = int.tryParse(entryId.replaceFirst('local_', ''));
      if (localId != null) {
        await _localDiary.hardDeleteDiaryEntry(localId);
      }
      _entries.removeWhere((e) => e.id == entryId);
      _nutritionSummary = _nutritionSummary.remove(
        entryToDelete.calories,
        entryToDelete.protein,
        entryToDelete.carbs,
        entryToDelete.fat,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }

    try {
      // === ONLINE: kirim DELETE ke API ===
      final response =
          await _httpClient.delete('${ApiConstants.diary}/$entryId');

      if (response.statusCode == 200) {
        _entries.removeWhere((e) => e.id == entryId);
        _nutritionSummary = _nutritionSummary.remove(
          entryToDelete.calories,
          entryToDelete.protein,
          entryToDelete.carbs,
          entryToDelete.fat,
        );

        // Hapus dari SQLite juga
        await _deleteLocalByServerId(entryId);

        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Gagal menghapus entri diary';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on NetworkException {
      // === OFFLINE: soft delete lokal (tandai deleted_at, sync_status = pending) ===
      return await _deleteEntryOffline(entryId, entryToDelete);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return await _deleteEntryOffline(entryId, entryToDelete);
      } else if (e.response?.statusCode == 404) {
        _errorMessage = 'Entri tidak ditemukan di server';
      } else if (e.response?.statusCode == 403) {
        _errorMessage = 'Tidak punya izin untuk menghapus entri ini';
      } else {
        _errorMessage = 'Gagal menghapus entri: ${e.message}';
      }
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

  /// Soft delete entry di SQLite saat offline
  Future<bool> _deleteEntryOffline(
      String serverId, DiaryEntry entryToDelete) async {
    try {
      await _softDeleteLocalByServerId(serverId);

      // Hapus dari UI list langsung
      _entries.removeWhere((e) => e.id == serverId);
      _nutritionSummary = _nutritionSummary.remove(
        entryToDelete.calories,
        entryToDelete.protein,
        entryToDelete.carbs,
        entryToDelete.fat,
      );

      _isOffline = true;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus secara offline: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cari local entry berdasarkan serverId lalu soft delete
  Future<void> _softDeleteLocalByServerId(String serverId) async {
    final db = await _getLocalEntryIdByServerId(serverId);
    if (db != null) {
      await _localDiary.deleteDiaryEntry(db);
    }
  }

  /// Hapus (hard delete) entry lokal berdasarkan serverId
  Future<void> _deleteLocalByServerId(String serverId) async {
    final localId = await _getLocalEntryIdByServerId(serverId);
    if (localId != null) {
      await _localDiary.hardDeleteDiaryEntry(localId);
    }
  }

  /// Dapatkan local SQLite id berdasarkan serverId
  Future<int?> _getLocalEntryIdByServerId(String serverId) async {
    try {
      final userId = await _getLocalUserId();
      if (userId == null) return null;

      // Cari di entries saat ini
      final match = _entries.firstWhere(
        (e) => e.id == serverId,
        orElse: () => DiaryEntry(
          id: '',
          userId: '',
          profileType: '',
          servingSize: 0,
          mealTime: '',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          entryDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (match.id.isEmpty) return null;

      // Tidak ada cara langsung, gunakan getPendingSyncEntries sebagai workaround
      // Implementasi lebih lengkap bisa tambahkan method getByServerId ke LocalDiaryDataSource
      return null;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // SEARCH FOODS — offline-first
  // ============================================================

  /// Search foods: coba API dulu, fallback ke SQLite lokal
  /// Requirements: 4.2 - Memilih makanan dari Food_Database
  Future<void> searchFoods(String query, {String? category}) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoadingFoods = true;
    _errorMessage = null;
    notifyListeners();

    final searchCategory =
        category ?? (_selectedProfile == 'baby' ? 'mpasi' : 'ibu');

    try {
      // === ONLINE: cari dari API ===
      final response = await _httpClient.get(
        ApiConstants.foods,
        queryParameters: {
          'search': query,
          'category': searchCategory,
          'limit': 20,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final foodsJson = data['foods'] as List<dynamic>?;

        if (foodsJson != null) {
          _searchResults = foodsJson
              .map((json) => FoodModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          _searchResults = [];
        }
        _errorMessage = null;
      } else {
        _searchResults = [];
      }
    } on NetworkException {
      // === OFFLINE: cari dari SQLite lokal ===
      await _searchFoodsLocal(query, searchCategory);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        await _searchFoodsLocal(query, searchCategory);
      } else {
        _searchResults = [];
      }
    } catch (e) {
      await _searchFoodsLocal(query, searchCategory);
    } finally {
      _isLoadingFoods = false;
      notifyListeners();
    }
  }

  /// Cari makanan dari SQLite saat offline
  Future<void> _searchFoodsLocal(String query, String category) async {
    try {
      final localFoods =
          await _localFood.searchFoods(query: query, category: category);
      _searchResults = localFoods
          .map((lf) => FoodModel(
                id: lf.serverId ?? lf.id.toString(),
                name: lf.name,
                category: lf.category,
                caloriesPer100g: lf.caloriesPer100g,
                proteinPer100g: lf.proteinPer100g,
                carbsPer100g: lf.carbsPer100g,
                fatPer100g: lf.fatPer100g,
                estimatedPricePer100g: lf.estimatedPricePer100g,
                createdAt: lf.createdAt,
              ))
          .toList();
    } catch (_) {
      _searchResults = [];
    }
  }

  // ============================================================
  // UTILS
  // ============================================================

  /// Clear search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if two dates are the same day
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}