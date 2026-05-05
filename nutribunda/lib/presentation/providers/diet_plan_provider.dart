import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nutribunda/data/datasources/local/local_steps_datasource.dart';
import 'base_provider.dart';
import '../../data/models/user_model.dart';
import '../../core/services/pedometer_service.dart';

/// Provider untuk mengelola Diet Plan dengan kalkulasi BMR/TDEE
/// Pedometer mode: always-on (otomatis menyala, tidak ada start/stop manual)
/// Notifikasi milestone langkah diurus di sini menggunakan flutter_local_notifications
/// yang sudah di-init oleh NotificationService di main app.
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

  // Pedometer service — always-on
  final PedometerService _pedometerService = PedometerService();

  // Notifikasi plugin — menggunakan instance yang sudah ada di app
  // (tidak perlu init ulang, NotificationService sudah menginisialisasinya)
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _stepChannelId = 'pedometer_milestones';
  static const int _stepNotificationId = 9001;

  // Activity level factors
  static const Map<String, double> _activityFactors = {
    'sedentary': 1.2,
    'lightly_active': 1.375,
    'moderately_active': 1.55,
  };

  static const double _breastfeedingCaloriesAvg = 400;
  static const double _maxCalorieDeficit = 500;

  // Getters
  double? get bmr => _bmr;
  double? get tdee => _tdee;
  double? get targetCalories => _targetCalories;
  int get steps => _steps;
  double get caloriesBurned => _caloriesBurned;
  UserModel? get user => _user;
  PedometerService get pedometerService => _pedometerService;

  /// Pedometer selalu aktif — tidak ada state berhenti selain saat error
  bool get isPedometerActive => _pedometerService.isListening;

  /// Get pedometer error message if any
  String? get pedometerError => _pedometerService.errorMessage;

  bool get canCalculateDietPlan {
    return _user != null &&
        _user!.weight != null &&
        _user!.height != null &&
        _user!.age != null;
  }

  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  List<String> get missingProfileData {
    final missing = <String>[];
    if (_user == null) return ['User data not loaded'];
    if (_user!.weight == null) missing.add('Berat badan');
    if (_user!.height == null) missing.add('Tinggi badan');
    if (_user!.age == null) missing.add('Usia');
    return missing;
  }

  void setUser(UserModel user) {
    final oldUser = _user;
    _user = user;

    if (canCalculateDietPlan) {
      calculateAll();
    } else {
      _bmr = null;
      _tdee = null;
      _targetCalories = null;

      if (oldUser != user) {
        safeNotifyListeners();
      }
    }
  }

  /// Calculate BMR using Mifflin-St Jeor formula for women
  /// Requirements: 5.1
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

    _bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    safeNotifyListeners();
  }

  /// Calculate TDEE
  /// Requirements: 5.2
  void calculateTDEE() {
    if (_bmr == null || _user == null) {
      _tdee = null;
      safeNotifyListeners();
      return;
    }

    final activityLevel = _user!.activityLevel;
    final activityFactor =
        _activityFactors[activityLevel] ?? _activityFactors['sedentary']!;

    _tdee = _bmr! * activityFactor;
    safeNotifyListeners();
  }

  /// Calculate target calories
  /// Requirements: 5.3, 5.4
  void calculateTargetCalories() {
    if (_tdee == null || _user == null) {
      _targetCalories = null;
      safeNotifyListeners();
      return;
    }

    double target = _tdee! - _maxCalorieDeficit;

    if (_user!.isBreastfeeding) {
      target += _breastfeedingCaloriesAvg;
    }

    final minimumSafe = _bmr! * 0.8;
    if (target < minimumSafe) {
      target = minimumSafe;
    }

    _targetCalories = target;
    safeNotifyListeners();
  }

  void calculateAll() {
    calculateBMR();
    calculateTDEE();
    calculateTargetCalories();
  }

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

    calculateAll();
  }

  /// Cek apakah hari sudah berganti saat app di-launch, jika iya reset steps
  void _checkAndResetForNewDay() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (_lastTrackedDate != null && _lastTrackedDate!.isBefore(todayDate)) {
      resetDailySteps();
    }
    _lastTrackedDate = todayDate;
  }

  /// Update steps dan hitung kalori
  /// Requirements: 5.6, 5.7
  void updateSteps(int steps) {
    _checkAndResetForNewDay();
    _steps = steps;

    if (_user == null || _user!.weight == null) {
      _caloriesBurned = 0;
      safeNotifyListeners();
      return;
    }

    final weight = _user!.weight!;
    // Formula: 1 langkah ≈ 0.04 kkal per kg berat badan
    // Requirements: 5.7
    _caloriesBurned = steps * 0.04 * weight / 1000;

    safeNotifyListeners();

    // Simpan ke DB setiap 10 langkah
    if (steps % 10 == 0 || steps == 0) {
      _saveTodayStepsLocally();
    }
  }

  /// Kirim notifikasi milestone langkah
  /// Dipanggil dari callback onMilestoneReached di _startPedometerTracking
  Future<void> _sendMilestoneNotification(int milestone) async {
    String title;
    String body;

    if (milestone >= 10000) {
      title = '🏆 $milestone Langkah!';
      body = 'Luar biasa! Kamu sudah mencapai target harian 10.000 langkah!';
    } else if (milestone >= 5000) {
      title = '🔥 $milestone Langkah!';
      body = 'Keren! Sudah separuh jalan menuju 10.000 langkah!';
    } else if (milestone >= 1000) {
      title = '💪 $milestone Langkah!';
      body = 'Tetap semangat! Kamu sudah melewati $milestone langkah hari ini.';
    } else {
      title = '👟 $milestone Langkah!';
      body = 'Bagus! Kamu sudah berjalan $milestone langkah hari ini.';
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _stepChannelId,
      'Pencapaian Langkah',
      channelDescription: 'Notifikasi saat kamu mencapai kelipatan 100 langkah',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: _stepNotificationId,
      title:title,
      body:body,
      notificationDetails: details
    );
  }

  Future<void> _saveTodayStepsLocally() async {
    if (_currentUserId == null) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      await _localStepsDatasource.saveOrUpdateDailySteps(
        userId: _currentUserId!,
        date: dateStr,
        steps: _steps,
        caloriesBurned: _caloriesBurned,
      );
    } catch (e) {
      throw Exception();
    }
  }

  /// Load data langkah hari ini dari lokal DB, lalu langsung jalankan pedometer.
  /// Ini adalah satu-satunya entry point untuk memulai pedometer — otomatis dipanggil
  /// saat screen diet plan dibuka atau saat app pertama kali launch.
  Future<void> loadTodaySteps() async {
    if (_currentUserId == null) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      final data = await _localStepsDatasource.getDailySteps(
        userId: _currentUserId!,
        date: dateStr,
      );

      if (data != null) {
        _steps = data['steps'] as int;
        _caloriesBurned = (data['calories_burned'] as num).toDouble();
        safeNotifyListeners();
      }

      // Selalu jalankan pedometer setelah load — inject data dari DB sebagai baseline
      _startPedometerTracking();
    } catch (e) {
      // Jika DB error, tetap jalankan sensor dari 0
      _startPedometerTracking();
      print('DietPlanProvider: Error loading steps - $e');
    }
  }

  Future<void> forceSaveSteps() async {
    await _saveTodayStepsLocally();
  }

  /// Jalankan pedometer — internal, tidak diekspos ke UI.
  /// UI tidak bisa start/stop pedometer secara manual.
  /// Requirements: 5.6
  void _startPedometerTracking() {
    if (_pedometerService.isListening) return;

    _pedometerService.startListening(
      (steps) => updateSteps(steps),
      savedDailySteps: _steps,
      onMilestoneReached: (milestone) => _sendMilestoneNotification(milestone),
    );
  }

  /// Reset langkah harian — dipanggil otomatis oleh PedometerService saat tengah malam,
  /// atau oleh [_checkAndResetForNewDay] saat app di-launch di hari baru.
  void resetDailySteps() {
    _steps = 0;
    _caloriesBurned = 0;
    _pedometerService.resetDailySteps();
    safeNotifyListeners();
  }

  double getRemainingCalories(double consumedCalories) {
    if (_targetCalories == null) return 0;
    return _targetCalories! - consumedCalories + _caloriesBurned;
  }

  double getCalorieProgress(double consumedCalories) {
    if (_targetCalories == null || _targetCalories == 0) return 0;
    final netCalories = consumedCalories - _caloriesBurned;
    final progress = (netCalories / _targetCalories!) * 100;
    return progress.clamp(0, 150);
  }

  String getProgressColor(double consumedCalories) {
    final progress = getCalorieProgress(consumedCalories);
    if (progress <= 80) return 'green';
    if (progress <= 100) return 'yellow';
    return 'red';
  }

  bool isCaloriesExceeded(double consumedCalories) {
    if (_targetCalories == null) return false;
    final netCalories = consumedCalories - _caloriesBurned;
    return netCalories > _targetCalories!;
  }

  double getCalorieExcess(double consumedCalories) {
    if (_targetCalories == null) return 0;
    final netCalories = consumedCalories - _caloriesBurned;
    final excess = netCalories - _targetCalories!;
    return excess > 0 ? excess : 0;
  }

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