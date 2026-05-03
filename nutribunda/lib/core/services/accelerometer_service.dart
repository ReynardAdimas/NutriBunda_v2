import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola shake detection menggunakan accelerometer
/// Requirements: 6.1, 6.2, 6.6
class AccelerometerService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  DateTime? _lastShakeTime;
  
  // Constants dari design specification
  static const double shakeThreshold = 20.0; // m/s²
  static const int shakeCooldownMs = 3000; // 3 detik
  static const int shakeDurationMs = 500; // minimal 300ms untuk deteksi shake
  
  bool _isListening = false;
  String? _errorMessage;
  
  // Untuk tracking shake duration
  DateTime? _shakeStartTime;
  bool _isShaking = false;
  
  // Getters
  bool get isListening => _isListening;
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
          debugPrint('AccelerometerService: Error - $_errorMessage');
        },
        cancelOnError: false,
      );
      
      _isListening = true;
      debugPrint('AccelerometerService: Started listening');
    } catch (e) {
      _errorMessage = 'Failed to start accelerometer: $e';
      debugPrint('AccelerometerService: Exception - $_errorMessage');
    }
  }
  
  /// Handle accelerometer event and detect shake
  /// Requirements: 6.2 - Deteksi shake dengan threshold 15 m/s² minimal 300ms
  void _handleAccelerometerEvent(
    UserAccelerometerEvent event,
    Function onShakeDetected,
  ) {
    // Calculate magnitude of acceleration vector: sqrt(x² + y² + z²)
    final double acceleration = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z
    );
    
    final DateTime now = DateTime.now();
    
    // Check if acceleration exceeds threshold
    if (acceleration > shakeThreshold) {
      if (!_isShaking) {
        // Start of shake
        _isShaking = true;
        _shakeStartTime = now;
        debugPrint('AccelerometerService: Shake started (acceleration: ${acceleration.toStringAsFixed(2)} m/s²)');
      } else {
        // Check if shake duration meets minimum requirement
        final int shakeDuration = now.difference(_shakeStartTime!).inMilliseconds;
        
        if (shakeDuration >= shakeDurationMs) {
          // Check cooldown period to prevent repeated triggers
          // Requirements: 6.6 - Debounce 3 detik untuk mencegah pemicu berulang
          if (_lastShakeTime == null || 
              now.difference(_lastShakeTime!).inMilliseconds > shakeCooldownMs) {
            _lastShakeTime = now;
            debugPrint('AccelerometerService: Shake detected! (duration: ${shakeDuration}ms, acceleration: ${acceleration.toStringAsFixed(2)} m/s²)');
            
            // Trigger callback
            onShakeDetected();
            
            // Reset shake state
            _isShaking = false;
            _shakeStartTime = null;
            
            // Clear any previous error
            _errorMessage = null;
          } else {
            // Within cooldown period, ignore
            final int timeSinceLastShake = now.difference(_lastShakeTime!).inMilliseconds;
            debugPrint('AccelerometerService: Shake ignored (cooldown: ${timeSinceLastShake}ms < ${shakeCooldownMs}ms)');
            
            // Reset shake state to avoid continuous detection
            _isShaking = false;
            _shakeStartTime = null;
          }
        }
      }
    } else {
      // Acceleration below threshold, reset shake state
      if (_isShaking) {
        final int shakeDuration = now.difference(_shakeStartTime!).inMilliseconds;
        if (shakeDuration < shakeDurationMs) {
          debugPrint('AccelerometerService: Shake too short (${shakeDuration}ms < ${shakeDurationMs}ms)');
        }
        _isShaking = false;
        _shakeStartTime = null;
      }
    }
  }
  
  /// Stop listening to accelerometer events
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    
    _isListening = false;
    _isShaking = false;
    _shakeStartTime = null;
    
    debugPrint('AccelerometerService: Stopped listening');
  }
  
  /// Handle accelerometer errors and return user-friendly message
  String _handleError(dynamic error) {
    final errorString = error.toString();
    
    if (errorString.contains('not available') || errorString.contains('Accelerometer not available')) {
      return 'Sensor accelerometer tidak tersedia di perangkat ini';
    } else if (errorString.contains('Permission denied') || errorString.contains('permission')) {
      return 'Izin akses sensor ditolak. Mohon aktifkan di pengaturan';
    } else {
      return 'Error accelerometer: $error';
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
