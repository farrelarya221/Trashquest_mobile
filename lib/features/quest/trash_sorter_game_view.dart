import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:confetti/confetti.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/models/waste_item.dart';
import '../../services/sensor_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sqlite_service.dart';
import '../../data/models/quest_challenge.dart';

class SorterGameItem {
  final String name;
  final WasteCategory category;
  final IconData icon;

  const SorterGameItem({
    required this.name,
    required this.category,
    required this.icon,
  });
}

class TrashSorterGameView extends StatefulWidget {
  const TrashSorterGameView({super.key});

  @override
  State<TrashSorterGameView> createState() => _TrashSorterGameViewState();
}

class _TrashSorterGameViewState extends State<TrashSorterGameView> with SingleTickerProviderStateMixin {
  final SensorService _sensorService = SensorService();
  late ConfettiController _confettiController;

  static const List<SorterGameItem> _itemPool = [
    SorterGameItem(name: 'Botol Plastik PET', category: WasteCategory.anorganik, icon: Icons.local_drink_rounded),
    SorterGameItem(name: 'Kulit Buah Pisang', category: WasteCategory.organik, icon: Icons.eco_rounded),
    SorterGameItem(name: 'Baterai Bekas', category: WasteCategory.b3, icon: Icons.battery_alert_rounded),
    SorterGameItem(name: 'Styrofoam Bekas', category: WasteCategory.residu, icon: Icons.delete_outline_rounded),
    SorterGameItem(name: 'Kardus Kemasan', category: WasteCategory.anorganik, icon: Icons.inventory_2_outlined),
    SorterGameItem(name: 'Sisa Sayuran', category: WasteCategory.organik, icon: Icons.grass_rounded),
    SorterGameItem(name: 'Lampu Neon', category: WasteCategory.b3, icon: Icons.lightbulb_outline_rounded),
    SorterGameItem(name: 'Puntung Rokok', category: WasteCategory.residu, icon: Icons.smoking_rooms_rounded),
    SorterGameItem(name: 'Kaleng Minuman', category: WasteCategory.anorganik, icon: Icons.takeout_dining_rounded),
    SorterGameItem(name: 'Daun Kering', category: WasteCategory.organik, icon: Icons.energy_savings_leaf_rounded),
  ];

  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _streak = 0;
  int _currentItemIndex = 0;
  double _itemX = 0.0; // -1.0 to 1.0
  double _itemY = 0.0; // 0.0 to 0.85
  late Ticker _ticker;
  String? _feedbackMessage;
  Color? _feedbackColor;

  final List<WasteCategory> _bins = [
    WasteCategory.organik,
    WasteCategory.anorganik,
    WasteCategory.b3,
    WasteCategory.residu,
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _startSensors();
  }

  void _tick(Duration elapsed) {
    if (!_isPlaying) return;
    setState(() {
      _itemY += 0.008; // smooth 60fps descent
      if (_itemY >= 0.84) {
        _evaluateItemPlacement();
      }
    });
  }

