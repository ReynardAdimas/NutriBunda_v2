import 'package:nutribunda/data/datasources/local/local_steps_datasource.dart';

import 'base_provider.dart';
import '../../data/models/user_model.dart';
import '../../core/services/pedometer_service.dart';

/// Provider untuk mengelola Diet Plan dengan kalkulasi BMR/TDEE
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7
class DietPlanProvider extends BaseProvider {
  // BMR, TDEE, dan Target Calories
  double? _bmr;
  double? _tdee;
  double? _targetCalories;
  
  // Step tracking
  int _steps = 0;
  double _caloriesBurned = 0;
  
  // User data untuk kalkulasi
  UserModel? _user;

  final LocalStepsDatasource _localStepsDatasource;
  int? _currentUserId; 

  DietPlanProvider(this._localStepsDatasource);

  DateTime? _lastTrackedDate;
  
  // Pedometer service
  final PedometerService _pedometerService = PedometerService();
  
  // Activity level factors
  static const Map<String, double> _activityFactors = {
    'sedentary': 1.2,
    'lightly_active': 1.375,
    'moderately_active': 1.55,
  };
  
  // Breastfeeding calorie addition (using average)
  static const double _breastfeedingCaloriesAvg = 400;
  
  // Safe calorie deficit
  static const double _maxCalorieDeficit = 500;

  // Getters
  double? get bmr => _bmr;
  double? get tdee => _tdee;
  double? get targetCalories => _targetCalories;
  int get steps => _steps;
  double get caloriesBurned => _caloriesBurned;
  UserModel? get user => _user;
  PedometerService get pedometerService => _pedometerService;
  
  /// Check if pedometer is currently active
  bool get isPedometerActive => _pedometerService.isListening;
  
  /// Get pedometer error message if any
  String? get pedometerError => _pedometerService.errorMessage;
  
  /// Check if diet plan can be calculated
  /// Requirements: 5.11 - Validasi data profil sebelum kalkulasi
  bool get canCalculateDietPlan {
    return _user != null &&
        _user!.weight != null &&
        _user!.height != null &&
        _user!.age != null;
  }
  
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  /// Get missing profile data fields
  List<String> get missingProfileData {
    final missing = <String>[];
    if (_user == null) {
      return ['User data not loaded'];
    }
    if (_user!.weight == null) missing.add('Berat badan');
    if (_user!.height == null) missing.add('Tinggi badan');
    if (_user!.age == null) missing.add('Usia');
    return missing;
  }

  /// Set user data and automatically recalculate
  /// Requirements: 5.5 - Recalculate saat user data berubah
  void setUser(UserModel user) {
    final oldUser = _user;
    _user = user;
    
    // Automatically recalculate if data is complete
    if (canCalculateDietPlan) {
      calculateAll();
    } else {
      // Clear calculations if data is incomplete
      _bmr = null;
      _tdee = null;
      _targetCalories = null;
      
      // Only notify if user actually changed
      if (oldUser != user) {
        safeNotifyListeners();
      }
    }
  }

  /// Calculate BMR using Mifflin-St Jeor formula for women
  /// Requirements: 5.1 - BMR = (10 × weight_kg) + (6.25 × height_cm) − (5 × age_years) − 161
  void calculateBMR() {
    if (_user == null || 
        _user!.weight == null || 
        _user!.height == null || 
        _user!.age == null) {
      _bmr = null;
      safeNotifyListeners();
      return;
    }

    final weight = _user!.weight!;
    final height = _user!.height!;
    final age = _user!.age!;

    // Mifflin-St Jeor formula for women
    _bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    
    safeNotifyListeners();
  }

  /// Calculate TDEE by multiplying BMR with activity factor
  /// Requirements: 5.2 - TDEE = BMR × activity_factor
  void calculateTDEE() {
    if (_bmr == null || _user == null) {
      _tdee = null;
      safeNotifyListeners();
      return;
    }

    final activityLevel = _user!.activityLevel;
    final activityFactor = _activityFactors[activityLevel] ?? _activityFactors['sedentary']!;

    _tdee = _bmr! * activityFactor;
    
    safeNotifyListeners();
  }

