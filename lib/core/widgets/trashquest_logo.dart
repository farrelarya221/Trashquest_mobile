import 'package:flutter/material.dart';

/// Logo resmi TrashQuest yang menampilkan Maskot TQ ECO dengan cincin konsentris,
/// pucuk daun hijau, ekspresi ceria berbinar, badge 'TQ ECO', dan wordmark tipografi modern.
class TrashQuestLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool isDark;
  final String? subtitle;
  final bool isVertical;

  const TrashQuestLogo({
    super.key,
    this.size = 80,
    this.showWordmark = false,
    this.isDark = false,
    this.subtitle,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Maskot TQ ECO Vektor (Skalabilitas Responsif)
    final symbol = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: TqMascotPainter(),
          ),

          // Badge Pill "TQ ECO"
          Positioned(
            bottom: size * 0.14,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: (size * 0.08).clamp(8.0, 18.0),
                vertical: (size * 0.02).clamp(2.0, 5.0),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0E4B2F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white,
                  width: (size * 0.015).clamp(1.0, 2.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Text(
                'TQ ECO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: (size * 0.09).clamp(8.5, 14.0),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!showWordmark) return symbol;

    // 2. Judul "TrashQuest"
    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Trash',
          style: TextStyle(
            fontSize: isVertical ? (size * 0.28).clamp(20.0, 30.0) : 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F243E),
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Quest',
          style: TextStyle(
            fontSize: isVertical ? (size * 0.28).clamp(20.0, 30.0) : 22,
            fontWeight: FontWeight.w900,
            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );

    // 3. Slogan Subtitle
    final subtitleWidget = subtitle != null
        ? Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle!,
              textAlign: isVertical ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: isVertical ? 13.5 : 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF14532D),
                letterSpacing: 0.1,
              ),
            ),
          )
        : null;

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          symbol,
          const SizedBox(height: 10),
          titleWidget,
          ?subtitleWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        symbol,
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleWidget,
            ?subtitleWidget,
          ],
        ),
      ],
    );
  }
}

/// CustomPainter untuk Maskot TQ ECO yang skalabel mengikuti parameter `size`
class TqMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + size.height * 0.025);

    // 1. Cincin Luar (Halus Mint)
    final outerRingPaint = Paint()
      ..color = const Color(0xFF86EFAC).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.015).clamp(1.0, 2.5);
    canvas.drawCircle(center, size.width * 0.46, outerRingPaint);

    // 2. Cincin Tengah (Hijau Mint Terang)
    final middleRingPaint = Paint()
      ..color = const Color(0xFF4ADE80).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.018).clamp(1.2, 2.8);
    canvas.drawCircle(center, size.width * 0.38, middleRingPaint);

    // 3. Lingkaran Putih Lembut Halo
    final haloPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.32, haloPaint);

    // Jari-jari badan maskot
    final bodyRadius = size.width * 0.24;

    // 4. Pucuk Daun di Kepala Maskot
    final sproutPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    final sproutBorderPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.015).clamp(1.0, 2.0);

    final sproutPath = Path();
    final topX = center.dx;
    final topY = center.dy - bodyRadius * 0.94;
    sproutPath.moveTo(topX, topY);
    sproutPath.cubicTo(
      topX - bodyRadius * 0.33,
      topY - bodyRadius * 0.33,
      topX - bodyRadius * 0.4,
      topY - bodyRadius * 0.65,
      topX,
      topY - bodyRadius * 0.8,
    );
    sproutPath.cubicTo(
      topX + bodyRadius * 0.4,
      topY - bodyRadius * 0.65,
      topX + bodyRadius * 0.33,
      topY - bodyRadius * 0.33,
      topX,
      topY,
    );
    canvas.drawPath(sproutPath, sproutPaint);
    canvas.drawPath(sproutPath, sproutBorderPaint);

    // Garis urat daun tengah
    final veinPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.012).clamp(0.8, 1.5);
    canvas.drawLine(
      Offset(topX, topY - bodyRadius * 0.7),
      Offset(topX, topY),
      veinPaint,
    );

    // 5. Badan Maskot Bulat Hijau Zamrud
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
      ).createShader(Rect.fromCircle(center: center, radius: bodyRadius));
    final bodyBorderPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.016).clamp(1.0, 2.0);

    canvas.drawCircle(center, bodyRadius, bodyPaint);
    canvas.drawCircle(center, bodyRadius, bodyBorderPaint);

    // 6. Mata Bulat Ekspresif
    final eyeWhitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF0F172A);
    final catchlightPaint = Paint()..color = Colors.white;

    final eyeOffsetX = bodyRadius * 0.33;
    final eyeOffsetY = center.dy - bodyRadius * 0.18;
    final leftEyeCenter = Offset(center.dx - eyeOffsetX, eyeOffsetY);
    final rightEyeCenter = Offset(center.dx + eyeOffsetX, eyeOffsetY);

    final eyeWidth = bodyRadius * 0.26;
    final eyeHeight = bodyRadius * 0.33;

    // Sclera putih
    canvas.drawOval(
      Rect.fromCenter(center: leftEyeCenter, width: eyeWidth, height: eyeHeight),
      eyeWhitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightEyeCenter, width: eyeWidth, height: eyeHeight),
      eyeWhitePaint,
    );

    // Pupil hitam
    final pupilWidth = bodyRadius * 0.18;
    final pupilHeight = bodyRadius * 0.24;
    canvas.drawOval(
      Rect.fromCenter(center: leftEyeCenter, width: pupilWidth, height: pupilHeight),
      pupilPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightEyeCenter, width: pupilWidth, height: pupilHeight),
      pupilPaint,
    );

    // Kilau mata putih (Catchlight)
    final catchlightRadius = (bodyRadius * 0.045).clamp(1.0, 2.5);
    canvas.drawCircle(
      Offset(leftEyeCenter.dx + eyeWidth * 0.15, leftEyeCenter.dy - eyeHeight * 0.15),
      catchlightRadius,
      catchlightPaint,
    );
    canvas.drawCircle(
      Offset(rightEyeCenter.dx + eyeWidth * 0.15, rightEyeCenter.dy - eyeHeight * 0.15),
      catchlightRadius,
      catchlightPaint,
    );

    // 7. Pipi Merona Pink (Blush)
    final blushPaint = Paint()
      ..color = const Color(0xFFF472B6).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final blushOffsetX = bodyRadius * 0.55;
    final blushOffsetY = center.dy + bodyRadius * 0.07;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - blushOffsetX, blushOffsetY),
        width: bodyRadius * 0.29,
        height: bodyRadius * 0.16,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + blushOffsetX, blushOffsetY),
        width: bodyRadius * 0.29,
        height: bodyRadius * 0.16,
      ),
      blushPaint,
    );

    // 8. Mulut Tersenyum Terbuka Ceria
    final mouthPath = Path();
    final mouthWidth = bodyRadius * 0.26;
    final mouthY = center.dy + bodyRadius * 0.11;
    mouthPath.moveTo(center.dx - mouthWidth, mouthY);
    mouthPath.quadraticBezierTo(
      center.dx,
      center.dy + bodyRadius * 0.36,
      center.dx + mouthWidth,
      mouthY,
    );
    mouthPath.close();

    final mouthPaint = Paint()..color = const Color(0xFFDC2626);
    final mouthBorderPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.012).clamp(0.8, 1.5);

    canvas.drawPath(mouthPath, mouthPaint);
    canvas.drawPath(mouthPath, mouthBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
