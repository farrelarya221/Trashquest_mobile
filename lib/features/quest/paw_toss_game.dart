import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import '../../services/sqlite_service.dart';
import '../../data/models/quest_challenge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Mengunci orientasi ke Landscape agar arena Kucing vs Anjing lebih luas & nyaman
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CatVsDogGameApp());
}

class CatVsDogGameApp extends StatelessWidget {
  const CatVsDogGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paw Toss: Anjing vs Kucing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorSchemeSeed: Colors.amber,
      ),
      home: const BackyardBattleScreen(),
    );
  }
}

/// Jenis-jenis benda yang bisa dilempar oleh Anjing & Kucing
enum ThrowableType {
  classic, // Tulang (Anjing) / Duri Ikan (Kucing)
  slipper, // Sandal Jepit (Cepat, ringan)
  basketball, // Bola Basket / Bola Benang (Memantul di tanah/pagar!)
  heavySplash, // Balon Air Jumbo / Kaleng (Berat, damage besar, area splash)
}

class ThrowableConfig {
  final ThrowableType type;
  final String dogItemName;
  final String catItemName;
  final String dogEmoji;
  final String catEmoji;
  final double baseDamage;
  final double gravityScale;
  final double windSensitivity;
  final double bounciness;
  final double radius;
  final Color trailColor;
  final String description;

  const ThrowableConfig({
    required this.type,
    required this.dogItemName,
    required this.catItemName,
    required this.dogEmoji,
    required this.catEmoji,
    required this.baseDamage,
    required this.gravityScale,
    required this.windSensitivity,
    required this.bounciness,
    required this.radius,
    required this.trailColor,
    required this.description,
  });
}

const List<ThrowableConfig> kArsenal = [
  ThrowableConfig(
    type: ThrowableType.classic,
    dogItemName: 'Tulang',
    catItemName: 'Ikan Asin',
    dogEmoji: '🦴',
    catEmoji: '🐟',
    baseDamage: 18,
    gravityScale: 1.0,
    windSensitivity: 1.0,
    bounciness: 0.25,
    radius: 16,
    trailColor: Color(0xFFFFB300),
    description: 'Seimbang & akurat',
  ),
  ThrowableConfig(
    type: ThrowableType.slipper,
    dogItemName: 'Sandal',
    catItemName: 'Sepatu',
    dogEmoji: '🩴',
    catEmoji: '👟',
    baseDamage: 15,
    gravityScale: 0.78,
    windSensitivity: 1.45,
    bounciness: 0.15,
    radius: 15,
    trailColor: Color(0xFF29B6F6),
    description: 'Ringan & terbang jauh',
  ),
  ThrowableConfig(
    type: ThrowableType.basketball,
    dogItemName: 'Basket',
    catItemName: 'Benang Wol',
    dogEmoji: '🏀',
    catEmoji: '🧶',
    baseDamage: 22,
    gravityScale: 1.05,
    windSensitivity: 0.85,
    bounciness: 0.72,
    radius: 19,
    trailColor: Color(0xFFFF7043),
    description: 'Memantul tinggi!',
  ),
  ThrowableConfig(
    type: ThrowableType.heavySplash,
    dogItemName: 'Balon Air',
    catItemName: 'Kaleng Susu',
    dogEmoji: '🎈',
    catEmoji: '🥫',
    baseDamage: 28,
    gravityScale: 1.32,
    windSensitivity: 0.5,
    bounciness: 0.05,
    radius: 21,
    trailColor: Color(0xFFAB47BC),
    description: 'Berat & Damage Besar',
  ),
];

/// Partikel visual untuk efek ledakan/benturan
class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life;
  double maxLife;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
  }) : maxLife = life;
}

/// Teks melayang saat terkena hit / meleset
class FloatingText {
  Offset position;
  String text;
  Color color;
  double life;
  double maxLife;

  FloatingText({
    required this.position,
    required this.text,
    required this.color,
    this.life = 1.2,
  }) : maxLife = life;
}

class BackyardBattleScreen extends StatefulWidget {
  const BackyardBattleScreen({super.key});

  @override
  State<BackyardBattleScreen> createState() => _BackyardBattleScreenState();
}

