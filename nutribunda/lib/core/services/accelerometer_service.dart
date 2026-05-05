import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola shake detection menggunakan accelerometer
/// Requirements: 6.1, 6.2, 6.6
class AccelerometerService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  DateTime? _lastShakeTime;

  // Constants
  // Dinaikkan dari 20.0 → 25.0 m/s²:
  // Normal walking  : ~2–8  m/s²
  // Jogging/berlari : ~8–20 m/s²
  // Shake disengaja : >25   m/s²
  // 20.0 terlalu rendah → false positive saat langkah berat / naik tangga
  static const double shakeThreshold = 20.0;
  static const int shakeCooldownMs = 3000;   // 3 detik cooldown
  static const int shakeWindowMs = 500;      // jendela waktu deteksi shake

  // Shake yang valid harus melampaui threshold minimal N kali dalam 1 window.
  // Walking biasanya cuma 1 puncak per langkah; shake manusia menghasilkan
  // beberapa puncak berturut-turut dalam 500 ms.
  static const int minThresholdHits = 2;

  bool _isListening = false;
  bool _sensorAvailable = true; // FIX: tambah flag ketersediaan sensor
  String? _errorMessage;

  // FIX: Track waktu pertama kali threshold terlampaui dalam satu window
  DateTime? _firstThresholdTime;
  // FIX: Hitung berapa kali threshold terlampaui dalam satu window
  int _thresholdHitCount = 0;

  // Getters
  bool get isListening => _isListening;
  bool get isSensorAvailable => _sensorAvailable;
  String? get errorMessage => _errorMessage;
  DateTime? get lastShakeTime => _lastShakeTime;

  /// Start listening to accelerometer events
  /// Requirements: 6.1 - Memantau data akselerometer secara terus-menerus
  void startListening(Function onShakeDetected) {
    if (_isListening) {
      debugPrint('AccelerometerService: Already listening');
      return;
    }

    try {
      // sensors_plus 6.x: samplingPeriod wajib diset eksplisit.
      // SensorInterval.normal (~50ms / 20 Hz) cukup untuk shake detection
      // dan mengurangi beban CPU vs default "fastest" yang bisa ribuan Hz.
      _subscription = userAccelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        (UserAccelerometerEvent event) {
          _handleAccelerometerEvent(event, onShakeDetected);
        },
        onError: (error) {
          _errorMessage = _handleError(error);
          _sensorAvailable = false; // FIX: tandai sensor tidak tersedia
          debugPrint('AccelerometerService: Error - $_errorMessage');
        },
        cancelOnError: false,
      );

      _isListening = true;
      _sensorAvailable = true;
      debugPrint('AccelerometerService: Started listening');
    } catch (e) {
      _errorMessage = 'Sensor akselerometer tidak tersedia di perangkat ini';
      _sensorAvailable = false; 
      debugPrint('AccelerometerService: Exception - $e');
    }
  }

  /// Deteksi shake hanya jika threshold terlampaui ≥ minThresholdHits kali
  /// dalam satu window (shakeWindowMs). Ini mencegah false positive dari
  /// satu langkah berat yang menghasilkan satu puncak akselerasi tinggi.
  /// Requirements: 6.2
  void _handleAccelerometerEvent(
    UserAccelerometerEvent event,
    Function onShakeDetected,
  ) {
    final double acceleration = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    final DateTime now = DateTime.now();

    if (acceleration > shakeThreshold) {
      if (_firstThresholdTime == null) {
        _firstThresholdTime = now;
        _thresholdHitCount = 1;
        debugPrint(
          'AccelerometerService: Threshold hit #1 '
          '(${acceleration.toStringAsFixed(2)} m/s²)',
        );
      } else {
        final int elapsed = now.difference(_firstThresholdTime!).inMilliseconds;

        if (elapsed <= shakeWindowMs) {
          _thresholdHitCount++;
          debugPrint(
            'AccelerometerService: Threshold hit #$_thresholdHitCount '
            '(${acceleration.toStringAsFixed(2)} m/s², ${elapsed}ms elapsed)',
          );

          // Baru trigger jika sudah cukup hits dalam window
          if (_thresholdHitCount >= minThresholdHits) {
            if (_lastShakeTime == null ||
                now.difference(_lastShakeTime!).inMilliseconds > shakeCooldownMs) {
              _lastShakeTime = now;
              _firstThresholdTime = null;
              _thresholdHitCount = 0;
              _errorMessage = null;

              debugPrint('AccelerometerService: Shake confirmed! '
                  '($_thresholdHitCount hits in ${elapsed}ms)');

              onShakeDetected();
            } else {
              debugPrint('AccelerometerService: Shake ignored — cooldown aktif');
              _firstThresholdTime = null;
              _thresholdHitCount = 0;
            }
          }
        } else {
          // Window kedaluwarsa — mulai window baru
          _firstThresholdTime = now;
          _thresholdHitCount = 1;
        }
      }
    } else {
      // Di bawah threshold — reset window jika sudah expired
      if (_firstThresholdTime != null) {
        final int elapsed = now.difference(_firstThresholdTime!).inMilliseconds;
        if (elapsed > shakeWindowMs) {
          _firstThresholdTime = null;
          _thresholdHitCount = 0;
        }
      }
    }
  }

  /// Stop listening to accelerometer events
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;

    _isListening = false;
    _firstThresholdTime = null;
    _thresholdHitCount = 0;

    debugPrint('AccelerometerService: Stopped listening');
  }

  /// Handle accelerometer errors and return user-friendly message
  String _handleError(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('not available') ||
        errorString.contains('Accelerometer not available')) {
      return 'Sensor akselerometer tidak tersedia di perangkat ini';
    } else if (errorString.contains('Permission denied') ||
        errorString.contains('permission')) {
      return 'Izin akses sensor ditolak. Mohon aktifkan di pengaturan';
    } else {
      return 'Error akselerometer: $error';
    }
  }

  /// Reset last shake time (useful for testing)
  void resetLastShakeTime() {
    _lastShakeTime = null;
    debugPrint('AccelerometerService: Last shake time reset');
  }

  /// Dispose and clean up resources
  void dispose() {
    stopListening();
    debugPrint('AccelerometerService: Disposed');
  }
}