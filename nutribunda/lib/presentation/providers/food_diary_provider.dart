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
import '../../data/models/local/local_food_model.dart';
import '../../data/models/nutrition_summary.dart';
import '../../data/models/food_model.dart';

/// Provider untuk mengelola state Food Diary
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
/// Offline-first: selalu baca dari SQLite lokal, sync ke server saat online
/// Custom food: input manual disimpan ke food database agar bisa dicari kembali
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
  /// Requirements: 4.4
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
  // HELPERS
  // ============================================================

  Future<int?> _getLocalUserId() async {
    final userIdStr = await _secureStorage.getUserId();
    if (userIdStr == null) return null;
    return int.tryParse(userIdStr);
  }

  DiaryEntry _localToRemote(LocalDiaryEntry local) {
    return DiaryEntry(
      id: local.serverId ?? local.id.toString(),
      userId: local.userId.toString(),
      profileType: local.profileType,
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

  NutritionSummary _calculateSummary(List<DiaryEntry> entries) {
    double cal = 0, pro = 0, carb = 0, fat = 0;
    for (final e in entries) {
      cal += e.calories;
      pro += e.protein;
      carb += e.carbs;
      fat += e.fat;
    }
    return NutritionSummary(calories: cal, protein: pro, carbs: carb, fat: fat);
  }

  bool _isConnectionError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;

  // ============================================================
  // LOAD ENTRIES — offline-first
  // ============================================================

  Future<void> loadEntries() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dateStr = _formatDate(_selectedDate);
      final response = await _httpClient.get(
        ApiConstants.diary,
        queryParameters: {'profile': _selectedProfile, 'date': dateStr},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final entriesJson = data['entries'] as List<dynamic>?;
        _entries = entriesJson != null
            ? entriesJson
                .map((j) => DiaryEntry.fromJson(j as Map<String, dynamic>))
                .toList()
            : [];

        final summaryJson = data['nutrition_summary'] as Map<String, dynamic>?;
        _nutritionSummary = summaryJson != null
            ? NutritionSummary.fromJson(summaryJson)
            : _calculateSummary(_entries);

        _isOffline = false;
        _errorMessage = null;

        // Cache ke SQLite untuk akses offline berikutnya
        await _cacheEntriesToLocal(_entries);
      } else {
        _errorMessage = 'Gagal memuat data diary';
        _entries = [];
        _nutritionSummary = const NutritionSummary();
      }
    } on NetworkException {
      await _loadFromLocal();
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        await _loadFromLocal();
      } else if (e.response?.statusCode == 401) {
        _errorMessage = 'Sesi habis. Silakan login ulang.';
        _entries = [];
        _nutritionSummary = const NutritionSummary();
      } else {
        await _loadFromLocal();
      }
    } catch (_) {
      await _loadFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Tidak ada koneksi dan data lokal tidak tersedia.';
      _entries = [];
      _nutritionSummary = const NutritionSummary();
    }
  }

  Future<void> _cacheEntriesToLocal(List<DiaryEntry> serverEntries) async {
    try {
      final userId = await _getLocalUserId();
      if (userId == null) return;
      for (final entry in serverEntries) {
        await _localDiary.insertOrUpdateFromServer(LocalDiaryEntry(
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
        ));
      }
    } catch (_) {}
  }

  // ============================================================
  // SAVE CUSTOM FOOD — inti fitur baru
  // ============================================================

  /// Simpan custom food ke server food database (POST /api/foods)
  /// Kalau berhasil, return FoodModel dengan server ID
  /// Kalau gagal/offline, return null
  Future<FoodModel?> _saveCustomFoodToServer({
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double? estimatedPricePer100g,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConstants.foods,
        data: {
          'name': name,
          'category': category,
          'calories_per_100g': calories,
          'protein_per_100g': protein,
          'carbs_per_100g': carbs,
          'fat_per_100g': fat,
          if (estimatedPricePer100g != null)
            'estimated_price_per_100g': estimatedPricePer100g,
        },
      );

      // 201 = baru dibuat, 200 = sudah ada (server kembalikan yang existing)
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.data != null) {
        return FoodModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Simpan custom food ke SQLite lokal
  /// Return: serverId (kalau ada) atau 'local_food_{id}' (kalau offline)
  Future<String?> _saveCustomFoodToLocal({
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double? estimatedPricePer100g,
    String? serverId,
    String syncStatus = 'pending',
  }) async {
    try {
      final localFood = LocalFoodModel(
        serverId: serverId,
        name: name,
        category: category,
        caloriesPer100g: calories,
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
        estimatedPricePer100g: estimatedPricePer100g,
        createdAt: DateTime.now(),
        syncStatus: syncStatus,
      );
      final localId = await _localFood.insertFood(localFood);
      return serverId ?? 'local_food_$localId';
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ADD ENTRY — offline-first + simpan custom food ke database
  // ============================================================

  /// Add new diary entry
  /// Requirements: 4.2, 4.3
  ///
  /// Alur untuk input manual (customFoodName != null):
  ///   Step 1 → Simpan ke food database (server atau SQLite lokal)
  ///   Step 2 → Buat diary entry menggunakan food ID yang didapat
  ///
  /// Hasilnya: makanan yang pernah diinput manual bisa dicari kembali
  /// melalui searchFoods() di sesi berikutnya.
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
    double? estimatedPricePer100g, 
  }) async {
    // --- Validasi input ---
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

    // Category makanan mengikuti profile
    final foodCategory = profileType == 'baby' ? 'mpasi' : 'ibu';
    String? resolvedFoodId = foodId;

    if (customFoodName != null) {
      // Coba simpan ke server dulu
      final savedFood = await _saveCustomFoodToServer(
        name: customFoodName,
        category: foodCategory,
        calories: calories!,
        protein: protein!,
        carbs: carbs!,
        fat: fat!,
        estimatedPricePer100g: estimatedPricePer100g,
      );

      if (savedFood != null) {
        // Online: dapat server ID, cache ke SQLite juga
        resolvedFoodId = savedFood.id;
        await _saveCustomFoodToLocal(
          name: customFoodName,
          category: foodCategory,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          estimatedPricePer100g: estimatedPricePer100g,
          serverId: savedFood.id,
          syncStatus: 'synced',
        );
      } else {
        // Offline: simpan lokal dengan status pending untuk di-sync nanti
        resolvedFoodId = await _saveCustomFoodToLocal(
          name: customFoodName,
          category: foodCategory,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          estimatedPricePer100g: estimatedPricePer100g,
          syncStatus: 'pending',
        );
      }
    }

    // ----------------------------------------------------------------
    // STEP 2: Buat diary entry
    // ----------------------------------------------------------------
    try {
      final Map<String, dynamic> requestData = {
        'profile_type': profileType,
        'serving_size': servingSize,
        'meal_time': mealTime,
        'entry_date': _formatDate(entryDate),
      };

      // Kalau dapat server food ID (UUID), pakai food_id
      // Kalau masih local_ (offline), kirim sebagai custom_food_name
      final isLocalFoodId =
          resolvedFoodId == null || resolvedFoodId.startsWith('local_');

      if (!isLocalFoodId) {
        requestData['food_id'] = resolvedFoodId;
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
      return await _addEntryOffline(
        profileType: profileType,
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
      if (_isConnectionError(e)) {
        return await _addEntryOffline(
          profileType: profileType,
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

  Future<bool> _addEntryOffline({
    required String profileType,
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
      final localId = await _localDiary.insertDiaryEntry(LocalDiaryEntry(
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
        syncStatus: 'pending',
      ));

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
        _nutritionSummary =
            _nutritionSummary.add(calories, protein, carbs, fat);
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

  Future<void> _saveSingleEntryLocal(DiaryEntry entry,
      {String syncStatus = 'synced'}) async {
    try {
      final userId = await _getLocalUserId();
      if (userId == null) return;
      await _localDiary.insertOrUpdateFromServer(LocalDiaryEntry(
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
      ));
    } catch (_) {}
  }

  // ============================================================
  // DELETE ENTRY
  // ============================================================

  /// Delete diary entry
  /// Requirements: 4.5
  Future<bool> deleteEntry(String entryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    DiaryEntry? entryToDelete;
    try {
      entryToDelete = _entries.firstWhere((e) => e.id == entryId);
    } catch (_) {
      _errorMessage = 'Entri tidak ditemukan';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Entry lokal yang belum pernah ke server → langsung hard delete
    if (entryId.startsWith('local_')) {
      final localId = int.tryParse(entryId.replaceFirst('local_', ''));
      if (localId != null) await _localDiary.hardDeleteDiaryEntry(localId);
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
      return await _deleteEntryOffline(entryId, entryToDelete);
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
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

  Future<bool> _deleteEntryOffline(
      String serverId, DiaryEntry entryToDelete) async {
    try {
      await _softDeleteLocalByServerId(serverId);
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

  Future<void> _softDeleteLocalByServerId(String serverId) async {
    try {
      final pending = await _localDiary.getPendingSyncEntries();
      final match = pending.where((e) => e.serverId == serverId).toList();
      if (match.isNotEmpty) {
        await _localDiary.deleteDiaryEntry(match.first.id!);
      }
    } catch (_) {}
  }

  // ============================================================
  // SEARCH FOODS — termasuk custom foods yang pernah diinput
  // ============================================================

  /// Search foods: coba API dulu, fallback ke SQLite lokal
  /// Hasil pencarian MENCAKUP makanan custom yang pernah diinput manual
  /// karena sudah disimpan ke tabel foods (bukan hanya diary_entries)
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
        _searchResults = foodsJson != null
            ? foodsJson
                .map((j) => FoodModel.fromJson(j as Map<String, dynamic>))
                .toList()
            : [];
        _errorMessage = null;
      } else {
        _searchResults = [];
      }
    } on NetworkException {
      await _searchFoodsLocal(query, searchCategory);
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        await _searchFoodsLocal(query, searchCategory);
      } else {
        _searchResults = [];
      }
    } catch (_) {
      await _searchFoodsLocal(query, searchCategory);
    } finally {
      _isLoadingFoods = false;
      notifyListeners();
    }
  }

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

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}