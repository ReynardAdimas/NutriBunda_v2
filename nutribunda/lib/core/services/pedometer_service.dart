import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola step counting menggunakan pedometer.
/// Mode: Always-on seperti smartwatch — tidak ada tombol mulai/berhenti.
///
/// Notifikasi TIDAK diurus di sini. Service ini memanggil callback
/// [onMilestoneReached] setiap kali langkah mencapai kelipatan 100,
/// sehingga caller (DietPlanProvider) yang memutuskan cara menampilkan notifikasi
/// menggunakan NotificationService yang sudah ada di app.
///
/// Requirements: 5.6, 5.7
class PedometerService {
  StreamSubscription<StepCount>? _subscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  Timer? _midnightResetTimer;
  Timer? _sensorCheckTimer; // Deteksi jika sensor tidak memancarkan event

  int _initialSteps = 0;
  int _currentSteps = 0;
  int _savedSteps = 0;
  String _pedestrianStatus = 'unknown';
  String? _errorMessage;

  bool _isListening = false;
  bool _initialStepsSet = false;

  // Milestone terakhir yang sudah dinotifikasi (untuk cegah duplikat)
  int _lastNotifiedMilestone = 0;

  // Getters
  int get currentSteps => _currentSteps;
  int get initialSteps => _initialSteps;
  String get pedestrianStatus => _pedestrianStatus;
  String? get errorMessage => _errorMessage;
  bool get isListening => _isListening;

