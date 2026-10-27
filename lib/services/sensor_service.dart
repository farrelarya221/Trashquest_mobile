import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Sensor fusion service combining Accelerometer + Gyroscope
/// for responsive and smoothed tilt steering in the Trash Sorter mini-game.
class SensorService {
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Smoothed tilt value (-1.0 to 1.0)
  double _filteredTilt = 0.0;
  double get currentTilt => _filteredTilt;

  // Sensor availability flags
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  // Callback to notify game loop
  Function(double tilt)? onTiltUpdate;

  // Filter constants (low-pass smoothing + gyro angular velocity fusion)
  static const double _alpha = 0.22; // Low-pass filter factor
  static const double _gyroWeight = 0.08; // Gyro rate contribution
  static const double _accelSensitivity = 0.25; // Scale raw m/s^2 into normalized range

  /// Start listening to accelerometer & gyroscope streams
  void startListening({required Function(double tilt) onUpdate}) {
    onTiltUpdate = onUpdate;
    _filteredTilt = 0.0;

    try {
      _accelSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _isAvailable = true;
          // Device held in portrait: x-axis measures lateral tilt (negative right, positive left)
          // Invert or normalize so tilting right produces positive value
          final rawTilt = (-event.x * _accelSensitivity).clamp(-1.0, 1.0);
          _filteredTilt = (_alpha * rawTilt) + ((1.0 - _alpha) * _filteredTilt);
          onTiltUpdate?.call(_filteredTilt);
        },
        onError: (err) {
          debugPrint('Accelerometer stream error: $err');
          _isAvailable = false;
        },
        cancelOnError: false,
      );

      _gyroSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          // Gyroscope y-axis rotation rate complements lateral tilt velocity
          final gyroDelta = (event.y * _gyroWeight).clamp(-0.2, 0.2);
          _filteredTilt = (_filteredTilt + gyroDelta).clamp(-1.0, 1.0);
        },
        onError: (err) {
          debugPrint('Gyroscope stream error: $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Sensor initialization failed: $e');
      _isAvailable = false;
    }
  }

  /// Manually inject tilt (used as fallback for mouse, touch drag, or emulator controls)
  void setManualTilt(double tilt) {
    _filteredTilt = tilt.clamp(-1.0, 1.0);
    onTiltUpdate?.call(_filteredTilt);
  }

  /// Cleanly pause or cancel stream subscriptions to preserve battery and resources
  void stopListening() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    onTiltUpdate = null;
    _filteredTilt = 0.0;
  }
}
