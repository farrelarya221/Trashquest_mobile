import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import '../auth/auth_view.dart';
import '../../app/main_navigation_layout.dart';


class TrashQuestSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const TrashQuestSplashScreen({super.key, this.onComplete});

  @override
  State<TrashQuestSplashScreen> createState() => _TrashQuestSplashScreenState();
}

/// Alias untuk kompatibilitas arsitektur fitur internal
typedef SplashView = TrashQuestSplashScreen;

class _TrashQuestSplashScreenState extends State<TrashQuestSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _floatController;
  late final AnimationController _leafSparkleController;
  bool _servicesReady = false;

  @override
  void initState() {
    super.initState();

    // 1. Inisialisasi service di background selama splash berjalan (Supabase & SQLite)
    _initServices();

    // 2. Animasi floating lembut untuk Maskot & Logo TQ ECO (2 detik)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // 3. Animasi ayunan daun pada loading bar (1.4 detik)
    _leafSparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 4. Animasi loading bar selama 3.0 detik
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _handleComplete();
      }
    });
  }

  Future<void> _initServices() async {
    try {
      await Future.wait([
        SupabaseService.instance.initialize(),
        SqliteService.instance.database,
      ]);
    } catch (e) {
      debugPrint('Error initializing services in splash: $e');
    } finally {
      if (mounted) {
        setState(() {
          _servicesReady = true;
        });
        if (_progressController.isCompleted) {
          _handleComplete();
        }
      }
    }
  }

  void _handleComplete() {
    if (!_servicesReady) return;

    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      final user = SupabaseService.instance.currentUser;
      late final Widget targetScreen;
      if (user.id.isNotEmpty && user.id != 'guest') {
        targetScreen = MainNavigationLayout(
          onLogout: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (ctx) => AuthView(
                  onLoginSuccess: () {
                    Navigator.of(ctx).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => MainNavigationLayout(onLogout: () {}),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      } else {
        targetScreen = AuthView(
          onLoginSuccess: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MainNavigationLayout(onLogout: () {}),
              ),
            );
          },
        );
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: targetScreen,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _floatController.dispose();
    _leafSparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE4F6ED),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradasi hijau mint pastel lembut (#E4F6ED -> #F3FBF7 -> #E6F7EF)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE4F6ED),
                  Color(0xFFF3FBF7),
                  Color(0xFFE6F7EF),
                ],
              ),
            ),
          ),

          // Siluet daun pastel elegan di sudut atas-kanan
          Positioned(
            top: -20,
            right: 15,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                width: 105,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF72C29B).withValues(alpha: 0.22),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(80),
                    topRight: Radius.circular(140),
                    bottomLeft: Radius.circular(140),
                    bottomRight: Radius.circular(80),
                  ),
                ),
              ),
            ),
          ),

          // Siluet lingkaran cahaya pastel di sudut bawah-kiri
          Positioned(
            bottom: -50,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF72C29B).withValues(alpha: 0.18),
              ),
            ),
          ),

          // Konten Utama Splash Screen
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Maskot TQ ECO dengan Cincin Konsentris & Animasi Floating
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      final offset =
                          math.sin(_floatController.value * math.pi) * 6.0;
                      return Transform.translate(
                        offset: Offset(0, -offset),
                        child: child,
                      );
                    },
                    child: const _TqEcoMascot(),
                  ),

                  const SizedBox(height: 26),

                  // Judul Aplikasi: TrashQuest (Tebal & Modern)
                  const Text(
                    'TrashQuest',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F243E),
                      letterSpacing: -0.5,
                      fontFamily: 'sans-serif',
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Slogan Aplikasi
                  const Text(
                    'Pilah lebih mudah, bumi lebih bersih.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF14532D),
                      letterSpacing: 0.1,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Loading Progress Bar Elegan dengan Daun Indikator
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_progressController, _leafSparkleController]),
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TrashQuestLoadingBar(
                            progress: _progressController.value,
                            sparkleOffset: _leafSparkleController.value,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Memuat misi...',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF14422B),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  // Footer Info Aplikasi
                  const Text(
                    'TrashQuest v2.4.0 • Didukung oleh AI Multimodal & Supabase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4C7A63),
                      letterSpacing: 0.15,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget Maskot TQ ECO dengan Cincin Konsentris dan Badge "TQ ECO"
class _TqEcoMascot extends StatelessWidget {
  const _TqEcoMascot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gambar Maskot Vector Melalui CustomPainter
          CustomPaint(
            size: const Size(230, 230),
            painter: _TqMascotPainter(),
          ),

          // Badge Pill "TQ ECO" di bagian bawah badan maskot
          Positioned(
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0E4B2F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'TQ ECO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter untuk menggambar Maskot TQ ECO dengan cincin konsentris,
/// pucuk daun di kepala, ekspresi mata bulat berbinar, pipi merona pink, dan senyum ceria.
class _TqMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 6);

    // 1. Cincin Luar (Halus Mint)
    final outerRingPaint = Paint()
      ..color = const Color(0xFF86EFAC).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 105, outerRingPaint);

    // 2. Cincin Tengah (Hijau Mint Terang)
    final middleRingPaint = Paint()
      ..color = const Color(0xFF4ADE80).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 88, middleRingPaint);

    // 3. Lingkaran Putih Lembut Halo
    final haloPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 74, haloPaint);

    // 4. Pucuk Daun di Kepala Maskot
    final sproutPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    final sproutBorderPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final sproutPath = Path();
    final topX = center.dx;
    final topY = center.dy - 52;
    sproutPath.moveTo(topX, topY);
    sproutPath.cubicTo(
        topX - 18, topY - 18, topX - 22, topY - 36, topX, topY - 44);
    sproutPath.cubicTo(
        topX + 22, topY - 36, topX + 18, topY - 18, topX, topY);
    canvas.drawPath(sproutPath, sproutPaint);
    canvas.drawPath(sproutPath, sproutBorderPaint);

    // Garis urat daun tengah
    final veinPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(topX, topY - 38), Offset(topX, topY), veinPaint);

    // 5. Badan Maskot Bulat Hijau Zamrud
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
      ).createShader(Rect.fromCircle(center: center, radius: 55));
    final bodyBorderPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, 55, bodyPaint);
    canvas.drawCircle(center, 55, bodyBorderPaint);

    // 6. Mata Bulat Ekspresif
    final eyeWhitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF0F172A);
    final catchlightPaint = Paint()..color = Colors.white;

    final leftEyeCenter = Offset(center.dx - 18, center.dy - 10);
    final rightEyeCenter = Offset(center.dx + 18, center.dy - 10);

    // Bagian putih mata
    canvas.drawOval(
        Rect.fromCenter(center: leftEyeCenter, width: 14, height: 18),
        eyeWhitePaint);
    canvas.drawOval(
        Rect.fromCenter(center: rightEyeCenter, width: 14, height: 18),
        eyeWhitePaint);

    // Pupil hitam
    canvas.drawOval(
        Rect.fromCenter(center: leftEyeCenter, width: 10, height: 13),
        pupilPaint);
    canvas.drawOval(
        Rect.fromCenter(center: rightEyeCenter, width: 10, height: 13),
        pupilPaint);

    // Kilau mata (Catchlight)
    canvas.drawCircle(
        Offset(leftEyeCenter.dx + 2, leftEyeCenter.dy - 3), 2.5, catchlightPaint);
    canvas.drawCircle(
        Offset(rightEyeCenter.dx + 2, rightEyeCenter.dy - 3), 2.5, catchlightPaint);

    // 7. Pipi Merona Pink (Blush)
    final blushPaint = Paint()
      ..color = const Color(0xFFF472B6).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx - 30, center.dy + 4),
            width: 16, height: 9),
        blushPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx + 30, center.dy + 4),
            width: 16, height: 9),
        blushPaint);

    // 8. Mulut Tersenyum Terbuka Ceria
    final mouthPath = Path();
    mouthPath.moveTo(center.dx - 14, center.dy + 6);
    mouthPath.quadraticBezierTo(
        center.dx, center.dy + 20, center.dx + 14, center.dy + 6);
    mouthPath.close();

    final mouthPaint = Paint()..color = const Color(0xFFDC2626);
    final mouthBorderPaint = Paint()
      ..color = const Color(0xFF14532D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(mouthPath, mouthPaint);
    canvas.drawPath(mouthPath, mouthBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget Loading Bar bertema Hijau Segar & Daun Indikator
/// Menampilkan kapsul track mint-grey transparan, bar aktif bergradasi hijau zamrud,
/// serta node lingkaran putih dan daun indikator di atas ujung bar.
class _TrashQuestLoadingBar extends StatelessWidget {
  final double progress;
  final double sparkleOffset;

  const _TrashQuestLoadingBar({
    required this.progress,
    required this.sparkleOffset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final currentWidth = (maxWidth * progress).clamp(18.0, maxWidth);

          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // Track Latar Belakang (Translucent Mint-Grey Capsule)
              Container(
                width: maxWidth,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF90C8A8).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              // Isi Bar Aktif (Gradasi Hijau Zamrud)
              Container(
                width: currentWidth,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4ADE80),
                      Color(0xFF22C55E),
                      Color(0xFF16A34A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),

              // Node Titik Lingkaran Putih di Kepala Bar
              Positioned(
                left: (currentWidth - 7).clamp(0.0, maxWidth - 14),
                top: 15, // center vertically in height 48 Stack
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF14532D),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // Daun / Sprout Indikator di Atas Kepala Bar
              Positioned(
                left: (currentWidth - 10).clamp(0.0, maxWidth - 20),
                top: -5 + (sparkleOffset * 2.5),
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.eco_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