  /// Mulai listening — dipanggil sekali saat app pertama kali launch.
  ///
  /// [onStepUpdate] dipanggil setiap kali jumlah langkah berubah.
  /// [onMilestoneReached] dipanggil setiap kali langkah mencapai kelipatan 100
  ///   baru — caller yang memutuskan cara menampilkan notifikasi.
  /// [savedDailySteps] adalah langkah yang sudah tersimpan di DB hari ini,
  ///   dipakai sebagai baseline agar tidak mulai dari 0 setelah app restart.
  ///
  /// Requirements: 5.6 - Menghitung langkah kaki secara real-time
  void startListening(
    void Function(int steps) onStepUpdate, {
    int savedDailySteps = 0,
    void Function(int milestone)? onMilestoneReached,
  }) {
    if (_isListening) {
      debugPrint('PedometerService: Already listening');
      return;
    }

    _savedSteps = savedDailySteps;
    _lastNotifiedMilestone = (savedDailySteps ~/ 100) * 100;

    try {
      _subscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          // Batalkan timer diagnostik — sensor sudah terbukti berfungsi
          _sensorCheckTimer?.cancel();
          _sensorCheckTimer = null;

          if (!_initialStepsSet) {
            _initialSteps = event.steps;
            _initialStepsSet = true;
            debugPrint(
                'PedometerService: Initial steps set to ${event.steps}');
          }

          _currentSteps = (event.steps - _initialSteps) + _savedSteps;

          // Jaga agar tidak negatif (bisa terjadi kalau device restart)
          if (_currentSteps < 0) {
            _initialSteps = event.steps;
            _currentSteps = _savedSteps;
          }

          debugPrint(
              'PedometerService: Steps updated to $_currentSteps (raw: ${event.steps})');

          onStepUpdate(_currentSteps);
          _errorMessage = null;

          // Cek milestone dan panggil callback jika ada
          _checkMilestone(_currentSteps, onMilestoneReached);
        },
        onError: (error) {
          _errorMessage = _handleError(error);
          debugPrint('PedometerService: Error - $_errorMessage');
          onStepUpdate(_currentSteps);
        },
        cancelOnError: false,
      );

      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
        (PedestrianStatus event) {
          _pedestrianStatus = event.status;
          debugPrint(
              'PedometerService: Status changed to $_pedestrianStatus');
        },
        onError: (error) {
          debugPrint('PedometerService: Status error - $error');
        },
        cancelOnError: false,
      );

      _isListening = true;

      // Jadwalkan reset otomatis saat tengah malam
      _scheduleMidnightReset(onStepUpdate, onMilestoneReached);

      // Pasang timer diagnostik: jika dalam 8 detik tidak ada event sama sekali,
      // kemungkinan sensor tidak tersedia atau permission runtime belum efektif.
      // Ini TIDAK menghentikan pedometer — hanya melaporkan via errorMessage
      // agar UI bisa menampilkan pesan yang berguna kepada user.
      _sensorCheckTimer = Timer(const Duration(seconds: 8), () {
        if (!_initialStepsSet && _isListening) {
          _errorMessage =
              'Sensor langkah belum merespon. Coba berjalan beberapa langkah '
              'atau periksa izin "Aktivitas Fisik" di pengaturan.';
          debugPrint('PedometerService: No step events received after 8s');
          onStepUpdate(_currentSteps); // trigger UI rebuild agar error muncul
        }
      });

      debugPrint('PedometerService: Started listening (always-on mode)');
    } catch (e) {
      _errorMessage = 'Gagal memulai pedometer: $e';
      debugPrint('PedometerService: Exception - $_errorMessage');
    }
  }

  /// Cek apakah langkah mencapai milestone kelipatan 100 yang baru
  void _checkMilestone(
    int steps,
    void Function(int milestone)? onMilestoneReached,
  ) {
    if (steps < 100 || onMilestoneReached == null) return;

    final milestone = (steps ~/ 100) * 100;
    if (milestone > _lastNotifiedMilestone) {
      _lastNotifiedMilestone = milestone;
      onMilestoneReached(milestone);
      debugPrint('PedometerService: Milestone reached: $milestone steps');
    }
  }

  /// Jadwalkan timer reset otomatis saat tengah malam
  void _scheduleMidnightReset(
    void Function(int steps) onStepUpdate,
    void Function(int milestone)? onMilestoneReached,
  ) {
    _midnightResetTimer?.cancel();

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final duration = midnight.difference(now);

    debugPrint(
        'PedometerService: Midnight reset scheduled in ${duration.inMinutes} menit');

    _midnightResetTimer = Timer(duration, () {
      _performDailyReset(onStepUpdate, onMilestoneReached);
    });
  }

  /// Reset harian — dipanggil otomatis oleh timer tengah malam
  /// Requirements: 5.6 - Reset harian untuk tracking per hari
  void _performDailyReset(
    void Function(int steps) onStepUpdate,
    void Function(int milestone)? onMilestoneReached,
  ) {
    debugPrint('PedometerService: Midnight — performing daily reset');

    _savedSteps = 0;
    _lastNotifiedMilestone = 0;
    _initialStepsSet = false;
    _currentSteps = 0;

    onStepUpdate(0);

    // Jadwalkan lagi untuk tengah malam berikutnya
    _scheduleMidnightReset(onStepUpdate, onMilestoneReached);
  }

  /// Reset manual langkah harian — dipakai saat app di-launch di hari baru
  void resetDailySteps() {
    _savedSteps = 0;
    _lastNotifiedMilestone = 0;
    _initialStepsSet = false;
    _currentSteps = 0;
    debugPrint('PedometerService: Daily steps reset manually');
  }

  /// Stop listening — hanya dipanggil saat dispose
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _midnightResetTimer?.cancel();
    _midnightResetTimer = null;
    _sensorCheckTimer?.cancel();
    _sensorCheckTimer = null;
    _isListening = false;
    _initialStepsSet = false;
    debugPrint('PedometerService: Stopped listening');
  }

  /// Set langkah secara manual (untuk sinkronisasi DB setelah load)
  void setSteps(int steps) {
    _currentSteps = steps;
    _savedSteps = steps;
    _lastNotifiedMilestone = (steps ~/ 100) * 100;
    debugPrint('PedometerService: Steps manually set to $steps');
  }

  String _handleError(dynamic error) {
    final errorString = error.toString();
    if (errorString.contains('not available') ||
        errorString.contains('Pedometer not available')) {
      return 'Sensor pedometer tidak tersedia di perangkat ini';
    } else if (errorString.contains('Step count not available')) {
      return 'Data langkah kaki tidak tersedia';
    } else if (errorString.contains('Permission denied') ||
        errorString.contains('permission')) {
      return 'Izin akses sensor ditolak. Mohon aktifkan di pengaturan';
    } else {
      return 'Error pedometer: $error';
    }
  }

  void dispose() {
    stopListening();
    debugPrint('PedometerService: Disposed');
  }
}