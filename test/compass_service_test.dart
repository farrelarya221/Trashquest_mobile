import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:trashquest/services/compass_service.dart';

void main() {
  group('CompassService Mathematical Tests', () {
    test('CompassService initializes with default heading 0.0', () {
      final service = CompassService();
      expect(service.currentHeading, 0.0);
      expect(service.isAvailable, false);
      expect(service.hasGyroscope, false);
      expect(service.hasAccelerometer, false);
    });

    test('CompassService setManualHeading works cleanly with modulo wrapping', () {
      final service = CompassService();
      double reported = -1.0;
      service.startListening(onUpdate: (h) => reported = h);

      service.setManualHeading(90.0);
      expect(service.currentHeading, 90.0);
      expect(reported, 90.0);

      service.setManualHeading(450.0);
      expect(service.currentHeading, 90.0);

      service.setManualHeading(-90.0);
      expect(service.currentHeading, 270.0);

      service.stopListening();
    });

    test('3D Tilt-Compensation TRIAD math resolves cardinal directions correctly', () {
      // Helper function to simulate CompassService's TRIAD calculation
      double computeHeading({
        required double gx,
        required double gy,
        required double gz,
        required double mx,
        required double my,
        required double mz,
      }) {
        final gNorm = math.sqrt(gx * gx + gy * gy + gz * gz);
        final ax = gx / gNorm;
        final ay = gy / gNorm;
        final az = gz / gNorm;

        // E = M x a
        final ex = (my * az) - (mz * ay);
        final ey = (mz * ax) - (mx * az);
        final ez = (mx * ay) - (my * ax);
        final eNorm = math.sqrt(ex * ex + ey * ey + ez * ez);

        final eNormX = ex / eNorm;
        final eNormY = ey / eNorm;
        final eNormZ = ez / eNorm;

        // N = a x E
        final ny = (az * eNormX) - (ax * eNormZ);

        final headingRad = math.atan2(eNormY, ny);
        var headingDeg = headingRad * (180.0 / math.pi);
        if (headingDeg < 0) headingDeg += 360.0;
        return headingDeg;
      }

      // 1. Flat, pointing North: g = (0, 0, 9.8), M = (0, 30, -20) (with magnetic dip)
      final northDeg = computeHeading(gx: 0, gy: 0, gz: 9.8, mx: 0, my: 30, mz: -20);
      expect(northDeg, closeTo(0.0, 0.01));

      // 2. Flat, pointing East: g = (0, 0, 9.8), M = (-30, 0, -20)
      final eastDeg = computeHeading(gx: 0, gy: 0, gz: 9.8, mx: -30, my: 0, mz: -20);
      expect(eastDeg, closeTo(90.0, 0.01));

      // 3. Flat, pointing South: g = (0, 0, 9.8), M = (0, -30, -20)
      final southDeg = computeHeading(gx: 0, gy: 0, gz: 9.8, mx: 0, my: -30, mz: -20);
      expect(southDeg, closeTo(180.0, 0.01));

      // 4. Flat, pointing West: g = (0, 0, 9.8), M = (30, 0, -20)
      final westDeg = computeHeading(gx: 0, gy: 0, gz: 9.8, mx: 30, my: 0, mz: -20);
      expect(westDeg, closeTo(270.0, 0.01));

      // 5. TILTED 45 DEGREES (held in user hand while walking) pointing North:
      // In hand: gravity has y component = -sin(45)*g, z component = cos(45)*g
      final s45 = math.sin(math.pi / 4);
      final c45 = math.cos(math.pi / 4);
      final gxTilted = 0.0;
      final gyTilted = -s45 * 9.8;
      final gzTilted = c45 * 9.8;

      // Magnetic field in rotated frame:
      final mxTilted = 0.0;
      final myTilted = c45 * 30.0;
      final mzTilted = s45 * 30.0;

      final tiltedNorthDeg = computeHeading(
        gx: gxTilted,
        gy: gyTilted,
        gz: gzTilted,
        mx: mxTilted,
        my: myTilted,
        mz: mzTilted,
      );
      // Must remain exactly North (0°) even when heavily tilted!
      expect(tiltedNorthDeg, closeTo(0.0, 0.01));
    });

    test('Continuous angle unwrap math avoids 360-to-0 jumping glitch', () {
      double lastRaw = 359.0;
      double unwrapped = 359.0;

      // Rotate clockwise by 3 degrees across the North boundary (359 -> 2)
      double newRaw = 2.0;
      double diff = newRaw - lastRaw; // 2 - 359 = -357
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360; // diff becomes +3.0!

      unwrapped += diff; // unwrapped becomes 362.0!
      expect(diff, 3.0);
      expect(unwrapped, 362.0);
      expect(unwrapped % 360, closeTo(2.0, 0.001));
    });
  });
}

