import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:confetti/confetti.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/models/waste_item.dart';
import '../../services/supabase_service.dart';
import '../../services/sqlite_service.dart';
import '../../data/models/quest_challenge.dart';

class NinjaTrash {
  final int id;
  final String name;
  final WasteCategory category;
  final IconData icon;
  double x, y;
  double vx, vy;
  double rotation;
  double rotationSpeed;
  bool isSliced;
  double splitDistance;

  NinjaTrash({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotationSpeed,
    this.rotation = 0,
    this.isSliced = false,
    this.splitDistance = 0,
  });
}

class NinjaParticle {
  double x, y;
  double vx, vy;
  Color color;
  double opacity;
  double size;

  NinjaParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    this.opacity = 1.0,
    this.size = 5.0,
  });
}

class TrashNinjaGameView extends StatefulWidget {
  const TrashNinjaGameView({super.key});

  @override
  State<TrashNinjaGameView> createState() => _TrashNinjaGameViewState();
}

class _TrashNinjaGameViewState extends State<TrashNinjaGameView> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late ConfettiController _confettiController;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _lives = 3;
  int _comboCount = 0;
  String? _comboText;

  final List<NinjaTrash> _activeTrash = [];
  final List<NinjaParticle> _particles = [];
  final Random _random = Random();
  int _idCounter = 0;
  int _framesSinceLastSpawn = 0;
  double _spawnRate = 80;

  final List<Offset> _sliceTrail = [];
  int _trailTimer = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    if (_ticker.isActive) _ticker.stop();
    _ticker.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _lives = 3;
      _comboCount = 0;
      _comboText = null;
      _activeTrash.clear();
      _particles.clear();
      _framesSinceLastSpawn = 0;
      _spawnRate = 80;
    });
    _ticker.start();
  }

  void _endGame() {
    _ticker.stop();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
    if (_score > 0) {
      SupabaseService.instance.addXp(_score);
    }
    if (_score >= 40) {
      _confettiController.play();
    }
  }

  void _tick(Duration elapsed) {
    if (!_isPlaying) return;

    setState(() {
      // Trail fade
      if (_sliceTrail.isNotEmpty) {
        _trailTimer++;
        if (_trailTimer > 6) {
          _sliceTrail.clear();
          _trailTimer = 0;
        }
      }

      // Update particles
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.opacity -= 0.05;
        if (p.opacity <= 0) {
          _particles.removeAt(i);
        }
      }

      // Update trash
      for (int i = _activeTrash.length - 1; i >= 0; i--) {
        final t = _activeTrash[i];
        t.x += t.vx;
        t.y += t.vy;
        t.vy += 0.0006;
        t.rotation += t.rotationSpeed;

        if (t.isSliced) {
          t.splitDistance += 0.006;
        }

        // Falls off bottom
        if (t.y > 1.25) {
          if (!t.isSliced && (t.category == WasteCategory.organik || t.category == WasteCategory.anorganik)) {
            _lives--;
            if (_lives <= 0) {
              _endGame();
              return;
            }
          }
          _activeTrash.removeAt(i);
        }
      }

      _framesSinceLastSpawn++;
      if (_framesSinceLastSpawn >= _spawnRate) {
        _spawnTrash();
        _framesSinceLastSpawn = 0;
        if (_spawnRate > 32) {
          _spawnRate -= 1.2;
        }
      }
    });
  }

  void _spawnTrash() {
    final types = [
      {'name': 'Botol Plastik', 'cat': WasteCategory.anorganik, 'icon': Icons.local_drink_rounded},
      {'name': 'Kardus Box', 'cat': WasteCategory.anorganik, 'icon': Icons.inventory_2_outlined},
      {'name': 'Kulit Pisang', 'cat': WasteCategory.organik, 'icon': Icons.eco_rounded},
      {'name': 'Sisa Buah', 'cat': WasteCategory.organik, 'icon': Icons.apple_rounded},
      {'name': 'Lampu Neon', 'cat': WasteCategory.b3, 'icon': Icons.lightbulb_outline_rounded},
      {'name': 'Baterai Bekas', 'cat': WasteCategory.b3, 'icon': Icons.battery_alert_rounded},
      {'name': 'Racun Serangga', 'cat': WasteCategory.b3, 'icon': Icons.warning_amber_rounded},
    ];

    final picked = types[_random.nextInt(types.length)];
    _idCounter++;
    _activeTrash.add(
      NinjaTrash(
        id: _idCounter,
        name: picked['name'] as String,
        category: picked['cat'] as WasteCategory,
        icon: picked['icon'] as IconData,
        x: 0.2 + _random.nextDouble() * 0.6,
        y: 1.15,
        vx: (_random.nextDouble() - 0.5) * 0.016,
        vy: -0.022 - (_random.nextDouble() * 0.010),
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.14,
      ),
    );
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isPlaying) return;

    final dx = details.localPosition.dx / constraints.maxWidth;
    final dy = details.localPosition.dy / constraints.maxHeight;

    setState(() {
      _sliceTrail.add(Offset(dx, dy));
      if (_sliceTrail.length > 7) _sliceTrail.removeAt(0);
      _trailTimer = 0;

      for (var t in _activeTrash) {
        if (t.isSliced) continue;

        final dist = sqrt(pow(t.x - dx, 2) + pow(t.y - dy, 2));
        if (dist < 0.11) {
          t.isSliced = true;

          // Spawn burst particles
          final particleColor = _categoryColor(t.category);
          for (int p = 0; p < 8; p++) {
            _particles.add(
              NinjaParticle(
                x: t.x,
                y: t.y,
                vx: (_random.nextDouble() - 0.5) * 0.02,
                vy: (_random.nextDouble() - 0.5) * 0.02,
                color: particleColor,
                size: 3.0 + _random.nextDouble() * 4.0,
              ),
            );
          }

          if (t.category == WasteCategory.b3) {
            // Cut hazardous waste: instant penalty!
            _lives--;
            _comboCount = 0;
            _comboText = '⚠️ AWAS! Limbah B3!';
            if (_lives <= 0) {
              _endGame();
              return;
            }
          } else {
            _score += 5;
            SqliteService.instance.incrementQuestProgressByType(QuestType.sortWaste, amount: 1);
            _comboCount++;
            if (_comboCount >= 3) {
              _score += 5; // Combo bonus
              _comboText = '🔥 COMBO x$_comboCount! (+10 XP)';
            }
          }
        }
      }
    });
  }

  Color _categoryColor(WasteCategory cat) {
    switch (cat) {
      case WasteCategory.organik:
        return const Color(0xFF10B981); // Emerald
      case WasteCategory.anorganik:
        return const Color(0xFF0EA5E9); // Sky Cyan
      case WasteCategory.b3:
        return const Color(0xFFEF4444); // Crimson Alert
      case WasteCategory.residu:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4), // Bright fresh mint
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flash_on_rounded, color: Color(0xFF0284C7), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Trash Ninja',
              style: AppTextStyles.titleMedium.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          if (_isPlaying || _isGameOver)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        index < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Floating Status Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.speed_rounded, size: 14, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Text(
                          'Kecepatan: ${(100 - _spawnRate).toInt()}%',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Colors.amberAccent),
                        const SizedBox(width: 4),
                        Text(
                          '$_score XP',
                          style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_comboText != null && _isPlaying)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _comboText!,
                    style: const TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // Game Arena with Crisp Bright Glassmorphism
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.all(AppSpacing.screenPadding),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;

                        return GestureDetector(
                          onPanUpdate: (details) => _handlePanUpdate(details, constraints),
                          child: Stack(
                            children: [
                              // Subtle background grid ambient
                              CustomPaint(
                                size: Size(width, height),
                                painter: _ArenaBackgroundPainter(),
                              ),

                              if (!_isPlaying && !_isGameOver)
                                _buildStartScreen(),

                              if (_isGameOver)
                                _buildGameOverScreen(),

                              // Active flying trash items
                              if (_isPlaying) ...[
                                for (final t in _activeTrash)
                                  _buildTrashWidget(t, width, height),
                              ],

                              // Particles
                              if (_isPlaying) ...[
                                for (final p in _particles)
                                  Positioned(
                                    left: p.x * width,
                                    top: p.y * height,
                                    child: Opacity(
                                      opacity: p.opacity.clamp(0.0, 1.0),
                                      child: Container(
                                        width: p.size,
                                        height: p.size,
                                        decoration: BoxDecoration(
                                          color: p.color,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(color: p.color, blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],

                              // Blade Slash Trail
                              if (_isPlaying && _sliceTrail.isNotEmpty)
                                CustomPaint(
                                  painter: _SliceTrailPainter(_sliceTrail, width, height),
                                  size: Size(width, height),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Confetti overlay on win
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirection: pi / 2,
                      maxBlastForce: 15,
                      minBlastForce: 5,
                      numberOfParticles: 25,
                      colors: const [Colors.amber, Colors.cyan, Color(0xFF10B981), Colors.greenAccent],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTrashWidget(NinjaTrash t, double width, double height) {
    final catColor = _categoryColor(t.category);
    final isB3 = t.category == WasteCategory.b3;
    const size = 68.0;

    return Positioned(
      left: (t.x * width) - (size / 2),
      top: (t.y * height) - (size / 2),
      child: Transform.rotate(
        angle: t.rotation,
        child: Opacity(
          opacity: t.isSliced ? 0.85 : 1.0,
          child: t.isSliced
              // Sliced item split visual
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(-t.splitDistance * width, 0),
                      child: _buildItemHalve(t, catColor, true),
                    ),
                    const SizedBox(width: 4),
                    Transform.translate(
                      offset: Offset(t.splitDistance * width, 0),
                      child: _buildItemHalve(t, catColor, false),
                    ),
                  ],
                )
              // Whole Item token - Bright glossy token with vibrant border
              : Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: isB3 ? const Color(0xFFEF4444) : catColor,
                      width: isB3 ? 3.0 : 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: catColor.withValues(alpha: isB3 ? 0.45 : 0.25),
                        blurRadius: isB3 ? 16 : 8,
                        spreadRadius: isB3 ? 2 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, color: isB3 ? const Color(0xFFEF4444) : catColor, size: 26),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.name,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildItemHalve(NinjaTrash t, Color color, bool isLeft) {
    return Container(
      width: 32,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? const Radius.circular(30) : Radius.zero,
          bottomLeft: isLeft ? const Radius.circular(30) : Radius.zero,
          topRight: !isLeft ? const Radius.circular(30) : Radius.zero,
          bottomRight: !isLeft ? const Radius.circular(30) : Radius.zero,
        ),
        border: Border.all(color: color, width: 2.0),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: Center(
        child: Icon(Icons.flash_on_rounded, size: 16, color: color),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.cut_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'TRASH NINJA',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Usap layar untuk menebas sampah yang terbang!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 20),

            // Rules Guide Pill
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tebas: Organik & Anorganik (+5 XP)',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'HINDARI: Limbah B3 beracun (Kurang Nyawa!)',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Mulai Tebas!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _score >= 40 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              ),
              child: Icon(
                _score >= 40 ? Icons.emoji_events_rounded : Icons.sports_kabaddi_rounded,
                size: 54,
                color: _score >= 40 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _score >= 40 ? 'Luar Biasa, Ninja!' : 'Permainan Selesai!',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Skor: $_score XP',
              style: const TextStyle(
                color: Color(0xFF0284C7),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Poin XP sudah otomatis tersimpan ke profilmu.',
              style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Main Lagi', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArenaBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    // Draw subtle grid lines
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SliceTrailPainter extends CustomPainter {
  final List<Offset> trail;
  final double width;
  final double height;

  _SliceTrailPainter(this.trail, this.width, this.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.length < 2) return;

    final glowPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.4)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    final corePaint = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(trail[0].dx * width, trail[0].dy * height);
    for (int i = 1; i < trail.length; i++) {
      path.lineTo(trail[i].dx * width, trail[i].dy * height);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant _SliceTrailPainter oldDelegate) => true;
}
