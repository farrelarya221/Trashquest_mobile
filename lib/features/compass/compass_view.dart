import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/waste_bank.dart';
import '../../services/compass_service.dart';
import '../../services/location_service.dart';

class CompassView extends StatefulWidget {
  final WasteBank targetBank;

  const CompassView({super.key, required this.targetBank});

  @override
  State<CompassView> createState() => _CompassViewState();
}

class _CompassViewState extends State<CompassView> {
  final CompassService _compassService = CompassService();

  double _deviceHeading = 0.0;
  double _unwrappedHeading = 0.0;
  double _lastRawHeading = 0.0;

  double _targetBearing = 0.0;
  double _distanceKm = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCompassAndLocation();
  }

  Future<void> _initCompassAndLocation() async {
    final userPos = await LocationService.instance.getCurrentLocation();
    final targetPos = LatLng(widget.targetBank.latitude, widget.targetBank.longitude);

    _distanceKm = LocationService.instance.calculateDistanceKm(userPos, targetPos);
    _targetBearing = LocationService.instance.calculateBearing(userPos, targetPos);

    _compassService.startListening(
      onUpdate: (heading) {
        if (!mounted) return;
        setState(() {
          // Continuous unwrap to guarantee butter-smooth rotation without 360-to-0 jumping
          double diff = heading - _lastRawHeading;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;

          _unwrappedHeading += diff;
          _lastRawHeading = heading;
          _deviceHeading = heading;
        });
      },
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _compassService.stopListening();
    super.dispose();
  }

  Future<void> _openGoogleMapsRoute() async {
    final lat = widget.targetBank.latitude;
    final lng = widget.targetBank.longitude;
    final cleanLabel = Uri.encodeComponent(widget.targetBank.name);

    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsDirUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$cleanLabel&travelmode=driving',
    );
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($cleanLabel)');

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(googleMapsDirUrl)) {
        await launchUrl(googleMapsDirUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(googleMapsDirUrl, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka Google Maps: $e')),
        );
      }
    }
  }

  String _getCardinalDirection(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'Utara';
    if (degrees >= 22.5 && degrees < 67.5) return 'Timur Laut';
    if (degrees >= 67.5 && degrees < 112.5) return 'Timur';
    if (degrees >= 112.5 && degrees < 157.5) return 'Tenggara';
    if (degrees >= 157.5 && degrees < 202.5) return 'Selatan';
    if (degrees >= 202.5 && degrees < 247.5) return 'Barat Daya';
    if (degrees >= 247.5 && degrees < 292.5) return 'Barat';
    return 'Barat Laut';
  }

  String _formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    // Relative angle pointing from device top towards the target
    final relativeAngle = (_targetBearing - _deviceHeading + 360) % 360;
    final unwrappedDialTurns = -_unwrappedHeading / 360.0;
    final unwrappedArrowTurns = (_targetBearing - _unwrappedHeading) / 360.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E), // Premium iOS Dark Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Kompas Navigator',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openGoogleMapsRoute,
            tooltip: 'Buka di Google Maps',
            icon: const Icon(Icons.near_me_rounded, color: Color(0xFF34D399), size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF22C55E)),
              )
            : Column(
                children: [
                  const SizedBox(height: 16),

                  // 1. Heading Degree & Cardinal Text (Pixel-perfect typography)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_deviceHeading.round()}°',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: -2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _compassService.hasGyroscope
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEAB308),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getCardinalDirection(_deviceHeading).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // 2. Ultra-Smooth Vector Compass Dial
                  Center(
                    child: SizedBox(
                      width: 320,
                      height: 320,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating Vector Dial (Smooth 60/120fps GPU transform)
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: unwrappedDialTurns, end: unwrappedDialTurns),
                            duration: const Duration(milliseconds: 60),
                            curve: Curves.easeOutCubic,
                            builder: (context, turns, child) {
                              return Transform.rotate(
                                angle: turns * 2 * math.pi,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 320,
                              height: 320,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: CustomPaint(
                                size: const Size(320, 320),
                                painter: _SmoothCompassDialPainter(),
                              ),
                            ),
                          ),

                          // Vector Center Crosshair & Gimbal Circle
                          IgnorePointer(
                            child: CustomPaint(
                              size: const Size(140, 140),
                              painter: _CenterCrosshairPainter(),
                            ),
                          ),

                          // Rotating Target Pointer Arrow (Smooth Vector Render)
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: unwrappedArrowTurns, end: unwrappedArrowTurns),
                            duration: const Duration(milliseconds: 60),
                            curve: Curves.easeOutCubic,
                            builder: (context, turns, child) {
                              return Transform.rotate(
                                angle: turns * 2 * math.pi,
                                child: child,
                              );
                            },
                            child: SizedBox(
                              width: 320,
                              height: 320,
                              child: CustomPaint(
                                size: const Size(320, 320),
                                painter: _TargetArrowPainter(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 3. Target Destination Details & Google Maps Quick Route Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E), // Apple Card Dark Tone
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.targetBank.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Jarak: ${_formatDistance(_distanceKm)} • Arah: ${_targetBearing.round()}° (Relatif ${relativeAngle.round()}°)',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.targetBank.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Turn-by-Turn Google Maps Navigation Action
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openGoogleMapsRoute,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.near_me_rounded, size: 18),
                            label: const Text(
                              'Buka Rute Google Maps',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Anti-aliased, pixel-perfect iOS Compass Dial Painter
class _SmoothCompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Major Ticks (every 30 degrees)
    final majorTickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Medium Ticks (every 10 degrees)
    final mediumTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Minor Ticks (every 2 degrees)
    final minorTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Red North Pointer (Equilateral chevron with anti-aliasing)
    final northPaint = Paint()
      ..color = const Color(0xFFFF3B30) // Apple System Red
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int deg = 0; deg < 360; deg += 2) {
      final rad = deg * (math.pi / 180.0);
      final isMajor = deg % 30 == 0;
      final isMedium = deg % 10 == 0;
      final isCardinal = deg % 90 == 0;

      if (deg == 0) {
        // Red North Triangle Pointer
        final path = Path()
          ..moveTo(center.dx, center.dy - radius + 12)
          ..lineTo(center.dx - 8, center.dy - radius + 30)
          ..lineTo(center.dx + 8, center.dy - radius + 30)
          ..close();
        canvas.drawPath(path, northPaint);
        continue;
      }

      final tickLength = isMajor ? 13.0 : (isMedium ? 8.5 : 5.0);
      final p1 = Offset(
        center.dx + (radius - 12) * math.sin(rad),
        center.dy - (radius - 12) * math.cos(rad),
      );
      final p2 = Offset(
        center.dx + (radius - 12 - tickLength) * math.sin(rad),
        center.dy - (radius - 12 - tickLength) * math.cos(rad),
      );

      final paintToUse = isMajor
          ? majorTickPaint
          : (isMedium ? mediumTickPaint : minorTickPaint);

      canvas.drawLine(p1, p2, paintToUse);

      // Cardinal Labels ('E', 'S', 'W')
      if (isCardinal) {
        final label = deg == 90 ? 'E' : (deg == 180 ? 'S' : 'W');
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final offset = Offset(
          center.dx + (radius - 46) * math.sin(rad) - (textPainter.width / 2),
          center.dy - (radius - 46) * math.cos(rad) - (textPainter.height / 2),
        );
        textPainter.paint(canvas, offset);
      }
      // Major Degree Numbers (30, 60, 120, 150, 210, 240, 300, 330)
      else if (isMajor) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: deg.toString(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final offset = Offset(
          center.dx + (radius - 40) * math.sin(rad) - (textPainter.width / 2),
          center.dy - (radius - 40) * math.cos(rad) - (textPainter.height / 2),
        );
        textPainter.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vector Painter for Center Gimbal Crosshairs
class _CenterCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, circlePaint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(center, 5.0, dotPaint);

    // Subtle crosshair cross markers
    final crossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(Offset(center.dx - 12, center.dy), Offset(center.dx - 6, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx + 6, center.dy), Offset(center.dx + 12, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 12), Offset(center.dx, center.dy - 6), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy + 6), Offset(center.dx, center.dy + 12), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vector Painter for Glowing Target Pointer Needle (Points towards Bank Sampah)
class _TargetArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final topY = 12.0;

    // Glowing shadow
    final glowPaint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..isAntiAlias = true;

    final arrowPath = Path()
      ..moveTo(center.dx, topY)
      ..lineTo(center.dx - 16, topY + 34)
      ..lineTo(center.dx - 7, topY + 28)
      ..lineTo(center.dx - 7, topY + 48)
      ..lineTo(center.dx + 7, topY + 48)
      ..lineTo(center.dx + 7, topY + 28)
      ..lineTo(center.dx + 16, topY + 34)
      ..close();

    canvas.drawPath(arrowPath, glowPaint);

    // Solid Emerald Vector Pointer
    final arrowPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(arrowPath, arrowPaint);

    // White center highlight line for depth
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(Offset(center.dx, topY + 6), Offset(center.dx, topY + 38), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