class _BackyardBattleScreenState extends State<BackyardBattleScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final math.Random _rng = math.Random();

  // State Mode & Giliran
  bool _vsAI = true;
  bool _isDogTurn = true; // true = Anjing (Kiri), false = Kucing (Kanan)
  bool _isAiming = false;
  bool _isProjectileFlying = false;
  bool _aiThinking = false;
  bool _isGameOver = false;
  bool _rewardAwarded = false;

  // Statistik Karakter
  double _dogHp = 100.0;
  double _catHp = 100.0;
  bool _dogHealUsed = false;
  bool _catHealUsed = false;
  bool _doubleDamageActive = false;
  bool _dogDoubleUsed = false;
  bool _catDoubleUsed = false;

  // Sistem Angin (-1.0 ke kiri s/d +1.0 ke kanan)
  double _wind = 0.15;

  // Senjata terpilih
  int _selectedWeaponIndex = 0;

  // State Bidikan Ketapel / Basketball Arc
  Offset? _dragStart;
  Offset? _dragCurrent;
  Offset _aimVelocity = Offset.zero;
  double _aimPowerPercent = 0.0;
  double _aimAngleDeg = 45.0;

  // State Proyektil Aktif
  Offset _projPos = Offset.zero;
  Offset _projVel = Offset.zero;
  double _projRotation = 0.0;
  int _projBounces = 0;
  final List<Offset> _projTrail = [];

  // Animasi & Efek Visual
  double _animTime = 0.0;
  double _fenceShake = 0.0;
  double _dogHitTimer = 0.0;
  double _catHitTimer = 0.0;
  final List<Particle> _particles = [];
  final List<FloatingText> _floatingTexts = [];

  // Ukuran Arena Terakhir
  Size _arenaSize = const Size(800, 400);

  // Konstanta Fisika
  static const double _baseGravity = 680.0; // px/s^2
  static const double _maxLaunchSpeed = 920.0; // px/s
  static const double _maxDragDistance = 150.0; // px

  @override
  void initState() {
    super.initState();
    // Kunci orientasi ke landscape dan mode immersive untuk kenyamanan bermain
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _randomizeWind();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Kembalikan ke orientasi portrait tegak dan edge-to-edge UI untuk aplikasi utama
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exitToApp() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleGameOverReward() {
    if (_rewardAwarded) return;
    _rewardAwarded = true;
    final bool dogWon = _catHp <= 0;
    final int xpEarned = dogWon ? 50 : 20;

    SupabaseService.instance.addXp(xpEarned);
    SqliteService.instance.incrementQuestProgressByType(QuestType.pawToss, amount: 1);
    NotificationService.instance.showNotification(
      title: dogWon ? '🏆 Kemenangan Paw Toss!' : '🎮 Sesi Paw Toss Selesai',
      body: dogWon
          ? 'Hebat! Bobi mengalahkan Mochi. Kamu meraih +$xpEarned XP!'
          : 'Pertarungan sengit! Kamu meraih +$xpEarned XP partisipasi.',
      icon: Icons.pets_rounded,
      iconColor: dogWon ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
    );
  }

  void _randomizeWind() {
    // Angin antara -0.85 s/d +0.85
    _wind = (_rng.nextDouble() * 1.7) - 0.85;
  }

  // Koordinat Penting Arena
  double get _groundY => _arenaSize.height * 0.80;
  double get _fenceX => _arenaSize.width * 0.50;
  double get _fenceWidth => 28.0;
  double get _fenceHeight => (_arenaSize.height * 0.34).clamp(115.0, 185.0);

  Offset get _dogPos => Offset(_arenaSize.width * 0.17, _groundY);
  Offset get _catPos => Offset(_arenaSize.width * 0.83, _groundY);

  Offset get _activeLauncherOrigin {
    final base = _isDogTurn ? _dogPos : _catPos;
    return Offset(base.dx + (_isDogTurn ? 18 : -18), base.dy - 48);
  }

  ThrowableConfig get _currentWeapon => kArsenal[_selectedWeaponIndex];

  void _onTick(Duration elapsed) {
    final double dt = _lastTick == Duration.zero
        ? 0.016
        : ((elapsed - _lastTick).inMicroseconds / 1000000.0).clamp(0.0, 0.05);
    _lastTick = elapsed;

    setState(() {
      _animTime += dt;
      if (_fenceShake > 0) _fenceShake = math.max(0, _fenceShake - dt * 5);
      if (_dogHitTimer > 0) _dogHitTimer = math.max(0, _dogHitTimer - dt);
      if (_catHitTimer > 0) _catHitTimer = math.max(0, _catHitTimer - dt);

      _updateParticles(dt);
      _updateFloatingTexts(dt);

      if (_isProjectileFlying) {
        _updateProjectile(dt);
      }
    });
  }

  void _updateParticles(double dt) {
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        _particles.removeAt(i);
      } else {
        p.velocity = Offset(p.velocity.dx, p.velocity.dy + 340 * dt);
        p.position += p.velocity * dt;
      }
    }
  }

  void _updateFloatingTexts(double dt) {
    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final ft = _floatingTexts[i];
      ft.life -= dt;
      if (ft.life <= 0) {
        _floatingTexts.removeAt(i);
      } else {
        ft.position = Offset(ft.position.dx, ft.position.dy - 38 * dt);
      }
    }
  }

  void _updateProjectile(double dt) {
    final weapon = _currentWeapon;
    final double gravity = _baseGravity * weapon.gravityScale;
    final double windAccel = _wind * 210.0 * weapon.windSensitivity;

    // Integrasi kecepatan & posisi
    _projVel = Offset(
      _projVel.dx + windAccel * dt,
      _projVel.dy + gravity * dt,
    );
    _projPos += _projVel * dt;
    _projRotation += (_projVel.dx * 0.012) * dt;

    // Simpan jejak ekor proyektil
    _projTrail.add(_projPos);
    if (_projTrail.length > 18) {
      _projTrail.removeAt(0);
    }

    // 1. Cek keluar batas kiri/kanan layar
    if (_projPos.dx < -60 || _projPos.dx > _arenaSize.width + 60) {
      _finishShot(missed: true);
      return;
    }

    // 2. Cek tabrakan dengan Pagar Rumah di tengah
    final Rect fenceRect = Rect.fromLTWH(
      _fenceX - _fenceWidth / 2,
      _groundY - _fenceHeight,
      _fenceWidth,
      _fenceHeight,
    );
    if (_circleIntersectsRect(_projPos, weapon.radius, fenceRect)) {
      _fenceShake = 1.0;
      _spawnBurst(_projPos, const Color(0xFF8D6E63), count: 16);

      if (weapon.bounciness >= 0.5 && _projBounces < 2) {
        // Bola basket / benang wol memantul dari pagar!
        _projBounces++;
        if ((_projPos.dy) < fenceRect.top + 12 && _projVel.dy > 0) {
          _projVel = Offset(_projVel.dx * 0.8, -_projVel.dy * weapon.bounciness);
          _projPos = Offset(_projPos.dx, fenceRect.top - weapon.radius - 1);
        } else {
          _projVel = Offset(-_projVel.dx * weapon.bounciness, _projVel.dy * 0.8);
          _projPos = Offset(
            _projPos.dx < _fenceX
                ? fenceRect.left - weapon.radius - 2
                : fenceRect.right + weapon.radius + 2,
            _projPos.dy,
          );
        }
        _addFloatingText(_projPos, 'PANTUL PAGAR!', Colors.orangeAccent);
        return;
      } else {
        _addFloatingText(_projPos, 'KENA PAGAR! 🪵', const Color(0xFFFFD54F));
        _finishShot(missed: true);
        return;
      }
    }

    // 3. Cek tabrakan dengan Karakter Lawan
    final Offset targetBase = _isDogTurn ? _catPos : _dogPos;
    final Offset targetCenter = Offset(targetBase.dx, targetBase.dy - 36);
    const double targetHitRadius = 34.0;

    final double distToTarget = (_projPos - targetCenter).distance;
    if (distToTarget <= weapon.radius + targetHitRadius) {
      _applyHitToTarget(targetCenter, directHit: true);
      return;
    }

    // 4. Cek tabrakan dengan Tanah (Ground)
    if (_projPos.dy + weapon.radius >= _groundY) {
      _projPos = Offset(_projPos.dx, _groundY - weapon.radius);

      // Jika bola memantul (Basket / Benang Wol)
      if (weapon.bounciness >= 0.5 &&
          _projBounces < 2 &&
          _projVel.dy.abs() > 140) {
        _projBounces++;
        _projVel = Offset(
          _projVel.dx * 0.78,
          -_projVel.dy * weapon.bounciness,
        );
        _spawnBurst(_projPos, weapon.trailColor, count: 10);
        return;
      }

      // Cek apakah senjata memiliki efek splash (Balon Air / Kaleng)
      if (weapon.type == ThrowableType.heavySplash &&
          (_projPos - targetCenter).distance <= 78.0) {
        _applyHitToTarget(targetCenter, directHit: false);
        return;
      }

      _spawnBurst(_projPos, const Color(0xFF7CB342), count: 14);
      _addFloatingText(_projPos, 'MELESET!', Colors.white70);
      _finishShot(missed: true);
    }
  }

  void _applyHitToTarget(Offset targetCenter, {required bool directHit}) {
    final weapon = _currentWeapon;
    double dmg = weapon.baseDamage;
    if (!directHit) {
      dmg = (dmg * 0.6).roundToDouble();
    }
    if (_doubleDamageActive) {
      dmg *= 1.5;
    }

    // Cek Headshot / Critical jika mengenai bagian atas kepala
    final bool isCritical = directHit && (_projPos.dy < targetCenter.dy - 10);
    if (isCritical) {
      dmg = (dmg * 1.25).roundToDouble();
    }

    setState(() {
      if (_isDogTurn) {
        _catHp = (_catHp - dmg).clamp(0.0, 100.0);
        _catHitTimer = 0.75;
      } else {
        _dogHp = (_dogHp - dmg).clamp(0.0, 100.0);
        _dogHitTimer = 0.75;
      }
    });

    _spawnBurst(
      _projPos,
      isCritical ? const Color(0xFFFF1744) : weapon.trailColor,
      count: 26,
    );

    final String label = isCritical
        ? 'HEADSHOT! -${dmg.toInt()} HP 🔥'
        : (directHit
            ? 'KENA! -${dmg.toInt()} HP 💥'
            : 'CIPRATAN! -${dmg.toInt()} HP 💦');

    _addFloatingText(
      Offset(targetCenter.dx, targetCenter.dy - 35),
      label,
      isCritical ? const Color(0xFFFF5252) : const Color(0xFFFFEB3B),
    );

    _finishShot(missed: false);
  }

  void _finishShot({required bool missed}) {
    _isProjectileFlying = false;
    _doubleDamageActive = false;
    _projTrail.clear();

    if (_dogHp <= 0 || _catHp <= 0) {
      _isGameOver = true;
      _handleGameOverReward();
      return;
    }

    // Ganti giliran & acak angin baru
    _isDogTurn = !_isDogTurn;
    _randomizeWind();

    // Jika lawan adalah AI Kucing, jadwalkan tembakan AI
    if (_vsAI && !_isDogTurn && !_isGameOver) {
      _aiThinking = true;
      Future.delayed(const Duration(milliseconds: 950), () {
        if (!mounted || _isGameOver) return;
        _executeAIShot();
      });
    }
  }

  /// Kalkulasi Balistik Pintar untuk AI Kucing melewati Pagar Rumah
  void _executeAIShot() {
    _aiThinking = false;
    // Pilih senjata secara acak untuk variasi
    _selectedWeaponIndex = _rng.nextInt(kArsenal.length);
    final weapon = _currentWeapon;

    final Offset start = _activeLauncherOrigin;
    final Offset target = Offset(_dogPos.dx, _dogPos.dy - 36);

    // Pilih waktu tempuh (time of flight) agar melambung melewati pagar tinggi
    final double flightTime = 1.28 + (_rng.nextDouble() * 0.25);
    final double gravity = _baseGravity * weapon.gravityScale;
    final double windAccel = _wind * 210.0 * weapon.windSensitivity;

    // Rumus kinematika: dx = vx*t + 0.5*ax*t^2  =>  vx = (dx - 0.5*ax*t^2) / t
    final double dx = target.dx - start.dx;
    final double dy = target.dy - start.dy;

    double vx = (dx - 0.5 * windAccel * flightTime * flightTime) / flightTime;
    double vy = (dy - 0.5 * gravity * flightTime * flightTime) / flightTime;

    // Tambahkan sedikit ketidakakuratan manusiawi agar seru
    vx += (_rng.nextDouble() * 56) - 28;
    vy += (_rng.nextDouble() * 44) - 22;

    _launchWithVelocity(Offset(vx, vy));
  }

  bool _circleIntersectsRect(Offset center, double radius, Rect rect) {
    final double closestX = center.dx.clamp(rect.left, rect.right);
    final double closestY = center.dy.clamp(rect.top, rect.bottom);
    final double dx = center.dx - closestX;
    final double dy = center.dy - closestY;
    return (dx * dx + dy * dy) <= (radius * radius);
  }

  void _spawnBurst(Offset center, Color color, {int count = 18}) {
    for (int i = 0; i < count; i++) {
      final double angle = _rng.nextDouble() * math.pi * 2;
      final double speed = 60 + _rng.nextDouble() * 220;
      _particles.add(
        Particle(
          position: center,
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed - 60),
          color: i.isEven ? color : Colors.white,
          size: 4 + _rng.nextDouble() * 6,
          life: 0.45 + _rng.nextDouble() * 0.4,
        ),
      );
    }
  }

  void _addFloatingText(Offset pos, String text, Color color) {
    _floatingTexts.add(FloatingText(position: pos, text: text, color: color));
  }

  // Gesture Handler untuk Membidik ala Ketapel / Basketball Trajectory
  void _onPanStart(DragStartDetails details) {
    if (_isProjectileFlying || _aiThinking || _isGameOver) return;
    if (_vsAI && !_isDogTurn) return;

    setState(() {
      _isAiming = true;
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
      _updateAimVector();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isAiming) return;
    setState(() {
      _dragCurrent = details.localPosition;
      _updateAimVector();
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isAiming) return;
    final velocity = _aimVelocity;
    final power = _aimPowerPercent;
    setState(() {
      _isAiming = false;
      _dragStart = null;
      _dragCurrent = null;
    });

    if (power >= 12.0) {
      _launchWithVelocity(velocity);
    }
  }

  void _updateAimVector() {
    if (_dragStart == null || _dragCurrent == null) return;
    // Tarik ke belakang untuk melontarkan ke depan (seperti ketapel / Angry Birds / Basketball)
    final Offset pullVector = _dragStart! - _dragCurrent!;
    final double rawDist = pullVector.distance;
    final double clampedDist = rawDist.clamp(0.0, _maxDragDistance);
    final double powerFactor = clampedDist / _maxDragDistance;

    if (rawDist < 4.0) {
      _aimVelocity = Offset.zero;
      _aimPowerPercent = 0.0;
      return;
    }

    final Offset dir = pullVector / rawDist;
    final double speed = (0.22 + 0.78 * powerFactor) * _maxLaunchSpeed;
    _aimVelocity = dir * speed;
    _aimPowerPercent = (powerFactor * 100).roundToDouble();

    // Hitung sudut elevasi relatif terhadap arah hadap
    final double horizontal = _isDogTurn ? dir.dx : -dir.dx;
    final double vertical = -dir.dy;
    _aimAngleDeg = (math.atan2(vertical, horizontal) * 180 / math.pi)
        .clamp(-45.0, 89.0);
  }

  void _launchWithVelocity(Offset velocity) {
    setState(() {
      _projPos = _activeLauncherOrigin;
      _projVel = velocity;
      _projRotation = 0.0;
      _projBounces = 0;
      _projTrail.clear();
      _isProjectileFlying = true;
    });
  }

  void _useHeal() {
    if (_isProjectileFlying || _aiThinking || _isGameOver) return;
    if (_isDogTurn && !_dogHealUsed && _dogHp < 100) {
      setState(() {
        _dogHealUsed = true;
        _dogHp = (_dogHp + 25).clamp(0.0, 100.0);
        _addFloatingText(
          Offset(_dogPos.dx, _dogPos.dy - 70),
          '+25 HP SNACK! 🍖',
          const Color(0xFF69F0AE),
        );
      });
    } else if (!_isDogTurn && !_catHealUsed && _catHp < 100) {
      setState(() {
        _catHealUsed = true;
        _catHp = (_catHp + 25).clamp(0.0, 100.0);
        _addFloatingText(
          Offset(_catPos.dx, _catPos.dy - 70),
          '+25 HP SUSU! 🥛',
          const Color(0xFF69F0AE),
        );
      });
    }
  }

  void _useDoublePower() {
    if (_isProjectileFlying || _aiThinking || _isGameOver || _doubleDamageActive) {
      return;
    }
    if (_isDogTurn && !_dogDoubleUsed) {
      setState(() {
        _dogDoubleUsed = true;
        _doubleDamageActive = true;
        _addFloatingText(
          Offset(_dogPos.dx, _dogPos.dy - 75),
          'POWER UP 1.5x! ⚡',
          Colors.amberAccent,
        );
      });
    } else if (!_isDogTurn && !_catDoubleUsed) {
      setState(() {
        _catDoubleUsed = true;
        _doubleDamageActive = true;
        _addFloatingText(
          Offset(_catPos.dx, _catPos.dy - 75),
          'POWER UP 1.5x! ⚡',
          Colors.amberAccent,
        );
      });
    }
  }

  void _resetGame() {
    setState(() {
      _rewardAwarded = false;
      _dogHp = 100.0;
      _catHp = 100.0;
      _dogHealUsed = false;
      _catHealUsed = false;
      _dogDoubleUsed = false;
      _catDoubleUsed = false;
      _doubleDamageActive = false;
      _isDogTurn = true;
      _isAiming = false;
      _isProjectileFlying = false;
      _aiThinking = false;
      _isGameOver = false;
      _particles.clear();
      _floatingTexts.clear();
      _projTrail.clear();
      _randomizeWind();
    });
  }

  /// Menghitung titik-titik lintasan parabola (seperti bidikan bola basket)
  List<Offset> _computeTrajectoryDots() {
    if (!_isAiming || _aimPowerPercent < 8) return const [];
    final List<Offset> dots = [];
    final Offset start = _activeLauncherOrigin;
    final weapon = _currentWeapon;
    final double gravity = _baseGravity * weapon.gravityScale;
    final double windAccel = _wind * 210.0 * weapon.windSensitivity;

    // Buat 20 titik prediksi lintasan parabola
    const int dotCount = 20;
    const double stepTime = 0.068;

    for (int i = 1; i <= dotCount; i++) {
      final double t = i * stepTime;
      final double x =
          start.dx + _aimVelocity.dx * t + 0.5 * windAccel * t * t;
      final double y = start.dy + _aimVelocity.dy * t + 0.5 * gravity * t * t;

      // Hentikan titik prediksi jika sudah menembus tanah
      if (y > _groundY) break;
      dots.add(Offset(x, y));
    }
    return dots;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            _arenaSize = Size(constraints.maxWidth, constraints.maxHeight);
            final trajectoryDots = _computeTrajectoryDots();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Stack(
                children: [
                  // 1. Canvas Utama Game (Langit, Pagar Rumah, Anjing, Kucing, Garis Titik-Titik Basket, Proyektil)
                  RepaintBoundary(
                    child: CustomPaint(
                      size: _arenaSize,
                      painter: BackyardArenaPainter(
                        animTime: _animTime,
                        groundY: _groundY,
                        fenceX: _fenceX,
                        fenceWidth: _fenceWidth,
                        fenceHeight: _fenceHeight,
                        fenceShake: _fenceShake,
                        dogPos: _dogPos,
                        catPos: _catPos,
                        isDogTurn: _isDogTurn,
                        isAiming: _isAiming,
                        dogHitTimer: _dogHitTimer,
                        catHitTimer: _catHitTimer,
                        trajectoryDots: trajectoryDots,
                        launcherOrigin: _activeLauncherOrigin,
                        dragStart: _dragStart,
                        dragCurrent: _dragCurrent,
                        aimPowerPercent: _aimPowerPercent,
                        aimAngleDeg: _aimAngleDeg,
                        isProjectileFlying: _isProjectileFlying,
                        projPos: _projPos,
                        projRotation: _projRotation,
                        projTrail: _projTrail,
                        weapon: _currentWeapon,
                        particles: _particles,
                        floatingTexts: _floatingTexts,
                        doubleDamageActive: _doubleDamageActive,
                      ),
                    ),
                  ),

                  // 2. Top HUD: Tombol Keluar + Health Bar Anjing & Kucing + Indikator Angin + Mode Switch
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tombol Keluar ke Menu Quest
                          Container(
                            height: 44,
                            width: 44,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                              tooltip: 'Kembali ke Quest',
                              onPressed: _exitToApp,
                            ),
                          ),

                          // Kartu Status Anjing (Kiri)
                          Expanded(
                            child: _buildFighterHudCard(
                              name: 'BOBI (ANJING)',
                              avatarEmoji: '🐶',
                              hp: _dogHp,
                              isActiveTurn: _isDogTurn && !_isGameOver,
                              primaryColor: const Color(0xFFFF8F00),
                              alignRight: false,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Panel Tengah: Indikator Angin & Tombol Mode
                          _buildCenterWindAndModePanel(),

                          const SizedBox(width: 12),
                          // Kartu Status Kucing (Kanan)
                          Expanded(
                            child: _buildFighterHudCard(
                              name: _vsAI ? 'MOCHI (AI)' : 'MOCHI (KUCING)',
                              avatarEmoji: '🐱',
                              hp: _catHp,
                              isActiveTurn: !_isDogTurn && !_isGameOver,
                              primaryColor: const Color(0xFFEC407A),
                              alignRight: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. Petunjuk Interaktif Saat Awal / Giliran
                if (!_isAiming && !_isProjectileFlying && !_isGameOver)
                  Positioned(
                    top: _arenaSize.height * 0.25,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            _aiThinking
                                ? '🐱 Kucing sedang mengincar melewati pagar...'
                                : (_isDogTurn
                                    ? '👉 Tarik layar (drag mundur) untuk mengatur lengkungan lemparan Anjing!'
                                    : '👉 Tarik layar (drag mundur) untuk mengatur lengkungan lemparan Kucing!'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. Bottom Dock: Pilihan Lemparan (Tulang, Sandal, Bola Basket, Balon Air) & Power-Up
                Positioned(
                  bottom: 10,
                  left: 16,
                  right: 16,
                  child: _buildBottomWeaponDock(),
                ),

                // 5. Overlay Modal Game Over
                if (_isGameOver) _buildGameOverModal(),
              ],
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildFighterHudCard({
    required String name,
    required String avatarEmoji,
    required double hp,
    required bool isActiveTurn,
    required Color primaryColor,
    required bool alignRight,
  }) {
    final Color hpColor = hp > 50
        ? const Color(0xFF00E676)
        : (hp > 25 ? const Color(0xFFFFEA00) : const Color(0xFFFF1744));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActiveTurn ? primaryColor : Colors.white24,
          width: isActiveTurn ? 2.5 : 1.2,
        ),
        boxShadow: isActiveTurn
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Row(
        textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 1.5),
            ),
            child: Text(avatarEmoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: alignRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: alignRight
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: hpColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${hp.toInt()} HP',
                        style: TextStyle(
                          color: hpColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        Container(color: Colors.white12),
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 300),
                          alignment: alignRight
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          widthFactor: (hp / 100.0).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [hpColor, primaryColor],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterWindAndModePanel() {
    final bool windRight = _wind >= 0;
    final int windStrength = (_wind.abs() * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.air, color: Colors.lightBlueAccent, size: 16),
              const SizedBox(width: 4),
              Text(
                'ANGIN $windStrength',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                windRight ? Icons.arrow_forward : Icons.arrow_back,
                color: Colors.amberAccent,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _vsAI = !_vsAI;
                    _resetGame();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _vsAI ? '🤖 1P vs AI' : '👥 2 Pemain',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _resetGame,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomWeaponDock() {
    final bool canInteract =
        !_isProjectileFlying && !_aiThinking && (!_vsAI || _isDogTurn);

    final bool healUsed = _isDogTurn ? _dogHealUsed : _catHealUsed;
    final bool doubleUsed = _isDogTurn ? _dogDoubleUsed : _catDoubleUsed;

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pilihan 4 Senjata Utama
              for (int i = 0; i < kArsenal.length; i++) ...[
                _buildWeaponChip(i, canInteract),
                const SizedBox(width: 8),
              ],
              Container(width: 1, height: 34, color: Colors.white24),
              const SizedBox(width: 8),

              // Tombol Power-Up 1.5x Damage
              _buildPowerUpButton(
                label: '1.5x DMG',
                emoji: '⚡',
                isUsed: doubleUsed,
                isActive: _doubleDamageActive,
                enabled: canInteract && !doubleUsed,
                color: Colors.amber,
                onTap: _useDoublePower,
              ),
              const SizedBox(width: 8),

              // Tombol Heal +25 HP
              _buildPowerUpButton(
                label: '+25 HP',
                emoji: _isDogTurn ? '🍖' : '🥛',
                isUsed: healUsed,
                isActive: false,
                enabled: canInteract && !healUsed,
                color: Colors.greenAccent,
                onTap: _useHeal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeaponChip(int index, bool canInteract) {
    final item = kArsenal[index];
    final bool isSelected = _selectedWeaponIndex == index;
    final String emoji = _isDogTurn ? item.dogEmoji : item.catEmoji;
    final String name = _isDogTurn ? item.dogItemName : item.catItemName;

    return GestureDetector(
      onTap: canInteract
          ? () => setState(() => _selectedWeaponIndex = index)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? item.trailColor.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? item.trailColor : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'DMG ${item.baseDamage.toInt()} • ${item.description}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerUpButton({
    required String label,
    required String emoji,
    required bool isUsed,
    required bool isActive,
    required bool enabled,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: isUsed && !isActive ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : Colors.white24,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? color : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverModal() {
    final bool dogWon = _catHp <= 0;
    final int xpEarned = dogWon ? 50 : 20;

    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      alignment: Alignment.center,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amberAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.25),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dogWon ? '🐶🎉' : '🐱👑',
              style: const TextStyle(fontSize: 52),
            ),
            const SizedBox(height: 10),
            Text(
              dogWon ? 'BOBI (ANJING) MENANG!' : 'MOCHI (KUCING) MENANG!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Text(
                '+$xpEarned XP Tersimpan ke Akun! 🌟',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dogWon
                  ? 'Lemparan jitu melewati pagar membuat Kucing menyerah!'
                  : 'Kucing berhasil membalas! Ayo coba lagi!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _exitToApp,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'KELUAR',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _resetGame,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text(
                      'MAIN LAGI',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter utama untuk menggambar seluruh dunia game, karakter, pagar,
/// serta garis titik-titik parabola ala tembakan bola basket.
class BackyardArenaPainter extends CustomPainter {
  final double animTime;
  final double groundY;
  final double fenceX;
  final double fenceWidth;
  final double fenceHeight;
  final double fenceShake;
  final Offset dogPos;
  final Offset catPos;
  final bool isDogTurn;
  final bool isAiming;
  final double dogHitTimer;
  final double catHitTimer;
  final List<Offset> trajectoryDots;
  final Offset launcherOrigin;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final double aimPowerPercent;
  final double aimAngleDeg;
  final bool isProjectileFlying;
  final Offset projPos;
  final double projRotation;
  final List<Offset> projTrail;
  final ThrowableConfig weapon;
  final List<Particle> particles;
  final List<FloatingText> floatingTexts;
  final bool doubleDamageActive;

  BackyardArenaPainter({
    required this.animTime,
    required this.groundY,
    required this.fenceX,
    required this.fenceWidth,
    required this.fenceHeight,
    required this.fenceShake,
    required this.dogPos,
    required this.catPos,
    required this.isDogTurn,
    required this.isAiming,
    required this.dogHitTimer,
    required this.catHitTimer,
    required this.trajectoryDots,
    required this.launcherOrigin,
    required this.dragStart,
    required this.dragCurrent,
    required this.aimPowerPercent,
    required this.aimAngleDeg,
    required this.isProjectileFlying,
    required this.projPos,
    required this.projRotation,
    required this.projTrail,
    required this.weapon,
    required this.particles,
    required this.floatingTexts,
    required this.doubleDamageActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSkyAndClouds(canvas, size);
    _drawBackyardHillsAndGrass(canvas, size);
    _drawWoodenFence(canvas);
    _drawDogCharacter(canvas);
    _drawCatCharacter(canvas);

    // Gambar garis titik-titik parabola ala Bola Basket saat membidik
    if (isAiming && trajectoryDots.isNotEmpty) {
      _drawBasketballTrajectoryArc(canvas);
    }

    // Gambar proyektil yang sedang terbang beserta trail-nya
    if (isProjectileFlying) {
      _drawFlyingProjectile(canvas);
    }

    _drawParticles(canvas);
    _drawFloatingTexts(canvas);
  }

  void _drawSkyAndClouds(Canvas canvas, Size size) {
    final Rect skyRect = Offset.zero & size;
    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF38BDF8),
          Color(0xFFBAE6FD),
          Color(0xFFFEF9C3),
        ],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // Matahari bersinar lembut
    final Offset sunCenter = Offset(size.width * 0.85, size.height * 0.18);
    canvas.drawCircle(
      sunCenter,
      36,
      Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      sunCenter,
      24,
      Paint()..color = const Color(0xFFFACC15),
    );

    // Awan bergerak perlahan
    final Paint cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78);
    for (int i = 0; i < 3; i++) {
      final double speed = 12.0 + i * 6.0;
      final double cx =
          ((size.width * (0.2 * i + 0.1)) + animTime * speed) %
              (size.width + 140) -
          70;
      final double cy = size.height * (0.16 + i * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: 88, height: 28),
          const Radius.circular(20),
        ),
        cloudPaint,
      );
      canvas.drawCircle(Offset(cx - 16, cy - 10), 16, cloudPaint);
      canvas.drawCircle(Offset(cx + 12, cy - 12), 20, cloudPaint);
    }
  }

  void _drawBackyardHillsAndGrass(Canvas canvas, Size size) {
    // Bukit halaman belakang
    final Path hillPath = Path()
      ..moveTo(0, groundY)
      ..quadraticBezierTo(
        size.width * 0.25,
        groundY - 45,
        size.width * 0.52,
        groundY,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        groundY - 38,
        size.width,
        groundY,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(hillPath, Paint()..color = const Color(0xFF86EFAC));

    // Rumput utama
    final Rect grassRect = Rect.fromLTWH(
      0,
      groundY,
      size.width,
      size.height - groundY,
    );
    final Paint grassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF22C55E),
          Color(0xFF15803D),
        ],
      ).createShader(grassRect);
    canvas.drawRect(grassRect, grassPaint);

    // Garis tepi rumput atas
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = const Color(0xFF166534)
        ..strokeWidth = 3,
    );
  }

  void _drawWoodenFence(Canvas canvas) {
    final double shakeOffset =
        fenceShake > 0 ? math.sin(animTime * 55) * 6 * fenceShake : 0.0;
    final double centerX = fenceX + shakeOffset;
    final double topY = groundY - fenceHeight;

    // Bayangan pagar
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, groundY + 4),
        width: fenceWidth * 2.1,
        height: 12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // Papan kayu utama
    final RRect postRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centerX - fenceWidth / 2,
        topY,
        fenceWidth,
        fenceHeight,
      ),
      const Radius.circular(6),
    );

    final Paint woodPaint = Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0xFFA16207),
          Color(0xFF78350F),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(postRect.outerRect);

    canvas.drawRRect(postRect, woodPaint);
    canvas.drawRRect(
      postRect,
      Paint()
        ..color = const Color(0xFF451A03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Ujung segitiga runcing di atas pagar rumah
    final Path roofTip = Path()
      ..moveTo(centerX - fenceWidth / 2 - 3, topY + 4)
      ..lineTo(centerX, topY - 18)
      ..lineTo(centerX + fenceWidth / 2 + 3, topY + 4)
      ..close();
    canvas.drawPath(roofTip, Paint()..color = const Color(0xFFB45309));
    canvas.drawPath(
      roofTip,
      Paint()
        ..color = const Color(0xFF451A03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Palang kayu horizontal & paku
    final Paint nailPaint = Paint()..color = const Color(0xFFD6D3D1);
    for (double yOffset in [0.28, 0.68]) {
      final double barY = topY + fenceHeight * yOffset;
      final Rect barRect = Rect.fromCenter(
        center: Offset(centerX, barY),
        width: fenceWidth + 14,
        height: 12,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF92400E),
      );
      canvas.drawCircle(Offset(centerX - 5, barY), 2.2, nailPaint);
      canvas.drawCircle(Offset(centerX + 5, barY), 2.2, nailPaint);
    }
  }

  void _drawDogCharacter(Canvas canvas) {
    final double bounce = math.sin(animTime * 4.2) * 3.0;
    final Offset center = Offset(dogPos.dx, dogPos.dy - 32 + bounce);

    // Indikator lingkaran giliran aktif di bawah kaki
    if (isDogTurn) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dogPos.dx, groundY + 4),
          width: 76,
          height: 18,
        ),
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.save();
    if (dogHitTimer > 0) {
      canvas.translate(math.sin(animTime * 50) * 5, 0);
    }

    // Badan Anjing
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx - 4, center.dy + 14),
          width: 44,
          height: 36,
        ),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFD97706),
    );

    // Kepala Anjing
    canvas.drawCircle(
      Offset(center.dx, center.dy - 8),
      23,
      Paint()..color = const Color(0xFFF59E0B),
    );

    // Telinga terkulai (Floppy Ears)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - 18, center.dy - 4),
        width: 14,
        height: 26,
      ),
      Paint()..color = const Color(0xFF78350F),
    );

    // Moncong (Snout)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 14, center.dy - 4),
        width: 20,
        height: 15,
      ),
      Paint()..color = const Color(0xFFFEF3C7),
    );
    // Hidung hitam
    canvas.drawCircle(
      Offset(center.dx + 22, center.dy - 7),
      4.5,
      Paint()..color = const Color(0xFF1C1917),
    );

    // Mata Anjing
    if (dogHitTimer > 0) {
      // Mata X saat kena lemparan
      _drawCrossEye(canvas, Offset(center.dx + 6, center.dy - 14));
    } else {
      canvas.drawCircle(
        Offset(center.dx + 6, center.dy - 14),
        4.2,
        Paint()..color = Colors.black,
      );
      canvas.drawCircle(
        Offset(center.dx + 7.5, center.dy - 15.5),
        1.5,
        Paint()..color = Colors.white,
      );
    }

    // Kalung merah
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + 1, center.dy + 7),
          width: 34,
          height: 6,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFEF4444),
    );

    canvas.restore();
  }

  void _drawCatCharacter(Canvas canvas) {
    final double bounce = math.sin(animTime * 4.2 + 1.5) * 3.0;
    final Offset center = Offset(catPos.dx, catPos.dy - 30 + bounce);

    if (!isDogTurn) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(catPos.dx, groundY + 4),
          width: 76,
          height: 18,
        ),
        Paint()..color = const Color(0xFFEC407A).withValues(alpha: 0.55),
      );
    }

    canvas.save();
    if (catHitTimer > 0) {
      canvas.translate(math.sin(animTime * 50) * 5, 0);
    }

    // Ekor Kucing melengkung
    final Path tailPath = Path()
      ..moveTo(center.dx + 16, center.dy + 18)
      ..quadraticBezierTo(
        center.dx + 38,
        center.dy + 2,
        center.dx + 28,
        center.dy - 18,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = const Color(0xFFFB7185)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Badan Kucing
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + 3, center.dy + 14),
          width: 40,
          height: 34,
        ),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFF43F5E),
    );

    // Telinga Runcing Segitiga Kucing
    final Path leftEar = Path()
      ..moveTo(center.dx - 16, center.dy - 18)
      ..lineTo(center.dx - 8, center.dy - 36)
      ..lineTo(center.dx + 2, center.dy - 22)
      ..close();
    final Path rightEar = Path()
      ..moveTo(center.dx + 2, center.dy - 22)
      ..lineTo(center.dx + 14, center.dy - 36)
      ..lineTo(center.dx + 18, center.dy - 16)
      ..close();
    canvas.drawPath(leftEar, Paint()..color = const Color(0xFFF43F5E));
    canvas.drawPath(rightEar, Paint()..color = const Color(0xFFF43F5E));

    // Kepala Kucing
    canvas.drawCircle(
      Offset(center.dx, center.dy - 8),
      21,
      Paint()..color = const Color(0xFFFB7185),
    );

    // Mata & Kumis Kucing
    if (catHitTimer > 0) {
      _drawCrossEye(canvas, Offset(center.dx - 7, center.dy - 12));
    } else {
      canvas.drawCircle(
        Offset(center.dx - 7, center.dy - 12),
        4.0,
        Paint()..color = const Color(0xFF1E293B),
      );
      canvas.drawCircle(
        Offset(center.dx - 8, center.dy - 13.5),
        1.4,
        Paint()..color = Colors.white,
      );
    }

    // Hidung pink kecil & kumis
    canvas.drawCircle(
      Offset(center.dx - 16, center.dy - 6),
      3.2,
      Paint()..color = const Color(0xFFFCE7F3),
    );
    final Paint whiskerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.6;
    canvas.drawLine(
      Offset(center.dx - 12, center.dy - 4),
      Offset(center.dx - 27, center.dy - 7),
      whiskerPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 12, center.dy - 2),
      Offset(center.dx - 27, center.dy - 1),
      whiskerPaint,
    );

    canvas.restore();
  }

  void _drawCrossEye(Canvas canvas, Offset pos) {
    final Paint p = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pos + const Offset(-4, -4), pos + const Offset(4, 4), p);
    canvas.drawLine(pos + const Offset(4, -4), pos + const Offset(-4, 4), p);
  }

  /// Menggambar lintasan titik-titik melengkung seperti bidikan Bola Basket (Basketball Shot Arc)
  void _drawBasketballTrajectoryArc(Canvas canvas) {
    // 1. Gambar garis tarik ketapel di jari (jika ada)
    if (dragStart != null && dragCurrent != null) {
      canvas.drawCircle(
        dragStart!,
        18,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        dragStart!,
        dragCurrent!,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.7)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        dragCurrent!,
        10,
        Paint()..color = Colors.amberAccent,
      );
    }

    // 2. Gambar titik-titik lintasan melengkung (parabola) dari tangan pelempar
    for (int i = 0; i < trajectoryDots.length; i++) {
      final Offset dotPos = trajectoryDots[i];
      final double progress = i / trajectoryDots.length;
      final double radius = (7.5 * (1.0 - progress * 0.55)).clamp(2.5, 8.0);
      final double alpha = (1.0 - progress * 0.65).clamp(0.2, 1.0);

      // Glow luar
      canvas.drawCircle(
        dotPos,
        radius + 3.5,
        Paint()
          ..color = weapon.trailColor.withValues(alpha: alpha * 0.38)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Inti titik putih-kuning terang seperti indikator tembakan basket
      canvas.drawCircle(
        dotPos,
        radius,
        Paint()
          ..color = (i.isEven ? Colors.white : weapon.trailColor)
              .withValues(alpha: alpha),
      );
    }

    // 3. Target Ring / Reticle di ujung titik prediksi terakhir
    if (trajectoryDots.isNotEmpty) {
      final Offset endDot = trajectoryDots.last;
      canvas.drawCircle(
        endDot,
        13,
        Paint()
          ..color = weapon.trailColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    // 4. Badge Power % & Sudut di dekat karakter yang sedang membidik
    final String badgeText =
        'POWER ${aimPowerPercent.toInt()}%  •  ${aimAngleDeg.toInt()}°';
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final Offset badgePos = Offset(
      launcherOrigin.dx - tp.width / 2,
      launcherOrigin.dy - 52,
    );
    final RRect badgeBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        badgePos.dx - 8,
        badgePos.dy - 4,
        tp.width + 16,
        tp.height + 8,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      badgeBg,
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      badgeBg,
      Paint()
        ..color = weapon.trailColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    tp.paint(canvas, badgePos);
  }

  void _drawFlyingProjectile(Canvas canvas) {
    // Gambar jejak ekor (trail)
    for (int i = 0; i < projTrail.length; i++) {
      final double ratio = (i + 1) / projTrail.length;
      canvas.drawCircle(
        projTrail[i],
        weapon.radius * 0.55 * ratio,
        Paint()
          ..color = (doubleDamageActive ? Colors.amberAccent : weapon.trailColor)
              .withValues(alpha: ratio * 0.45),
      );
    }

    // Lingkaran aura proyektil
    canvas.drawCircle(
      projPos,
      weapon.radius + 4,
      Paint()
        ..color = (doubleDamageActive ? Colors.redAccent : weapon.trailColor)
            .withValues(alpha: 0.35),
    );

    // Gambar emoji proyektil berputar
    canvas.save();
    canvas.translate(projPos.dx, projPos.dy);
    canvas.rotate(projRotation);

    final String emoji = isDogTurn ? weapon.dogEmoji : weapon.catEmoji;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: weapon.radius * 1.65),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawParticles(Canvas canvas) {
    for (final p in particles) {
      final double alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.position,
        p.size * alpha,
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in floatingTexts) {
      final double alpha = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withValues(alpha: alpha),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: alpha * 0.8),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(ft.position.dx - tp.width / 2, ft.position.dy));
    }
  }

  @override
  bool shouldRepaint(covariant BackyardArenaPainter oldDelegate) => true;
}