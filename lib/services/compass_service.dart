import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Professional AHRS (Attitude & Heading Reference System) Compass Service.
/// Implements 3D Tilt Compensation (Gravity + Magnetometer TRIAD projection)
/// fused with Gyroscope angular rate dead-reckoning for an ultra-responsive,
/// jitter-free, iPhone-grade navigation experience.
class CompassService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  double _currentHeading = 0.0;
  double get currentHeading => _currentHeading;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _hasGyroscope = false;
  bool get hasGyroscope => _hasGyroscope;
      
  bool _hasAccelerometer = false;
  bool get hasAccelerometer => _hasAccelerometer;

  bool _hasInitialHeading = false;

  // Filtered gravity vector (m/s^2)
  double _gx = 0.0;
  double _gy = 0.0;
  double _gz = 9.81;

  // Device orientation angles (in degrees)
  double _pitch = 0.0;
  double get currentPitch => _pitch;
  double _roll = 0.0;
  double get currentRoll => _roll;

  Function(double heading)? onHeadingUpdate;

  DateTime? _lastGyroTimestamp;

  void startListening({required Function(double heading) onUpdate}) {
    onHeadingUpdate = onUpdate;
    _lastGyroTimestamp = null;
    _hasInitialHeading = false;

    // 1. Listen to Accelerometer for 3D Tilt Compensation (Gravity Vector)
    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _hasAccelerometer = true;
          // Low-pass filter to isolate steady-state gravity from hand vibrations
          _gx = (_gx * 0.85) + (event.x * 0.15);
          _gy = (_gy * 0.85) + (event.y * 0.15);
          _gz = (_gz * 0.85) + (event.z * 0.15);

          final gNorm = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
          if (gNorm > 0.1) {
            // Calculate pitch (tilt forward/backward) & roll (tilt left/right)
            _pitch = math.atan2(-_gy, math.sqrt(_gx * _gx + _gz * _gz)) * (180.0 / math.pi);
            _roll = math.atan2(_gx, _gz) * (180.0 / math.pi);
          }
        },
        onError: (err) {
          debugPrint('Accelerometer stream error: $err');
          _hasAccelerometer = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Accelerometer unavailable: $e');
      _hasAccelerometer = false;
    }

    // 2. Listen to Magnetometer (Geomagnetic Field with 3D Tilt Projection)
    try {
      _magnetometerSubscription = magnetometerEventStream().listen(
        (MagnetometerEvent event) {
          _isAvailable = true;
          double rawHeading = 0.0;

          final gNorm = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
          if (_hasAccelerometer && gNorm > 0.1) {
            // Direction Cosine / TRIAD 3D Tilt Compensation
            // Normalized gravity unit vector (pointing opposite to gravity)
            final ax = _gx / gNorm;
            final ay = _gy / gNorm;
            final az = _gz / gNorm;

            // Earth East horizontal vector: E = M x a
            final ex = (event.y * az) - (event.z * ay);
            final ey = (event.z * ax) - (event.x * az);
            final ez = (event.x * ay) - (event.y * ax);
            final eNorm = math.sqrt(ex * ex + ey * ey + ez * ez);

            if (eNorm > 0.001) {
              final eNormX = ex / eNorm;
              final eNormY = ey / eNorm;
              final eNormZ = ez / eNorm;

              // Earth North horizontal vector: N = a x E
              // ny component along phone forward Y-axis:
              final ny = (az * eNormX) - (ax * eNormZ);

              // Azimuth (bearing clockwise from North):
              final headingRad = math.atan2(eNormY, ny);
              rawHeading = headingRad * (180.0 / math.pi);
              if (rawHeading < 0) rawHeading += 360.0;
            } else {
              // Degenerate (magnetic field parallel to gravity)
              rawHeading = _currentHeading;
            }
          } else {
            // 2D Portrait Fallback (when accelerometer is still calibrating)
            // Note: -event.x ensures correct clockwise rotation from North
            final headingRad = math.atan2(-event.x, event.y);
            rawHeading = headingRad * (180.0 / math.pi);
            if (rawHeading < 0) rawHeading += 360.0;
          }

          // Initial reading lock (immediate convergence on app launch)
          if (!_hasInitialHeading) {
            _currentHeading = rawHeading;
            _hasInitialHeading = true;
            onHeadingUpdate?.call(_currentHeading);
            return;
          }

          // Shortest angular difference (-180 to +180)
          double diff = rawHeading - _currentHeading;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;

          if (_hasGyroscope) {
            // Gyroscope provides instantaneous updates. Magnetometer corrects drift.
            // Adaptive blend: faster sync if deviation is large, subtle if steady.
            final alpha = (diff.abs() > 20.0) ? 0.20 : 0.05;
            _currentHeading = (_currentHeading + alpha * diff) % 360;
            if (_currentHeading < 0) _currentHeading += 360;
            onHeadingUpdate?.call(_currentHeading);
          } else {
            // Standalone Magnetometer + Accelerometer Low-Pass Filter
            final alpha = (diff.abs() > 25.0) ? 0.35 : 0.15;
            _currentHeading = (_currentHeading + alpha * diff) % 360;
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

    // 3. Listen to Gyroscope (Instantaneous Angular Velocity / Zero-Latency Response)
    try {
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _hasGyroscope = true;
          final now = DateTime.now();

          if (_lastGyroTimestamp != null && _hasInitialHeading) {
            final dt = now.difference(_lastGyroTimestamp!).inMicroseconds / 1000000.0;

            // Filter reasonable time deltas (prevents jumps after pause)
            if (dt > 0.001 && dt < 0.2) {
              double yawRateRad = event.z;
              final gNorm = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);

              // 3D Gyroscope projection onto gravity vector for tilt-independent yaw rate
              if (_hasAccelerometer && gNorm > 0.1) {
                yawRateRad = (event.x * _gx + event.y * _gy + event.z * _gz) / gNorm;
              }

              // Clockwise rotation produces negative yaw, so negate to increase heading
              final gyroDeltaDeg = -yawRateRad * (180.0 / math.pi) * dt;

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
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    onHeadingUpdate = null;
    _lastGyroTimestamp = null;
    _hasInitialHeading = false;
  }
}
