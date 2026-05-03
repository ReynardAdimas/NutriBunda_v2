import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola step counting menggunakan pedometer
/// Requirements: 5.6, 5.7
class PedometerService {
  StreamSubscription<StepCount>? _subscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  
  int _initialSteps = 0;
  int _currentSteps = 0;
  String _pedestrianStatus = 'unknown';
  String? _errorMessage;
  
  bool _isListening = false;
  bool _initialStepsSet = false; // FIX: flag terpisah, tidak bergantung nilai 0
  
  // Getters
  int get currentSteps => _currentSteps;
  int get initialSteps => _initialSteps;
  String get pedestrianStatus => _pedestrianStatus;
  String? get errorMessage => _errorMessage;
  bool get isListening => _isListening;
  
  /// Start listening to step count updates
  /// Requirements: 5.6 - Menghitung langkah kaki secara real-time
  void startListening(Function(int steps) onStepUpdate) {
    if (_isListening) {
      debugPrint('PedometerService: Already listening');
      return;
    }
    
    try {
      // Listen to step count stream
      _subscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          // FIX: Gunakan flag boolean, bukan cek nilai == 0
          if (!_initialStepsSet) {
            _initialSteps = event.steps;
            _initialStepsSet = true;
            debugPrint('PedometerService: Initial steps set to ${event.steps}');
          }
          
          // Calculate current steps relative to initial
          _currentSteps = event.steps - _initialSteps;
          
          // Ensure steps don't go negative (can happen on device restart)
          if (_currentSteps < 0) {
            _initialSteps = event.steps;
            _currentSteps = 0;
          }
          
          debugPrint('PedometerService: Steps updated to $_currentSteps (total: ${event.steps})');
          
          // Notify callback
          onStepUpdate(_currentSteps);
          
          // Clear any previous error
          _errorMessage = null;
        },
        onError: (error) {
          _errorMessage = _handleError(error);
          debugPrint('PedometerService: Error - $_errorMessage');
          
          // Still notify with current steps on error
          onStepUpdate(_currentSteps);
        },
        cancelOnError: false,
      );
      
      // Listen to pedestrian status (walking, stopped, unknown)
      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
        (PedestrianStatus event) {
          _pedestrianStatus = event.status;
          debugPrint('PedometerService: Status changed to $_pedestrianStatus');
        },
        onError: (error) {
          debugPrint('PedometerService: Status error - $error');
        },
        cancelOnError: false,
      );
      
      _isListening = true;
      debugPrint('PedometerService: Started listening');
    } catch (e) {
      _errorMessage = 'Failed to start pedometer: $e';
      debugPrint('PedometerService: Exception - $_errorMessage');
    }
  }
  
  /// Stop listening to step count updates
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    
    _statusSubscription?.cancel();
    _statusSubscription = null;
    
    _isListening = false;
    _initialStepsSet = false; // FIX: reset flag saat berhenti
    debugPrint('PedometerService: Stopped listening');
  }
  
  /// Reset daily steps counter
  /// This should be called at midnight or when user manually resets
  /// Requirements: 5.6 - Reset harian untuk tracking per hari
  void resetDailySteps() {
    // Move current total to initial, effectively resetting current to 0
    _initialSteps = _currentSteps + _initialSteps;
    _currentSteps = 0;
    _initialStepsSet = false; // FIX: reset flag agar baseline diperbarui di event berikutnya
    debugPrint('PedometerService: Daily steps reset (new baseline: $_initialSteps)');
  }
  
  /// Manually set step count (useful for testing or manual adjustment)
  void setSteps(int steps) {
    _currentSteps = steps;
    debugPrint('PedometerService: Steps manually set to $steps');
  }
  
  /// Handle pedometer errors and return user-friendly message
  String _handleError(dynamic error) {
    final errorString = error.toString();
    
    if (errorString.contains('not available') || errorString.contains('Pedometer not available')) {
      return 'Sensor pedometer tidak tersedia di perangkat ini';
    } else if (errorString.contains('Step count not available')) {
      return 'Data langkah kaki tidak tersedia';
    } else if (errorString.contains('Permission denied') || errorString.contains('permission')) {
      return 'Izin akses sensor ditolak. Mohon aktifkan di pengaturan';
    } else {
      return 'Error pedometer: $error';
    }
  }
  
  /// Dispose and clean up resources
  void dispose() {
    stopListening();
    debugPrint('PedometerService: Disposed');
  }
}