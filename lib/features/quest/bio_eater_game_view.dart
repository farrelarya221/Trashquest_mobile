// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../../app/theme/app_text_styles.dart';
import '../../services/supabase_service.dart';

// ==========================================
// MODELS UNTUK ENTITAS MIKRO-DUNIA
// ==========================================

enum PlasticType { petShard, nanoPellet, synthFiber, capFragment }
enum HazardType { acidToxin, spikedMetal, virusCluster }
enum PowerUpType { hyperEnzyme, bioShield, magnetVortex }

class MicroPlastic {
  final int id;
  double x, y;
  double vx, vy;
  double size;
  double rotation;
  double rotSpeed;
  final PlasticType type;
  final Color color;
  final int score;
  final double energy;
  double shimmer;

  MicroPlastic({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotSpeed,
    required this.type,
    required this.color,
    required this.score,
    required this.energy,
    this.shimmer = 0,
  });
}

class HazardToxin {
  final int id;
  double x, y;
  double vx, vy;
  double radius;
  double pulse;
  final HazardType type;
  final Color color;

  HazardToxin({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.type,
    required this.color,
    this.pulse = 0,
  });
}

class PowerUpItem {
  final int id;
  double x, y;
  double pulse;
  final PowerUpType type;

  PowerUpItem({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
    this.pulse = 0,
  });
}

class BioParticle {
  double x, y;
  double vx, vy;
  Color color;
  double size;
  double opacity;
  final double maxLife;
  double life;

  BioParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    this.opacity = 1.0,
    required this.maxLife,
  }) : life = maxLife;
}

class ShockwaveRing {
  double x, y;
  double radius;
  final double maxRadius;
  final Color color;
  double opacity;

  ShockwaveRing({
    required this.x,
    required this.y,
    required this.radius,
    required this.maxRadius,
    required this.color,
    this.opacity = 1.0,
  });
}

class FloatingTextEffect {
  double x, y;
  final String text;
  final Color color;
  double opacity;
  double vy;

  FloatingTextEffect({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.opacity = 1.0,
    this.vy = -1.5,
  });
}

// ==========================================
// MAIN GAME VIEW
// ==========================================

class BioEaterGameView extends StatefulWidget {
  const BioEaterGameView({super.key});

  @override
  State<BioEaterGameView> createState() => _BioEaterGameViewState();
}

