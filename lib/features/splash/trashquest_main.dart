import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const TrashQuestApp());
}

class TrashQuestApp extends StatelessWidget {
  const TrashQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrashQuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF127347),
          primary: const Color(0xFF127347),
        ),
      ),
      home: const TrashQuestSplashScreen(),
    );
  }
}

// ============================================================================
// 1. SPLASH LOADING SCREEN (Desain Foto Kedua Hasil Generate)
// ============================================================================
class TrashQuestSplashScreen extends StatefulWidget {
  const TrashQuestSplashScreen({super.key});

  @override
  State<TrashQuestSplashScreen> createState() => _TrashQuestSplashScreenState();
}

class _TrashQuestSplashScreenState extends State<TrashQuestSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();

    // Animasi floating lembut untuk maskot dan partikel daun
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Animasi loading progress bar selama 3.5 detik lalu pindah ke halaman Login
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
              opacity: animation,
              child: const TrashQuestLoginScreen(),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradasi hijau mint lembut
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD6F5E6),
                  Color(0xFFF2FBF7),
                  Color(0xFFD9F6E8),
                ],
              ),
            ),
          ),

          // Dekorasi siluet daun & bokeh cahaya halus di background
          Positioned(
            top: -40,
            right: -30,
            child: Opacity(
              opacity: 0.12,
              child: Transform.rotate(
                angle: -0.4,
                child: const Icon(
                  Icons.eco_rounded,
                  size: 280,
                  color: Color(0xFF127347),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -40,
            child: Opacity(
              opacity: 0.12,
              child: Transform.rotate(
                angle: 0.5,
                child: const Icon(
                  Icons.eco_rounded,
                  size: 260,
                  color: Color(0xFF127347),
                ),
              ),
            ),
          ),
          ..._buildBokehCircles(),

          // Konten Utama Splash Screen
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Maskot & Emblem Lingkaran "Q" TrashQuest
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
                    child: const TrashQuestMascotBadge(size: 220),
                  ),

                  const SizedBox(height: 28),

                  // Judul Aplikasi: TrashQuest
                  const Text(
                    'TrashQuest',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0A3622),
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Slogan Aplikasi
                  const Text(
                    'Pilah lebih mudah, bumi lebih bersih.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F4E37),
                      letterSpacing: 0.1,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Loading Progress Bar dengan Efek Partikel Daun
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return Column(
                        children: [
                          _TrashQuestLoadingBar(
                            progress: _progressController.value,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Memuat misi...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E4631),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBokehCircles() {
    const positions = [
      Offset(45, 220),
      Offset(310, 260),
      Offset(60, 520),
      Offset(320, 620),
    ];
    return positions.map((pos) {
      return Positioned(
        left: pos.dx,
        top: pos.dy,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 12,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// Widget Badge Maskot TrashQuest
class TrashQuestMascotBadge extends StatelessWidget {
  final double size;

  const TrashQuestMascotBadge({super.key, this.size = 210});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/logo TQ.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _FallbackMascotBadge(size: size);
        },
      ),
    );
  }
}

class _FallbackMascotBadge extends StatelessWidget {
  final double size;

  const _FallbackMascotBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF22A05D), Color(0xFF106A39)],
              ),
            ),
            padding: EdgeInsets.all(size * 0.085),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const ClipOval(
                child: _FallbackMascotIllustration(),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.04,
            right: size * 0.08,
            child: Transform.rotate(
              angle: 0.65,
              child: Container(
                width: size * 0.28,
                height: size * 0.16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback Ilustrasi Karakter jika file asset PNG belum dipasang di pubspec.yaml
class _FallbackMascotIllustration extends StatelessWidget {
  const _FallbackMascotIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFFF4FBF7), Color(0xFFDCEFE5)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Kepala Daun & Masker Superhero
          Container(
            width: 72,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF8CD71E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
              border: Border.all(color: const Color(0xFF0F532D), width: 2.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Topeng Hijau Superhero
                Positioned(
                  top: 22,
                  left: 4,
                  right: 4,
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E7C3A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildEye(),
                        _buildEye(),
                      ],
                    ),
                  ),
                ),
                // Senyum
                Positioned(
                  bottom: 10,
                  child: Container(
                    width: 26,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7B1E1E),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Badan dengan Simbol Recycle & Sabuk "TQ"
          Container(
            width: 68,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF8CD71E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0F532D), width: 2.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.recycling_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                // Sabuk TQ
                Container(
                  width: double.infinity,
                  height: 18,
                  color: const Color(0xFF0E7C3A),
                  alignment: Alignment.center,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EE38),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF0F532D),
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'TQ',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0A3622),
                      ),
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

  Widget _buildEye() {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: Color(0xFF143621),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Widget Progress Bar dengan Efek Partikel Daun
class _TrashQuestLoadingBar extends StatelessWidget {
  final double progress;

  const _TrashQuestLoadingBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final currentWidth = (maxWidth * progress).clamp(24.0, maxWidth);

          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // Track Latar Belakang
              Container(
                width: maxWidth,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF288E5F).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF127347).withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),

              // Isi Progress Hijau Aktif
              Container(
                width: currentWidth,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF38B87C),
                      Color(0xFF147A4B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),

              // Partikel Daun di Ujung Progress Bar
              Positioned(
                left: (currentWidth - 16).clamp(0.0, maxWidth - 32),
                top: -2,
                child: const Icon(
                  Icons.eco_rounded,
                  size: 16,
                  color: Color(0xFF22A05D),
                ),
              ),
              Positioned(
                left: (currentWidth + 4).clamp(0.0, maxWidth - 20),
                bottom: 0,
                child: Transform.rotate(
                  angle: 0.8,
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 13,
                    color: Color(0xFF38B87C),
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

// ============================================================================
// 2. HALAMAN LOGIN & DAFTAR (Sesuai Foto Aplikasi Kedua yang Diunggah)
// ============================================================================
class TrashQuestLoginScreen extends StatefulWidget {
  const TrashQuestLoginScreen({super.key});

  @override
  State<TrashQuestLoginScreen> createState() => _TrashQuestLoginScreenState();
}

class _TrashQuestLoginScreenState extends State<TrashQuestLoginScreen> {
  bool _isLoginTab = true;
  bool _obscurePassword = true;
  bool _enableBiometric = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2EE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header: Ikon Q TrashQuest + Nama Aplikasi + Slogan
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _TrashQuestMiniQLogo(size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'TrashQuest',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF14261D),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pilah lebih mudah, bumi lebih bersih.',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF55695F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // Card Putih Utama (Masuk / Daftar, Input Email & Kata Sandi)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Segmented Tab: Masuk | Daftar
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F0EC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isLoginTab = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isLoginTab
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _isLoginTab
                                        ? [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: _isLoginTab
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: _isLoginTab
                                          ? const Color(0xFF14261D)
                                          : const Color(0xFF5B6E64),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isLoginTab = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !_isLoginTab
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: !_isLoginTab
                                        ? [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Daftar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: !_isLoginTab
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: !_isLoginTab
                                          ? const Color(0xFF14261D)
                                          : const Color(0xFF5B6E64),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Input Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6E7E76),
                            fontSize: 15,
                          ),
                          prefixIcon: const Icon(
                            Icons.alternate_email_rounded,
                            color: Color(0xFF55695F),
                            size: 22,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE5E0),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF127347),
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Input Kata Sandi
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Kata Sandi',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6E7E76),
                            fontSize: 15,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF55695F),
                            size: 22,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF55695F),
                              size: 22,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE5E0),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF127347),
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Checkbox: Aktifkan login biometrik (sidik jari / wajah)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() {
                            _enableBiometric = !_enableBiometric;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _enableBiometric,
                                  activeColor: const Color(0xFF127347),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _enableBiometric = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Aktifkan login biometrik (sidik jari / wajah)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF37473F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Tombol Utama: Masuk ke Akun
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _isLoginTab
                                      ? 'Memproses masuk ke akun TrashQuest...'
                                      : 'Memproses pendaftaran akun TrashQuest...',
                                ),
                                backgroundColor: const Color(0xFF127347),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF127347),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _isLoginTab ? 'Masuk ke Akun' : 'Daftar Akun',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Tombol Bawah: Masuk Cepat dengan Biometrik
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Memindai autentikasi biometrik...'),
                          backgroundColor: Color(0xFF127347),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.fingerprint_rounded,
                      size: 26,
                      color: Color(0xFF127347),
                    ),
                    label: const Text(
                      'Masuk Cepat dengan Biometrik',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3329),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F8F5),
                      side: const BorderSide(
                        color: Color(0xFFCBD8D1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
}

/// Ikon Lingkaran Panah "Q" dengan Daun Oranye (Header Halaman Login)
class _TrashQuestMiniQLogo extends StatelessWidget {
  final double size;

  const _TrashQuestMiniQLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF155E3A),
                width: size * 0.14,
              ),
            ),
          ),
          // Ekor daun oranye di kanan bawah
          Positioned(
            bottom: 2,
            right: 2,
            child: Transform.rotate(
              angle: 0.6,
              child: Container(
                width: size * 0.34,
                height: size * 0.18,
                decoration: const BoxDecoration(
                  color: Color(0xFFE07A2E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}