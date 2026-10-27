import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CompassService {
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  double _currentHeading = 0.0;
  double get currentHeading => _currentHeading;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _hasGyroscope = false;
  bool get hasGyroscope => _hasGyroscope;

  Function(double heading)? onHeadingUpdate;

  DateTime? _lastGyroTimestamp;

  static const double _magBlendWithGyro = 0.08; 
  static const double _magSmoothingNoGyro = 0.15; 

  void startListening({required Function(double heading) onUpdate}) {
    onHeadingUpdate = onUpdate;
    _lastGyroTimestamp = null;

    try {
      _magnetometerSubscription = magnetometerEventStream().listen(
        (MagnetometerEvent event) {
          _isAvailable = true;

          // Compute absolute magnetic heading in degrees [0, 360)
          // In portrait orientation:
          final headingRad = math.atan2(event.x, event.y);
          double rawHeading = (headingRad * 180 / math.pi);
          if (rawHeading < 0) rawHeading += 360;

          if (!_hasGyroscope) {
            // Standalone Magnetometer Low-Pass Filter
            double diff = rawHeading - _currentHeading;
            if (diff > 180) diff -= 360;
            if (diff < -180) diff += 360;

            _currentHeading = (_currentHeading + _magSmoothingNoGyro * diff) % 360;
            if (_currentHeading < 0) _currentHeading += 360;
            onHeadingUpdate?.call(_currentHeading);
          } else {
            // Gyroscope is active: gently nudge current heading towards absolute North
            double diff = rawHeading - _currentHeading;
            if (diff > 180) diff -= 360;
            if (diff < -180) diff += 360;

            _currentHeading = (_currentHeading + _magBlendWithGyro * diff) % 360;
            if (_currentHeading < 0) _currentHeading += 360;
            onHeadingUpdate?.call(_currentHeading);
          }
        },
        onError: (err) {
          debugPrint('Magnetometer stream error: $err');
          _isAvailable = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Magnetometer unavailable: $e');
      _isAvailable = false;
    }

    // 2. Listen to Gyroscope (Instantaneous Angular Velocity / Butter-Smooth Steering)
    try {
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _hasGyroscope = true;
          final now = DateTime.now();

          if (_lastGyroTimestamp != null) {
            final dt = now.difference(_lastGyroTimestamp!).inMicroseconds / 1000000.0;

            // Only integrate reasonable time deltas (prevents jumps after pause)
            if (dt > 0.001 && dt < 0.2) {
              // event.z is yaw rate in radians/second in portrait
              // Clockwise rotation produces negative z, so subtract to increase heading
              final gyroDeltaDeg = -event.z * (180.0 / math.pi) * dt;

              _currentHeading = (_currentHeading + gyroDeltaDeg) % 360;
              if (_currentHeading < 0) _currentHeading += 360;

              onHeadingUpdate?.call(_currentHeading);
            }
          }

          _lastGyroTimestamp = now;
        },
        onError: (err) {
          debugPrint('Gyroscope stream error: $err');
          _hasGyroscope = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Gyroscope unavailable: $e');
      _hasGyroscope = false;
    }
  }

  /// Manually inject heading (fallback for emulator, web, or testing)
  void setManualHeading(double heading) {
    _currentHeading = heading % 360;
    if (_currentHeading < 0) _currentHeading += 360;
    onHeadingUpdate?.call(_currentHeading);
  }

  /// Cleanly pause or cancel stream subscriptions
  void stopListening() {
    _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    onHeadingUpdate = null;
    _lastGyroTimestamp = null;
  }
}