  void _startSensors() {
    _sensorService.startListening(
      onUpdate: (tilt) {
        if (_isPlaying && mounted) {
          setState(() {
            _itemX = (_itemX + tilt * 0.08).clamp(-1.0, 1.0);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    if (_ticker.isActive) _ticker.stop();
    _ticker.dispose();
    _confettiController.dispose();
    _sensorService.stopListening();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _streak = 0;
      _currentItemIndex = 0;
      _itemX = 0.0;
      _itemY = 0.0;
      _feedbackMessage = null;
    });
    _ticker.start();
  }

  WasteCategory _getCurrentTargetBin() {
    if (_itemX < -0.5) return WasteCategory.organik;
    if (_itemX < 0.0) return WasteCategory.anorganik;
    if (_itemX < 0.5) return WasteCategory.b3;
    return WasteCategory.residu;
  }

  void _evaluateItemPlacement() {
    final currentItem = _itemPool[_currentItemIndex % _itemPool.length];
    final selectedBin = _getCurrentTargetBin();

    final isCorrect = selectedBin == currentItem.category;
    if (isCorrect) {
      _streak++;
      int addedXp = 10;
      if (_streak >= 4) addedXp += 15; // Streak bonus
      _score += addedXp;
      _feedbackMessage = '✓ TEPAT! +$addedXp XP (${selectedBin.displayName})';
      _feedbackColor = const Color(0xFF10B981);
      SqliteService.instance.incrementQuestProgressByType(QuestType.sortWaste, amount: 1);
    } else {
      _streak = 0;
      _feedbackMessage = '✕ SALAH! Seharusnya ${currentItem.category.displayName}';
      _feedbackColor = const Color(0xFFEF4444);
    }

    if (_currentItemIndex >= 7) {
      _endGame();
    } else {
      _currentItemIndex++;
      _itemY = 0.0;
      _itemX = 0.0;
    }
  }

  void _endGame() {
    _ticker.stop();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    final totalReward = _score + 25; // Round bonus
    SupabaseService.instance.addXp(totalReward);
    SupabaseService.instance.incrementSortedCount(8);

    if (_score >= 40) {
      _confettiController.play();
    }
  }

  Color _binColor(WasteCategory cat) {
    switch (cat) {
      case WasteCategory.organik:
        return const Color(0xFF10B981);
      case WasteCategory.anorganik:
        return const Color(0xFF0EA5E9);
      case WasteCategory.b3:
        return const Color(0xFFEF4444);
      case WasteCategory.residu:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _itemPool[_currentItemIndex % _itemPool.length];
    final activeTargetBin = _getCurrentTargetBin();

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Icon(Icons.screen_rotation_rounded, color: Color(0xFF16A34A), size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Trash Sorter',
                style: AppTextStyles.titleMedium.copyWith(color: const Color(0xFF0F172A), fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Colors.amberAccent),
                const SizedBox(width: 4),
                Text(
                  '$_score XP',
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Floating Status Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Sampah ${_currentItemIndex + 1} / 8',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _streak >= 3 ? const Color(0xFFFEF3C7) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _streak >= 3 ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _streak >= 3 ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: _streak >= 3 ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Streak: $_streak',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _streak >= 3 ? const Color(0xFFB45309) : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_feedbackMessage != null && _isPlaying)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _feedbackColor ?? Colors.transparent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (_feedbackColor ?? Colors.transparent).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _feedbackMessage!,
                  style: TextStyle(color: _feedbackColor, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),

            // Drop Arena
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
                        colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isGameOver
                        ? _buildGameOverScreen()
                        : !_isPlaying
                            ? _buildStartScreen()
                            : _buildActivePlayArena(currentItem, activeTargetBin),
                  ),

                  // Confetti on finish
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

            // Manual Touch Fallback
            if (_isPlaying) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0284C7)),
                      onPressed: () => setState(() => _itemX = (_itemX - 0.25).clamp(-1.0, 1.0)),
                    ),
                    Expanded(
                      child: Text(
                        'Miringkan HP untuk mengarahkan ke tempat sampah',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0284C7)),
                      onPressed: () => setState(() => _itemX = (_itemX + 0.25).clamp(-1.0, 1.0)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.35), blurRadius: 20),
                ],
              ),
              child: const Icon(Icons.screen_rotation_rounded, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'TRASH SORTER',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Miringkan HP ke kiri atau kanan agar sampah jatuh ke tong yang tepat!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Mini Bin Preview using Wrap so it never overflows
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: _bins.map((b) {
                final color = _binColor(b);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    b.displayName,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Mulai Permainan', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFEF3C7),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 48, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ronde Pemilahan Selesai!',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Skor: $_score XP (+25 XP Bonus)',
              style: const TextStyle(color: Color(0xFF0284C7), fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Hebat! 8 jenis sampah telah dipilah dengan benar.',
              style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Main Lagi', style: TextStyle(fontWeight: FontWeight.w900)),
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePlayArena(SorterGameItem currentItem, WasteCategory targetBin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final arenaWidth = constraints.maxWidth;
        final arenaHeight = constraints.maxHeight;

        final itemPixelX = (arenaWidth / 2) + (_itemX * (arenaWidth * 0.4)) - 38;
        final itemPixelY = _itemY * (arenaHeight - 130);
        final itemColor = _binColor(currentItem.category);

        return Stack(
          children: [
            // Background grid guide
            CustomPaint(
              size: Size(arenaWidth, arenaHeight),
              painter: _ArenaGuidePainter(),
            ),

            // Targeting Laser Guide Line
            Positioned(
              left: itemPixelX + 38,
              top: itemPixelY + 50,
              bottom: 95,
              child: Container(
                width: 2.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      itemColor.withValues(alpha: 0.7),
                      itemColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),

            // Falling Waste Item (3D Capsule Token)
            Positioned(
              left: itemPixelX.clamp(12.0, (arenaWidth - 88.0).clamp(12.0, double.infinity)),
              top: itemPixelY.clamp(12.0, (arenaHeight - 130.0).clamp(12.0, double.infinity)),
              child: Transform.rotate(
                angle: _itemX * 0.25, // Natural physics tilt
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: itemColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: itemColor.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currentItem.icon, size: 28, color: itemColor),
                      const SizedBox(height: 4),
                      Text(
                        currentItem.name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Target Bins at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 98,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: _bins.map((cat) {
                    final color = _binColor(cat);
                    final isHighlighted = targetBin == cat;

                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? color.withValues(alpha: 0.22)
                              : color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isHighlighted ? color : color.withValues(alpha: 0.3),
                            width: isHighlighted ? 2.5 : 1.2,
                          ),
                          boxShadow: isHighlighted
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Bin Lid Indicator
                              Container(
                                width: 24,
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: isHighlighted ? color : color.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Icon(cat.icon, size: 22, color: color),
                              const SizedBox(height: 3),
                              Text(
                                cat.displayName,
                                style: TextStyle(
                                  color: isHighlighted ? color : const Color(0xFF334155),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArenaGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