class _BioEaterGameViewState extends State<BioEaterGameView>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late ConfettiController _confettiController;
  final Random _rng = Random();

  // Dimensi Game
  Size _screenSize = Size.zero;

  // Organisme Pemain (Ideonella sakaiensis)
  double _playerX = 200;
  double _playerY = 400;
  double _playerVx = 0;
  double _playerVy = 0;
  double _targetX = 200;
  double _targetY = 400;
  double _playerRadius = 26.0;
  double _wobblePhase = 0;
  int _playerLevel = 1; // 1: Spora, 2: Ciliate, 3: Titan
  bool _shieldActive = false;
  double _shieldDuration = 0;
  bool _magnetActive = false;
  double _magnetDuration = 0;
  double _boostCooldown = 0;
  bool _isBoosting = false;
  double _boostTimer = 0;

  // Trail
  final List<Offset> _trail = [];

  // Entitas
  final List<MicroPlastic> _plastics = [];
  final List<HazardToxin> _hazards = [];
  final List<PowerUpItem> _powerUps = [];
  final List<BioParticle> _particles = [];
  final List<ShockwaveRing> _shockwaves = [];
  final List<FloatingTextEffect> _floatingTexts = [];

  // Supernova Skill
  double _supernovaCharge = 0.0; // 0.0 to 1.0
  bool _isSupernovaActive = false;
  double _supernovaTimer = 0.0;

  // Skor & Status Permainan
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isPaused = false;
  int _score = 0;
  double _microplasticGrams = 0.0;
  int _combo = 0;
  double _comboTimer = 0;
  int _lives = 3;
  int _secondsElapsed = 0;
  double _secondCounter = 0;

  // Screen Shake
  double _screenShakeX = 0;
  double _screenShakeY = 0;
  double _shakeIntensity = 0;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _startGame() {
    _plastics.clear();
    _hazards.clear();
    _powerUps.clear();
    _particles.clear();
    _shockwaves.clear();
    _floatingTexts.clear();
    _trail.clear();

    _playerX = _screenSize.width / 2;
    _playerY = _screenSize.height / 2;
    _targetX = _playerX;
    _targetY = _playerY;
    _playerVx = 0;
    _playerVy = 0;
    _playerRadius = 26.0;
    _playerLevel = 1;

    _score = 0;
    _microplasticGrams = 0;
    _combo = 0;
    _comboTimer = 0;
    _lives = 3;
    _supernovaCharge = 0.35; // Beri modal awal 35%
    _isSupernovaActive = false;
    _shieldActive = false;
    _magnetActive = false;
    _isBoosting = false;
    _boostCooldown = 0;
    _secondsElapsed = 0;
    _secondCounter = 0;

    _spawnInitialBatch();

    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _isPaused = false;
    });

    _ticker.start();
  }

  void _spawnInitialBatch() {
    for (int i = 0; i < 14; i++) {
      _spawnPlastic();
    }
    for (int i = 0; i < 3; i++) {
      _spawnHazard();
    }
  }

  void _spawnPlastic() {
    if (_screenSize.width <= 0) return;
    final typeIndex = _rng.nextInt(PlasticType.values.length);
    final type = PlasticType.values[typeIndex];

    Color color;
    int score;
    double energy;
    double size;

    switch (type) {
      case PlasticType.petShard:
        color = const Color(0xFF06B6D4); // Cyan
        score = 15;
        energy = 0.08;
        size = 14 + _rng.nextDouble() * 6;
        break;
      case PlasticType.nanoPellet:
        color = const Color(0xFF10B981); // Emerald
        score = 10;
        energy = 0.05;
        size = 11 + _rng.nextDouble() * 5;
        break;
      case PlasticType.synthFiber:
        color = const Color(0xFFA855F7); // Violet
        score = 25;
        energy = 0.12;
        size = 16 + _rng.nextDouble() * 8;
        break;
      case PlasticType.capFragment:
        color = const Color(0xFFF59E0B); // Amber
        score = 30;
        energy = 0.15;
        size = 18 + _rng.nextDouble() * 8;
        break;
    }

    _plastics.add(
      MicroPlastic(
        id: DateTime.now().microsecondsSinceEpoch + _rng.nextInt(9999),
        x: _rng.nextDouble() * (_screenSize.width - 40) + 20,
        y: _rng.nextDouble() * (_screenSize.height - 120) + 60,
        vx: (_rng.nextDouble() - 0.5) * 1.2,
        vy: (_rng.nextDouble() - 0.5) * 1.2,
        size: size,
        rotation: _rng.nextDouble() * 2 * pi,
        rotSpeed: (_rng.nextDouble() - 0.5) * 0.06,
        type: type,
        color: color,
        score: score,
        energy: energy,
      ),
    );
  }

  void _spawnHazard() {
    if (_screenSize.width <= 0) return;
    final typeIndex = _rng.nextInt(HazardType.values.length);
    final type = HazardType.values[typeIndex];

    _hazards.add(
      HazardToxin(
        id: DateTime.now().microsecondsSinceEpoch + _rng.nextInt(9999),
        x: _rng.nextDouble() * (_screenSize.width - 60) + 30,
        y: _rng.nextDouble() * (_screenSize.height - 140) + 70,
        vx: (_rng.nextDouble() - 0.5) * 1.4,
        vy: (_rng.nextDouble() - 0.5) * 1.4,
        radius: 18 + _rng.nextDouble() * 10,
        type: type,
        color: const Color(0xFFEF4444),
      ),
    );
  }

  void _spawnPowerUp() {
    if (_screenSize.width <= 0 || _powerUps.isNotEmpty) return;
    final typeIndex = _rng.nextInt(PowerUpType.values.length);
    _powerUps.add(
      PowerUpItem(
        id: DateTime.now().microsecondsSinceEpoch,
        x: _rng.nextDouble() * (_screenSize.width - 80) + 40,
        y: _rng.nextDouble() * (_screenSize.height - 180) + 90,
        type: PowerUpType.values[typeIndex],
      ),
    );
  }

  // ==========================================
  // GAME LOOP (TICK)
  // ==========================================
  void _onTick(Duration elapsed) {
    if (!_isPlaying || _isPaused) return;

    _wobblePhase += 0.08;

    // Timer waktu
    _secondCounter += 1 / 60;
    if (_secondCounter >= 1.0) {
      _secondCounter = 0;
      _secondsElapsed++;
      // Spawn bertahap
      if (_plastics.length < 18) _spawnPlastic();
      if (_secondsElapsed % 8 == 0 && _hazards.length < 5) _spawnHazard();
      if (_secondsElapsed % 12 == 0) _spawnPowerUp();
    }

    // Boost & Shield Timer
    if (_boostCooldown > 0) _boostCooldown -= 1 / 60;
    if (_isBoosting) {
      _boostTimer -= 1 / 60;
      if (_boostTimer <= 0) _isBoosting = false;
    }
    if (_shieldActive) {
      _shieldDuration -= 1 / 60;
      if (_shieldDuration <= 0) _shieldActive = false;
    }
    if (_magnetActive) {
      _magnetDuration -= 1 / 60;
      if (_magnetDuration <= 0) _magnetActive = false;
    }

    // Screen shake decay
    if (_shakeIntensity > 0) {
      _screenShakeX = (_rng.nextDouble() - 0.5) * _shakeIntensity;
      _screenShakeY = (_rng.nextDouble() - 0.5) * _shakeIntensity;
      _shakeIntensity *= 0.88;
      if (_shakeIntensity < 0.5) {
        _shakeIntensity = 0;
        _screenShakeX = 0;
        _screenShakeY = 0;
      }
    }

    // Supernova Timer
    if (_isSupernovaActive) {
      _supernovaTimer -= 1 / 60;
      _shakeIntensity = 4.0;
      if (_supernovaTimer <= 0) {
        _isSupernovaActive = false;
      }
    }

    // Update Combo Timer
    if (_combo > 0) {
      _comboTimer -= 1 / 60;
      if (_comboTimer <= 0) {
        _combo = 0;
      }
    }

    // Pergerakan Pemain dengan Fluid Inertia
    final dx = _targetX - _playerX;
    final dy = _targetY - _playerY;
    final dist = sqrt(dx * dx + dy * dy);

    final speedMultiplier = _isBoosting ? 2.4 : 1.0;
    if (dist > 4) {
      final angle = atan2(dy, dx);
      final moveSpeed = min(dist * 0.12, 7.0 * speedMultiplier);
      _playerVx = cos(angle) * moveSpeed;
      _playerVy = sin(angle) * moveSpeed;
    } else {
      _playerVx *= 0.85;
      _playerVy *= 0.85;
    }

    _playerX += _playerVx;
    _playerY += _playerVy;

    // Batas Arena (Clamp)
    final minX = _playerRadius + 12;
    final maxX = _screenSize.width - _playerRadius - 12;
    final minY = _playerRadius + 60;
    final maxY = _screenSize.height - _playerRadius - 70;

    _playerX = _playerX.clamp(minX, maxX);
    _playerY = _playerY.clamp(minY, maxY);

    // Update Trail
    if (_playerVx.abs() > 0.4 || _playerVy.abs() > 0.4) {
      _trail.insert(0, Offset(_playerX, _playerY));
      if (_trail.length > 18) _trail.removeLast();
    } else if (_trail.isNotEmpty) {
      _trail.removeLast();
    }

    // Partikel saat boost
    if (_isBoosting) {
      _spawnBoostParticles();
    }

    // Update Shockwaves
    for (int i = _shockwaves.length - 1; i >= 0; i--) {
      final sw = _shockwaves[i];
      sw.radius += 12;
      sw.opacity = (1.0 - (sw.radius / sw.maxRadius)).clamp(0.0, 1.0);
      if (sw.radius >= sw.maxRadius) {
        _shockwaves.removeAt(i);
      }
    }

    // Update Floating Texts
    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final ft = _floatingTexts[i];
      ft.y += ft.vy;
      ft.opacity -= 0.03;
      if (ft.opacity <= 0) {
        _floatingTexts.removeAt(i);
      }
    }

    // Update Particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 1 / 60;
      p.opacity = (p.life / p.maxLife).clamp(0.0, 1.0);
      if (p.life <= 0) {
        _particles.removeAt(i);
      }
    }

    // Update Hazards & Cek Tabrakan dengan Pemain
    for (int i = _hazards.length - 1; i >= 0; i--) {
      final h = _hazards[i];
      h.x += h.vx;
      h.y += h.vy;
      h.pulse += 0.05;

      // Pantulan dinding
      if (h.x - h.radius < 10 || h.x + h.radius > _screenSize.width - 10) {
        h.vx = -h.vx;
      }
      if (h.y - h.radius < 50 || h.y + h.radius > _screenSize.height - 60) {
        h.vy = -h.vy;
      }

      // Jika Supernova aktif: Racun hancur dan jadi poin!
      if (_isSupernovaActive) {
        final distH = sqrt(pow(h.x - _playerX, 2) + pow(h.y - _playerY, 2));
        if (distH < 220) {
          _explodeHazard(h);
          _hazards.removeAt(i);
          continue;
        }
      }

      // Tabrakan dengan Pemain
      final distPlayer =
          sqrt(pow(h.x - _playerX, 2) + pow(h.y - _playerY, 2));
      if (distPlayer < _playerRadius + h.radius) {
        if (_shieldActive) {
          // Shield pecah menyelamatkan pemain
          _shieldActive = false;
          _triggerShockwave(h.x, h.y, const Color(0xFF38BDF8), 80);
          _showFloatingText('SHIELD BLOCK!', const Color(0xFF38BDF8));
          _hazards.removeAt(i);
          HapticFeedback.mediumImpact();
        } else if (!_isSupernovaActive) {
          // Terkena racun
          _takeDamage();
          _hazards.removeAt(i);
        }
      }
    }

    // Update Mikroplastik & Magnet & Konsumsi
    final magnetEffective = _magnetActive || _isSupernovaActive;
    final magnetRadius = _isSupernovaActive ? 300.0 : 160.0;

    for (int i = _plastics.length - 1; i >= 0; i--) {
      final p = _plastics[i];
      p.x += p.vx;
      p.y += p.vy;
      p.rotation += p.rotSpeed;
      p.shimmer += 0.05;

      // Pantul dinding lembut
      if (p.x < 15 || p.x > _screenSize.width - 15) p.vx = -p.vx;
      if (p.y < 55 || p.y > _screenSize.height - 65) p.vy = -p.vy;

      // Efek Magnet / Supernova Sedot
      final distToPlayer =
          sqrt(pow(p.x - _playerX, 2) + pow(p.y - _playerY, 2));
      if (magnetEffective && distToPlayer < magnetRadius) {
        final angle = atan2(_playerY - p.y, _playerX - p.x);
        final pullForce = _isSupernovaActive ? 9.0 : 4.5;
        p.vx += cos(angle) * pullForce * 0.15;
        p.vy += sin(angle) * pullForce * 0.15;
      }

      // Deteksi Dimakan Organisme
      if (distToPlayer < _playerRadius + p.size * 0.7) {
        _consumePlastic(p);
        _plastics.removeAt(i);
      }
    }

    // Update PowerUps
    for (int i = _powerUps.length - 1; i >= 0; i--) {
      final pu = _powerUps[i];
      pu.pulse += 0.08;
      final distToPlayer =
          sqrt(pow(pu.x - _playerX, 2) + pow(pu.y - _playerY, 2));
      if (distToPlayer < _playerRadius + 22) {
        _collectPowerUp(pu);
        _powerUps.removeAt(i);
      }
    }

    setState(() {});
  }

  // ==========================================
  // LOGIKA AKSI & EFEK VISUAL MENGGELEGAR
  // ==========================================

  void _consumePlastic(MicroPlastic p) {
    _combo++;
    _comboTimer = 2.5;

    final multiplier = (_combo >= 10)
        ? 3
        : (_combo >= 5)
            ? 2
            : 1;
    final gainedScore = p.score * multiplier;

    _score += gainedScore;
    _microplasticGrams += (p.size * 0.8) / 10;

    // Supernova charge
    _supernovaCharge = (_supernovaCharge + p.energy).clamp(0.0, 1.0);

    // Pertumbuhan Organisme
    if (_playerRadius < 44.0) {
      _playerRadius += 0.25;
    }

    // Evolusi Organisme
    if (_score >= 500 && _playerLevel < 3) {
      _playerLevel = 3;
      _triggerEvolutionEffects('TITAN BIO-ORGANISM!');
    } else if (_score >= 200 && _playerLevel < 2) {
      _playerLevel = 2;
      _triggerEvolutionEffects('CILIATE ADVANCED!');
    }

    // Semburan Partikel Menggelegar
    _spawnEatParticles(p.x, p.y, p.color);

    // Text mengambang
    if (multiplier > 1) {
      _showFloatingText('+$gainedScore x$multiplier', p.color);
    } else {
      _showFloatingText('+$gainedScore', p.color);
    }

    HapticFeedback.lightImpact();

    // Spawn pengganti segera
    if (_plastics.length < 14) {
      _spawnPlastic();
    }
  }

  void _triggerEvolutionEffects(String title) {
    _triggerShockwave(_playerX, _playerY, const Color(0xFFF59E0B), 250);
    _shakeIntensity = 6.0;
    _showFloatingText(title, const Color(0xFFF59E0B));
    HapticFeedback.heavyImpact();
  }

  void _explodeHazard(HazardToxin h) {
    _score += 40;
    _showFloatingText('+40 LIMBAH TERURAI!', const Color(0xFF10B981));
    _triggerShockwave(h.x, h.y, const Color(0xFF10B981), 120);

    for (int i = 0; i < 20; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = _rng.nextDouble() * 5 + 2;
      _particles.add(
        BioParticle(
          x: h.x,
          y: h.y,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: const Color(0xFF10B981),
          size: _rng.nextDouble() * 4 + 2,
          maxLife: 0.6,
        ),
      );
    }
  }

  void _collectPowerUp(PowerUpItem pu) {
    HapticFeedback.mediumImpact();
    switch (pu.type) {
      case PowerUpType.hyperEnzyme:
        _supernovaCharge = 1.0;
        _showFloatingText('FULL ENZYME CHARGE!', const Color(0xFFF59E0B));
        _triggerShockwave(pu.x, pu.y, const Color(0xFFF59E0B), 140);
        break;
      case PowerUpType.bioShield:
        _shieldActive = true;
        _shieldDuration = 10.0;
        _showFloatingText('BIO-SHIELD 10S!', const Color(0xFF38BDF8));
        _triggerShockwave(pu.x, pu.y, const Color(0xFF38BDF8), 120);
        break;
      case PowerUpType.magnetVortex:
        _magnetActive = true;
        _magnetDuration = 8.0;
        _showFloatingText('VACUUM VORTEX!', const Color(0xFFA855F7));
        _triggerShockwave(pu.x, pu.y, const Color(0xFFA855F7), 120);
        break;
    }
  }

  void _takeDamage() {
    _lives--;
    _combo = 0;
    _shakeIntensity = 10.0;
    _playerRadius = max(24.0, _playerRadius - 3.0);

    _triggerShockwave(_playerX, _playerY, const Color(0xFFEF4444), 160);
    _showFloatingText('-1 BIO-LIFE!', const Color(0xFFEF4444));
    HapticFeedback.heavyImpact();

    if (_lives <= 0) {
      _endGame();
    }
  }

  // ULTIMATE: ENZYME SUPERNOVA (MENGGELEGAR)
  void _activateSupernova() {
    if (_supernovaCharge < 1.0 || _isSupernovaActive) return;

    setState(() {
      _supernovaCharge = 0.0;
      _isSupernovaActive = true;
      _supernovaTimer = 3.5;
      _shakeIntensity = 14.0;
    });

    HapticFeedback.heavyImpact();
    _triggerShockwave(_playerX, _playerY, const Color(0xFF06B6D4), 360);
    _triggerShockwave(_playerX, _playerY, const Color(0xFFF59E0B), 280);
    _showFloatingText('⚡ ENZYME SUPERNOVA ACTIVATED!', const Color(0xFF06B6D4));

    // Ledakan 100+ partikel plasma
    for (int i = 0; i < 90; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = _rng.nextDouble() * 8 + 3;
      final color = i % 2 == 0
          ? const Color(0xFF06B6D4)
          : (i % 3 == 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
      _particles.add(
        BioParticle(
          x: _playerX,
          y: _playerY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: color,
          size: _rng.nextDouble() * 5 + 3,
          maxLife: 1.0 + _rng.nextDouble() * 0.5,
        ),
      );
    }
  }

  void _activateBoost() {
    if (_boostCooldown > 0 || _isBoosting) return;

    setState(() {
      _isBoosting = true;
      _boostTimer = 0.8;
      _boostCooldown = 2.5;
    });

    HapticFeedback.mediumImpact();
    _triggerShockwave(_playerX, _playerY, const Color(0xFF10B981), 90);
  }

  void _triggerShockwave(double x, double y, Color color, double maxRadius) {
    _shockwaves.add(
      ShockwaveRing(
        x: x,
        y: y,
        radius: 10,
        maxRadius: maxRadius,
        color: color,
      ),
    );
  }

  void _showFloatingText(String text, Color color) {
    _floatingTexts.add(
      FloatingTextEffect(
        x: _playerX - 20,
        y: _playerY - 25,
        text: text,
        color: color,
      ),
    );
  }

  void _spawnEatParticles(double x, double y, Color color) {
    for (int i = 0; i < 14; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = _rng.nextDouble() * 4 + 1.5;
      _particles.add(
        BioParticle(
          x: x,
          y: y,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: color,
          size: _rng.nextDouble() * 3.5 + 2,
          maxLife: 0.45,
        ),
      );
    }
  }

  void _spawnBoostParticles() {
    for (int i = 0; i < 2; i++) {
      final angle = atan2(-_playerVy, -_playerVx) + (_rng.nextDouble() - 0.5);
      final speed = _rng.nextDouble() * 3 + 2;
      _particles.add(
        BioParticle(
          x: _playerX,
          y: _playerY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: const Color(0xFF10B981),
          size: _rng.nextDouble() * 4 + 2,
          maxLife: 0.35,
        ),
      );
    }
  }

  void _endGame() {
    _ticker.stop();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    final xpEarned = (_score ~/ 2).clamp(10, 150);
    SupabaseService.instance.addXp(xpEarned);
    SupabaseService.instance.incrementSortedCount((_score ~/ 20).clamp(1, 10));

    if (_score >= 250) {
      _confettiController.play();
    }
  }

  // ==========================================
  // UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Stack(
        children: [
          // Canvas Arena Game Utama
          Transform.translate(
            offset: Offset(_screenShakeX, _screenShakeY),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                if (!_isPlaying) return;
                _targetX = details.localPosition.dx;
                _targetY = details.localPosition.dy;
              },
              onPanStart: (details) {
                if (!_isPlaying) return;
                _targetX = details.localPosition.dx;
                _targetY = details.localPosition.dy;
              },
              onPanUpdate: (details) {
                if (!_isPlaying) return;
                _targetX = details.localPosition.dx;
                _targetY = details.localPosition.dy;
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: BioArenaPainter(
                  playerX: _playerX,
                  playerY: _playerY,
                  playerRadius: _playerRadius,
                  wobblePhase: _wobblePhase,
                  playerLevel: _playerLevel,
                  trail: _trail,
                  shieldActive: _shieldActive,
                  isSupernovaActive: _isSupernovaActive,
                  plastics: _plastics,
                  hazards: _hazards,
                  powerUps: _powerUps,
                  particles: _particles,
                  shockwaves: _shockwaves,
                  floatingTexts: _floatingTexts,
                ),
              ),
            ),
          ),

          // Confetti Rayakan Kemenangan
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF06B6D4),
                Color(0xFF10B981),
                Color(0xFFF59E0B),
                Colors.white,
              ],
            ),
          ),

          // Top HUD Bar (Skor, Darah, Gram Sampah)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopHud(),
          ),

          // Bottom Action Hub & Status Badges
          if (_isPlaying)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: _buildStatusBadges()),
                  const SizedBox(width: 8),
                  _buildActionControls(),
                ],
              ),
            ),

          // Start Screen Overlay
          if (!_isPlaying && !_isGameOver) _buildStartOverlay(),

          // Game Over Dialog Overlay
          if (_isGameOver) _buildGameOverOverlay(),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET KOMPONEN HUD & KONTROL
  // ==========================================

  Widget _buildTopHud() {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Tombol Keluar
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF0F172A), size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),

              // Bio Lives (Hati Bercahaya)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final active = index < _lives;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      active
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: active
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                  );
                }),
              ),

              const SizedBox(width: 8),
              const Spacer(),

              // Skor & Gram Sampah Terurai
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded,
                              color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 2),
                          Text(
                            '$_score XP',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_microplasticGrams.toStringAsFixed(1)} mg Mikroplastik',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: const Color(0xFF0284C7),
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Supernova Charge Meter Bar
          Row(
            children: [
              const Text(
                '⚡ SUPERNOVA',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 8,
                    color: const Color(0xFFE2E8F0),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _supernovaCharge,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _supernovaCharge >= 1.0
                                ? [const Color(0xFF06B6D4), const Color(0xFFF59E0B)]
                                : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                          ),
                          boxShadow: _supernovaCharge >= 1.0
                              ? [
                                  const BoxShadow(
                                    color: Color(0xFF06B6D4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(_supernovaCharge * 100).toInt()}%',
                style: TextStyle(
                  color: _supernovaCharge >= 1.0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_combo > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 4),
                Text(
                  'COMBO x$_combo',
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFF0284C7), size: 14),
              const SizedBox(width: 4),
              Text(
                '${_secondsElapsed}s Bertahan',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionControls() {
    final canSupernova = _supernovaCharge >= 1.0 && !_isSupernovaActive;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tombol Dash Boost
        GestureDetector(
          onTap: _activateBoost,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _boostCooldown <= 0
                  ? Colors.white
                  : const Color(0xFFF1F5F9),
              border: Border.all(
                color: _boostCooldown <= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFCBD5E1),
                width: 2.2,
              ),
              boxShadow: _boostCooldown <= 0
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: _boostCooldown <= 0
                  ? const Icon(Icons.fast_forward_rounded,
                      color: Color(0xFF10B981), size: 28)
                  : Text(
                      '${_boostCooldown.toStringAsFixed(1)}s',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Tombol ULTIMATE: SUPERNOVA
        GestureDetector(
          onTap: canSupernova ? _activateSupernova : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: canSupernova
                    ? [
                        const Color(0xFF38BDF8),
                        const Color(0xFF0284C7),
                      ]
                    : [
                        const Color(0xFFE2E8F0),
                        const Color(0xFFCBD5E1),
                      ],
              ),
              boxShadow: canSupernova
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
              border: Border.all(
                color: canSupernova
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF94A3B8),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.electric_bolt_rounded,
                color: canSupernova ? Colors.white : const Color(0xFF94A3B8),
                size: 36,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartOverlay() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.coronavirus_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 14),
                const Text(
                  'BIO-EATER: PLASTIC HUNTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kendalikan mikroba pemakan mikroplastik (Ideonella sakaiensis) di cawan petri.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Petunjuk Singkat
                _buildGuideItem(
                  Icons.touch_app_rounded,
                  const Color(0xFF0284C7),
                  'Sentuh / Geser Layar',
                  'Kendalikan arah berenang mikroba',
                ),
                const SizedBox(height: 8),
                _buildGuideItem(
                  Icons.warning_amber_rounded,
                  const Color(0xFFEF4444),
                  'Hindari Toksin Berduri',
                  'Jangan biarkan racun menghabiskan 3 nyawamu',
                ),
                const SizedBox(height: 8),
                _buildGuideItem(
                  Icons.electric_bolt_rounded,
                  const Color(0xFFF59E0B),
                  'Enzyme Supernova',
                  'Isi bar hingga 100% untuk ledakan & sedot semua plastik!',
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _startGame,
                    child: const Text(
                      'MULAI EKSPEDISI MIKRO',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideItem(
      IconData icon, Color color, String title, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverOverlay() {
    final xpEarned = (_score ~/ 2).clamp(10, 150);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Icon(Icons.military_tech_rounded,
                      color: Color(0xFFD97706), size: 44),
                ),
                const SizedBox(height: 12),
                const Text(
                  'MISI MIKRO SELESAI!',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mikroba Anda berhasil mengurai mikroplastik!',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Stat Cards
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildStatColumn('Total Skor', '$_score', const Color(0xFF0284C7))),
                      Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                      Expanded(
                        child: _buildStatColumn(
                          'Terurai',
                          '${_microplasticGrams.toStringAsFixed(1)} mg',
                          const Color(0xFF10B981),
                        ),
                      ),
                      Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                      Expanded(child: _buildStatColumn('Bonus XP', '+$xpEarned', const Color(0xFFD97706))),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _startGame,
                        child: const Text(
                          'Main Lagi',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ==========================================
// CUSTOM PAINTER: DUNIA BIO-LUMINESCENT MENGGELEGAR
// ==========================================

class BioArenaPainter extends CustomPainter {
  final double playerX;
  final double playerY;
  final double playerRadius;
  final double wobblePhase;
  final int playerLevel;
  final List<Offset> trail;
  final bool shieldActive;
  final bool isSupernovaActive;
  final List<MicroPlastic> plastics;
  final List<HazardToxin> hazards;
  final List<PowerUpItem> powerUps;
  final List<BioParticle> particles;
  final List<ShockwaveRing> shockwaves;
  final List<FloatingTextEffect> floatingTexts;

  BioArenaPainter({
    required this.playerX,
    required this.playerY,
    required this.playerRadius,
    required this.wobblePhase,
    required this.playerLevel,
    required this.trail,
    required this.shieldActive,
    required this.isSupernovaActive,
    required this.plastics,
    required this.hazards,
    required this.powerUps,
    required this.particles,
    required this.shockwaves,
    required this.floatingTexts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. LATAR CAWAN PETRI BIO-LUMINESCENT
    _drawPetriBackground(canvas, size);

    // 2. SHOCKWAVES & BURST LIGHTNING
    _drawShockwaves(canvas);

    // 3. SUPERNOVA LIGHTNING ARCS
    if (isSupernovaActive) {
      _drawSupernovaLightning(canvas);
    }

    // 4. MIKROPLASTIK & HAZARD TOXIN
    _drawPlastics(canvas);
    _drawHazards(canvas);
    _drawPowerUps(canvas);

    // 5. JEJAK TRAIL PEMAIN
    _drawPlayerTrail(canvas);

    // 6. TUBUH MIKROBA PEMAIN (ORGANIK AMOEBA)
    _drawPlayerOrganism(canvas);

    // 7. PARTIKEL LEDAKAN & SPARKLES
    _drawParticles(canvas);

    // 8. FLOATING TEXT MESSAGES
    _drawFloatingTexts(canvas);
  }

  void _drawPetriBackground(Canvas canvas, Size size) {
    // Gradien Kedalaman Mikro (Cerah, Bersih, dan Segar)
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          const Color(0xFFFFFFFF),
          const Color(0xFFF0FDF4),
          const Color(0xFFE0F2FE),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Cincin Batas Cawan Petri Modern & Segar
    final rimPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 50, size.width - 16, size.height - 110),
        const Radius.circular(32),
      ),
      rimPaint,
    );

    // Grid halus bio-cawan petri
    final gridPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, gridPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.65, gridPaint);
  }

  void _drawShockwaves(Canvas canvas) {
    for (final sw in shockwaves) {
      final p = Paint()
        ..color = sw.color.withOpacity(sw.opacity * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(Offset(sw.x, sw.y), sw.radius, p);

      // Inner faint ring
      final pInner = Paint()
        ..color = sw.color.withOpacity(sw.opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;
      canvas.drawCircle(Offset(sw.x, sw.y), sw.radius * 0.85, pInner);
    }
  }

  void _drawSupernovaLightning(Canvas canvas) {
    final lightningPaint = Paint()
      ..color = const Color(0xFF06B6D4).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Gambar busur petir ke mikroplastik terdekat
    for (final pl in plastics.take(6)) {
      final path = Path();
      path.moveTo(playerX, playerY);

      final segments = 4;
      double curX = playerX;
      double curY = playerY;
      for (int i = 1; i <= segments; i++) {
        final t = i / segments;
        final targetSubX = playerX + (pl.x - playerX) * t;
        final targetSubY = playerY + (pl.y - playerY) * t;
        final jitter = (i < segments) ? (sin(wobblePhase * 3 + i) * 16) : 0.0;

        curX = targetSubX + jitter;
        curY = targetSubY + jitter;
        path.lineTo(curX, curY);
      }
      canvas.drawPath(path, lightningPaint);
    }
  }

  void _drawPlastics(Canvas canvas) {
    for (final p in plastics) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      // Bentuk kristal bersudut
      final path = Path();
      final r = p.size;
      path.moveTo(0, -r);
      path.lineTo(r * 0.85, -r * 0.3);
      path.lineTo(r * 0.6, r * 0.9);
      path.lineTo(-r * 0.6, r * 0.7);
      path.lineTo(-r * 0.8, -r * 0.2);
      path.close();

      canvas.drawPath(path, paint);

      // Kilau Specular Putih
      final specular = Paint()..color = Colors.white.withOpacity(0.65);
      canvas.drawCircle(Offset(-r * 0.2, -r * 0.3), r * 0.25, specular);

      canvas.restore();
    }
  }

  void _drawHazards(Canvas canvas) {
    for (final h in hazards) {
      final pulseR = h.radius + sin(h.pulse) * 2.5;

      // Aura bahaya merah
      final aura = Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(h.x, h.y), pulseR + 6, aura);

      // Tubuh berduri
      final bodyPaint = Paint()
        ..color = const Color(0xFFDC2626)
        ..style = PaintingStyle.fill;

      final path = Path();
      const numSpikes = 8;
      for (int i = 0; i < numSpikes * 2; i++) {
        final angle = (i * pi) / numSpikes;
        final r = (i % 2 == 0) ? pulseR : pulseR * 0.65;
        final px = h.x + cos(angle) * r;
        final py = h.y + sin(angle) * r;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      canvas.drawPath(path, bodyPaint);

      // Inti racun ungu gelap
      final corePaint = Paint()..color = const Color(0xFF7F1D1D);
      canvas.drawCircle(Offset(h.x, h.y), pulseR * 0.4, corePaint);
    }
  }

  void _drawPowerUps(Canvas canvas) {
    for (final pu in powerUps) {
      final pulseR = 14 + sin(pu.pulse) * 3;
      final glowPaint = Paint()
        ..color = const Color(0xFFF59E0B).withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(pu.x, pu.y), pulseR + 6, glowPaint);

      final p = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(pu.x, pu.y), pulseR, p);

      // Simbol bintang / petir
      final whiteP = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(pu.x, pu.y), pulseR * 0.45, whiteP);
    }
  }

  void _drawPlayerTrail(Canvas canvas) {
    for (int i = 0; i < trail.length; i++) {
      final t = trail[i];
      final frac = 1.0 - (i / trail.length);
      final r = (playerRadius * 0.65) * frac;
      final p = Paint()
        ..color = const Color(0xFF06B6D4).withOpacity(frac * 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(t, r, p);
    }
  }

  void _drawPlayerOrganism(Canvas canvas) {
    final center = Offset(playerX, playerY);

    // Outer Aura Glow
    final glowPaint = Paint()
      ..color = (isSupernovaActive
              ? const Color(0xFFF59E0B)
              : (playerLevel == 3
                  ? const Color(0xFF06B6D4)
                  : const Color(0xFF10B981)))
          .withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, playerRadius + 12, glowPaint);

    // Shield Bubble (jika aktif)
    if (shieldActive) {
      final shieldPaint = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(center, playerRadius + 16, shieldPaint);
    }

    // Tubuh Amoeba Bergelombang (Organic Spline Vertices)
    final path = Path();
    const vertices = 12;
    for (int i = 0; i < vertices; i++) {
      final angle = (i * 2 * pi) / vertices;
      final wave = sin(wobblePhase + i * 1.5) * 4.0;
      final r = playerRadius + wave;
      final vx = playerX + cos(angle) * r;
      final vy = playerY + sin(angle) * r;

      if (i == 0) {
        path.moveTo(vx, vy);
      } else {
        path.lineTo(vx, vy);
      }
    }
    path.close();

    // Warna Tubuh Organisme Berdasarkan Level
    final bodyShader = RadialGradient(
      colors: isSupernovaActive
          ? [const Color(0xFFFBBF24), const Color(0xFF06B6D4)]
          : (playerLevel == 3
              ? [const Color(0xFF38BDF8), const Color(0xFF0284C7)]
              : (playerLevel == 2
                  ? [const Color(0xFF34D399), const Color(0xFF059669)]
                  : [const Color(0xFF10B981), const Color(0xFF047857)])),
    ).createShader(
        Rect.fromCircle(center: center, radius: playerRadius));

    final bodyPaint = Paint()
      ..shader = bodyShader
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bodyPaint);

    // Inti Sel / Nukleus Berdenyut
    final nucleusR = playerRadius * 0.42;
    final nucleusPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        center + Offset(sin(wobblePhase) * 2, cos(wobblePhase) * 2),
        nucleusR,
        nucleusPaint);

    // Cilia / Tentakel Bulu Getar Halus
    final ciliaPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (int i = 0; i < 10; i++) {
      final angle = (i * 2 * pi) / 10;
      final startR = playerRadius;
      final endR = playerRadius + 7 + sin(wobblePhase * 2 + i) * 3;
      final sx = playerX + cos(angle) * startR;
      final sy = playerY + sin(angle) * startR;
      final ex = playerX + cos(angle + 0.2) * endR;
      final ey = playerY + sin(angle + 0.2) * endR;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), ciliaPaint);
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in floatingTexts) {
      final textSpan = TextSpan(
        text: ft.text,
        style: TextStyle(
          color: ft.color.withOpacity(ft.opacity),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 4,
            ),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(ft.x, ft.y));
    }
  }

  @override
  bool shouldRepaint(covariant BioArenaPainter oldDelegate) => true;
}