  /// Calculate target calories with safe deficit and breastfeeding adjustment
  /// Requirements: 5.3 - Target kalori dengan defisit aman maksimal 500 kkal
  /// Requirements: 5.4 - Tambahkan 300-500 kkal saat menyusui
  void calculateTargetCalories() {
    if (_tdee == null || _user == null) {
      _targetCalories = null;
      safeNotifyListeners();
      return;
    }

    // Start with TDEE minus safe deficit
    // Requirements: 5.3 - Defisit maksimal 500 kkal
    double target = _tdee! - _maxCalorieDeficit;

    // Add breastfeeding calories if applicable
    // Requirements: 5.4 - Tambahkan 300-500 kkal saat menyusui
    if (_user!.isBreastfeeding) {
      target += _breastfeedingCaloriesAvg;
    }

    // Ensure target is not below a safe minimum (80% of BMR)
    final minimumSafe = _bmr! * 0.8;
    if (target < minimumSafe) {
      target = minimumSafe;
    }

    _targetCalories = target;
    
    safeNotifyListeners();
  }

  /// Calculate all values (BMR, TDEE, Target Calories)
  /// Requirements: 5.5 - Recalculate semua saat data berubah
  void calculateAll() {
    calculateBMR();
    calculateTDEE();
    calculateTargetCalories();
  }

  /// Update user profile data and recalculate
  /// Requirements: 5.5 - Automatic recalculation saat profil diupdate
  void updateUserProfile({
    double? weight,
    double? height,
    int? age,
    String? activityLevel,
    bool? isBreastfeeding,
  }) {
    if (_user == null) return;

    _user = _user!.copyWith(
      weight: weight ?? _user!.weight,
      height: height ?? _user!.height,
      age: age ?? _user!.age,
      activityLevel: activityLevel ?? _user!.activityLevel,
      isBreastfeeding: isBreastfeeding ?? _user!.isBreastfeeding,
    );

    // Automatically recalculate
    calculateAll();
  }
  
  void _checkAndResetForNewDay() {
    final today = DateTime.now(); 
    final todayDate = DateTime(today.year, today.month, today.day); 

    if(_lastTrackedDate != null && _lastTrackedDate!.isBefore(todayDate)) {
      resetDailySteps();
    }
    _lastTrackedDate = todayDate;
  }
  /// Update steps and calculate calories burned
  /// Requirements: 5.6, 5.7 - Menghitung kalori terbakar dari langkah
  void updateSteps(int steps) {
    _checkAndResetForNewDay();
    _steps = steps;
    
    if (_user == null || _user!.weight == null) {
      _caloriesBurned = 0;
      safeNotifyListeners();
      return;
    }
    
    // Formula: 1 langkah ≈ 0.04 kkal per kg berat badan
    // Requirements: 5.7 - Formula kalori terbakar
    final weight = _user!.weight!;
    _caloriesBurned = steps * 0.04 * weight / 1000;
    
    safeNotifyListeners();

    if (steps %10==0 || steps == 0) {
      _saveTodayStepsLocally();
    }
  }

