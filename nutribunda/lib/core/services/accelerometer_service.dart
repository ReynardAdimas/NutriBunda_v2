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
  static const double shakeThreshold = 20.0; // m/s² (tanpa gravitasi)
  static const int shakeCooldownMs = 3000;   // 3 detik cooldown
  static const int shakeWindowMs = 500;      // jendela waktu deteksi shake

  bool _isListening = false;
  bool _sensorAvailable = true; // FIX: tambah flag ketersediaan sensor
  String? _errorMessage;

  // FIX: Track waktu pertama kali threshold terlampaui dalam satu window
  DateTime? _firstThresholdTime;

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
      _subscription = userAccelerometerEventStream().listen(
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
      _sensorAvailable = false; // FIX: tangkap jika sensor tidak ada
      debugPrint('AccelerometerService: Exception - $e');
    }
  }

  /// FIX: Pendekatan baru — deteksi shake berdasarkan "puncak dalam jendela waktu"
  /// Jika dalam shakeWindowMs ada setidaknya satu puncak di atas threshold → shake
  /// Requirements: 6.2 - Deteksi shake dengan threshold 20 m/s² dalam window 500ms
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
        // Catat waktu pertama kali threshold terlampaui
        _firstThresholdTime = now;
        debugPrint(
          'AccelerometerService: Threshold exceeded '
          '(acceleration: ${acceleration.toStringAsFixed(2)} m/s²)',
        );
      }

      // Cek apakah masih dalam jendela waktu yang valid
      final int elapsed = now.difference(_firstThresholdTime!).inMilliseconds;

      if (elapsed <= shakeWindowMs) {
        // Masih dalam window — cek cooldown lalu trigger
        if (_lastShakeTime == null ||
            now.difference(_lastShakeTime!).inMilliseconds > shakeCooldownMs) {
          _lastShakeTime = now;
          _firstThresholdTime = null; // reset untuk shake berikutnya
          _errorMessage = null;

          debugPrint(
            'AccelerometerService: Shake detected! '
            '(elapsed: ${elapsed}ms, acceleration: ${acceleration.toStringAsFixed(2)} m/s²)',
          );

          onShakeDetected();
        } else {
          final int timeSinceLastShake =
              now.difference(_lastShakeTime!).inMilliseconds;
          debugPrint(
            'AccelerometerService: Shake ignored — cooldown '
            '($timeSinceLastShake ms < $shakeCooldownMs ms)',
          );
          _firstThresholdTime = null;
        }
      } else {
        // Lewat window tapi threshold masih terlampaui — mulai window baru
        _firstThresholdTime = now;
      }
    } else {
      // Di bawah threshold — reset window jika sudah kedaluwarsa
      if (_firstThresholdTime != null) {
        final int elapsed = now.difference(_firstThresholdTime!).inMilliseconds;
        if (elapsed > shakeWindowMs) {
          debugPrint(
            'AccelerometerService: Window expired without valid shake '
            '(${elapsed}ms)',
          );
          _firstThresholdTime = null;
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