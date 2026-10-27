import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// A reusable, elegant ambient background featuring diffused aura glow orbs,
/// subtle topographic contours, and an organic curved hero arc.
/// Designed for premium mobile aesthetics without visual clutter or high-contrast garishness.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  final bool showHeroArc;
  final double heroHeight;
  final Color? primaryGlowColor;
  final Color? secondaryGlowColor;

  const AmbientBackground({
    super.key,
    required this.child,
    this.showHeroArc = true,
    this.heroHeight = 260.0,
    this.primaryGlowColor,
    this.secondaryGlowColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryGlow = primaryGlowColor ?? const Color(0xFF10B981); // Emerald
    final secondaryGlow = secondaryGlowColor ?? const Color(0xFF0EA5E9); // Sky Azure

    return Stack(
      children: [
        // 1. Base clean canvas gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFAFCFA),
                  Color(0xFFF1F5F2),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 2. Subtle Topographic Contour Waves
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight + 100,
          child: CustomPaint(
            painter: _TopographicContourPainter(
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
          ),
        ),

        // 3. Top Curved Hero Arc
        if (showHeroArc)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: CustomPaint(
              painter: _CurvedHeroArcPainter(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.09),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

        // 4. Ambient Aura Orbs (Diffused glow)
        // Top-Left Emerald Aura
        Positioned(
          top: -60,
          left: -60,
          width: 260,
          height: 260,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryGlow.withValues(alpha: 0.15),
                    primaryGlow.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Top-Right Sky Cyan Aura
        Positioned(
          top: 20,
          right: -70,
          width: 240,
          height: 240,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    secondaryGlow.withValues(alpha: 0.11),
                    secondaryGlow.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Mid-screen subtle warm amber accent glow
        Positioned(
          top: 380,
          left: -40,
          width: 190,
          height: 190,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // 5. Main Content Layer
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class _CurvedHeroArcPainter extends CustomPainter {
  final Gradient gradient;

  _CurvedHeroArcPainter({required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);

    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 25,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopographicContourPainter extends CustomPainter {
  final Color color;

  _TopographicContourPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 4; i++) {
      final path = Path();
      final yOffset = 45.0 + (i * 35.0);
      path.moveTo(0, yOffset);
      path.cubicTo(
        size.width * 0.3,
        yOffset - 30 + (i * 10),
        size.width * 0.7,
        yOffset + 40 - (i * 8),
        size.width,
        yOffset - 10,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