  Future<void> _saveTodayStepsLocally() async {
    if(_currentUserId == null) return; 

    final today = DateTime.now(); 
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      await _localStepsDatasource.saveOrUpdateDailySteps(
        userId: _currentUserId!, 
        date: dateStr, 
        steps: _steps, 
        caloriesBurned: _caloriesBurned
      );
    } catch (e) {
      throw Exception();
    }
  }

  Future<void> loadTodaySteps() async {
    if(_currentUserId == null) return; 

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      final data = await _localStepsDatasource.getDailySteps(
        userId: _currentUserId!, 
        date: dateStr
      );

      if(data != null) {
        _steps = data['steps'] as int; 
        _caloriesBurned = (data['calories_burned'] as num).toDouble(); 
        safeNotifyListeners();
      }
    } catch (e) {
      throw Exception();
    }
  }

  Future<void> forceSaveSteps() async {
    await _saveTodayStepsLocally();
  }
  
  /// Start pedometer tracking
  /// Requirements: 5.6 - Menghitung langkah kaki secara real-time
  void startPedometerTracking() {
    if (_pedometerService.isListening) {
      return;
    }
    
    _pedometerService.startListening((steps) {
      updateSteps(steps);
    });
  }
  
  /// Stop pedometer tracking
  void stopPedometerTracking() {
    _pedometerService.stopListening();
  }

  /// Reset daily steps (should be called at midnight)
  void resetDailySteps() {
    _steps = 0;
    _caloriesBurned = 0;
    _pedometerService.resetDailySteps();
    safeNotifyListeners();
  }

  /// Get remaining calories (target - consumed + burned)
  /// Requirements: 5.8 - Menampilkan sisa kalori
  double getRemainingCalories(double consumedCalories) {
    if (_targetCalories == null) return 0;
    
    return _targetCalories! - consumedCalories + _caloriesBurned;
  }

  /// Get calorie progress percentage
  /// Requirements: 5.9 - Progress bar kalori
  double getCalorieProgress(double consumedCalories) {
    if (_targetCalories == null || _targetCalories == 0) return 0;
    
    final netCalories = consumedCalories - _caloriesBurned;
    final progress = (netCalories / _targetCalories!) * 100;
    
    // Cap at 150% for display purposes
    return progress.clamp(0, 150);
  }

  /// Get progress color based on percentage
  /// Requirements: 5.9 - Color coding: hijau (0-80%), kuning (81-100%), merah (>100%)
  String getProgressColor(double consumedCalories) {
    final progress = getCalorieProgress(consumedCalories);
    
    if (progress <= 80) {
      return 'green';
    } else if (progress <= 100) {
      return 'yellow';
    } else {
      return 'red';
    }
  }

  /// Check if calories exceeded target
  /// Requirements: 5.10 - Peringatan jika melebihi target
  bool isCaloriesExceeded(double consumedCalories) {
    if (_targetCalories == null) return false;
    
    final netCalories = consumedCalories - _caloriesBurned;
    return netCalories > _targetCalories!;
  }

  /// Get calorie excess amount
  /// Requirements: 5.10 - Menampilkan selisih kalori yang melebihi
  double getCalorieExcess(double consumedCalories) {
    if (_targetCalories == null) return 0;
    
    final netCalories = consumedCalories - _caloriesBurned;
    final excess = netCalories - _targetCalories!;
    
    return excess > 0 ? excess : 0;
  }

  /// Get diet plan summary
  Map<String, dynamic> getDietPlanSummary(double consumedCalories) {
    return {
      'bmr': _bmr,
      'tdee': _tdee,
      'targetCalories': _targetCalories,
      'consumedCalories': consumedCalories,
      'caloriesBurned': _caloriesBurned,
      'remainingCalories': getRemainingCalories(consumedCalories),
      'progressPercentage': getCalorieProgress(consumedCalories),
      'progressColor': getProgressColor(consumedCalories),
      'isExceeded': isCaloriesExceeded(consumedCalories),
      'excessAmount': getCalorieExcess(consumedCalories),
      'steps': _steps,
      'canCalculate': canCalculateDietPlan,
      'missingData': missingProfileData,
    };
  }

  @override
  void resetState() {
    _bmr = null;
    _tdee = null;
    _targetCalories = null;
    _steps = 0;
    _caloriesBurned = 0;
    _user = null;
    _pedometerService.dispose();
    super.resetState();
  }
  
  @override
  void dispose() {
    _pedometerService.dispose();
    super.dispose();
  }
}
