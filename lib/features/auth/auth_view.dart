import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/trashquest_logo.dart';
import '../../services/biometric_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';

class AuthView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthView({super.key, required this.onLoginSuccess});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> with SingleTickerProviderStateMixin {
  bool _isRegister = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _enableBiometrics = true;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkBiometricPreference();

    // Listeners untuk reactive animated focus glow
    _nameFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  Future<void> _checkBiometricPreference() async {
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (mounted) {
      setState(() => _enableBiometrics = enabled);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegister) {
        final success = await SupabaseService.instance.register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
        );

        if (success) {
          if (mounted) {
            setState(() {
              _isRegister = false; // Beralih halus ke login
              _passwordController.clear();
              _errorMessage = null;
            });

            // Trigger notifikasi real-time ke HP dan in-app HUD
            NotificationService.instance.showNotification(
              title: '🎉 Pendaftaran Berhasil!',
              body: 'Akun Anda telah aktif. Silakan masuk untuk memulai ekspedisi daur ulang.',
              icon: Icons.celebration_rounded,
              iconColor: const Color(0xFF0EA5E9),
            );
          }
        } else {
          setState(() => _errorMessage = SupabaseService.instance.lastAuthError ?? 'Gagal mendaftar. Silakan periksa kembali email Anda.');
        }
      } else {
        final success = await SupabaseService.instance.login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (success) {
          if (_enableBiometrics) {
            await BiometricService.instance.setBiometricEnabled(true);
          }

          // Trigger notifikasi real-time ke HP dan in-app HUD
          NotificationService.instance.showNotification(
            title: '👋 Selamat Datang Kembali!',
            body: 'Berhasil masuk ke akun TrashQuest. Siap pilah sampah lebih bijak hari ini?',
            icon: Icons.verified_user_rounded,
            iconColor: const Color(0xFF10B981),
          );

          if (mounted) widget.onLoginSuccess();
        } else {
          setState(() => _errorMessage = SupabaseService.instance.lastAuthError ?? 'Email tidak terdaftar atau kata sandi salah.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kendala jaringan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    final authenticated = await BiometricService.instance.authenticate(
      reason: 'Gunakan biometrik untuk masuk ke akun TrashQuest',
    );
    if (authenticated && mounted) {
      if (SupabaseService.instance.isAuthenticated) {
        NotificationService.instance.showNotification(
          title: '⚡ Login Biometrik Berhasil',
          body: 'Identitas Anda telah diverifikasi secara aman.',
          icon: Icons.fingerprint_rounded,
          iconColor: const Color(0xFF10B981),
        );
        widget.onLoginSuccess();
      } else {
        setState(() => _errorMessage = 'Silakan masuk dengan email & kata sandi terlebih dahulu.');
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lupa Kata Sandi?', style: AppTextStyles.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'Pulihkan akses akun TrashQuest Anda',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Masukkan alamat email yang terdaftar. Kami akan mengirimkan tautan verifikasi untuk mengatur ulang kata sandi baru.',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (localError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        localError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  _buildGlowTextField(
                    controller: resetEmailController,
                    label: 'Alamat Email Terdaftar',
                    hintText: 'nama@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final email = resetEmailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              setModalState(() => localError = 'Format email tidak valid.');
                              return;
                            }
                            setModalState(() {
                              isSubmitting = true;
                              localError = null;
                            });

                            final ok = await SupabaseService.instance.resetPassword(email: email);
                            if (!mounted) return;
                            if (ctx.mounted) {
                              if (ok) {
                                Navigator.pop(ctx);
                                NotificationService.instance.showNotification(
                                  title: '📩 Email Pemulihan Terkirim',
                                  body: 'Tautan reset kata sandi telah dikirim ke $email. Silakan periksa inbox / spam.',
                                  icon: Icons.mark_email_read_rounded,
                                  iconColor: const Color(0xFF10B981),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Tautan reset kata sandi berhasil dikirim ke $email!'),
                                    backgroundColor: const Color(0xFF10B981),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } else {
                                setModalState(() {
                                  isSubmitting = false;
                                  localError = SupabaseService.instance.lastAuthError ?? 'Gagal mengirim instruksi reset kata sandi.';
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Kirim Tautan Pemulihan',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Kembali ke Halaman Masuk',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: AmbientBackground(
        heroHeight: 320,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo Maskot TQ ECO Resmi
                    const Center(
                      child: TrashQuestLogo(
                        size: 92,
                        showWordmark: true,
                        subtitle: 'Pilah lebih mudah, bumi lebih bersih.',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // FLOATING AUTH CARD
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderLight, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. ULTRA-SMOOTH SLIDING PILL SWITCHER (GAYA TIKTOK)
                          _buildSlidingTabSwitcher(),
                          const SizedBox(height: 24),

                          // 2. ANIMATED ERROR BANNER (Slide & Fade)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            child: _errorMessage != null
                                ? Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorSoft,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.error,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // 3. ANIMATED MORPHING FORM FIELDS (Expand smoothly on Register)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.topCenter,
                            child: _isRegister
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildGlowTextField(
                                      controller: _nameController,
                                      focusNode: _nameFocusNode,
                                      label: 'Nama Lengkap',
                                      hintText: 'Nama panggilan atau lengkap',
                                      prefixIcon: Icons.person_outline_rounded,
                                      validator: (v) => (_isRegister && (v == null || v.isEmpty))
                                          ? 'Nama tidak boleh kosong'
                                          : null,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Email Field (Always visible)
                          _buildGlowTextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            label: 'Email',
                            hintText: 'contoh@gmail.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.alternate_email_rounded,
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Format email tidak valid'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Password Field (Always visible)
                          _buildGlowTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            label: 'Kata Sandi',
                            hintText: 'Minimal 6 karakter',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) => RotationTransition(
                                  turns: child.key == const ValueKey('vis')
                                      ? Tween(begin: 0.75, end: 1.0).animate(anim)
                                      : Tween(begin: 1.25, end: 1.0).animate(anim),
                                  child: FadeTransition(opacity: anim, child: child),
                                ),
                                child: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  key: ValueKey(_obscurePassword ? 'vis' : 'invis'),
                                  size: 20,
                                  color: _passwordFocusNode.hasFocus ? AppColors.primary : AppColors.textTertiary,
                                ),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Kata sandi minimal 6 karakter'
                                : null,
                          ),

                          // Tombol Lupa Kata Sandi (Tampil khusus mode masuk)
                          if (!_isRegister) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: _showForgotPasswordDialog,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                  child: Text(
                                    'Lupa kata sandi?',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Biometric Checkbox
                          GestureDetector(
                            onTap: () => setState(() => _enableBiometrics = !_enableBiometrics),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _enableBiometrics,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    onChanged: (val) => setState(() => _enableBiometrics = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Aktifkan login biometrik (sidik jari / wajah)',
                                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // 4. MORPHING GRADIENT ACTION BUTTON
                          _buildMorphingSubmitButton(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Biometric Option
                    OutlinedButton.icon(
                      onPressed: _handleBiometricLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 22),
                      label: Text(
                        'Masuk Cepat dengan Biometrik',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Demo Login Button (Instant bypass for rate limits & tests)
                    TextButton.icon(
                      onPressed: () async {
                        await SupabaseService.instance.loginDemo();
                        NotificationService.instance.showNotification(
                          title: '🌱 Masuk Mode Demo',
                          body: 'Selamat datang Aulia Rahma! Menjelajahi fitur TrashQuest & Eco-Ledger.',
                          icon: Icons.eco_rounded,
                          iconColor: const Color(0xFF10B981),
                        );
                        if (mounted) widget.onLoginSuccess();
                      },
                      icon: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF059669)),
                      label: const Text(
                        'Masuk Cepat (Akun Demo Aulia Rahma)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGETS DENGAN ANIMASI FLUID & MEWAH
  // ==========================================

  /// Segmented Tab Slider dengan Kapsul Meluncur (Gaya TikTok DailyFlutterUI)
  Widget _buildSlidingTabSwitcher() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // Kapsul Putih Meluncur (Sliding Pill)
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: _isRegister ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Label Teks di Atas Kapsul
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isRegister) setState(() => _isRegister = false);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: !_isRegister ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        fontWeight: !_isRegister ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      child: const Text('Masuk'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_isRegister) setState(() => _isRegister = true);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _isRegister ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        fontWeight: _isRegister ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      child: const Text('Daftar'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kolom Input dengan Glow Fokus Halus
  Widget _buildGlowTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final hasFocus = focusNode?.hasFocus ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: hasFocus ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus ? AppColors.primary : const Color(0xFFE2E8F0),
          width: hasFocus ? 1.6 : 1.0,
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          labelText: label,
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          labelStyle: TextStyle(
            color: hasFocus ? AppColors.primaryDark : const Color(0xFF64748B),
            fontSize: 13,
            fontWeight: hasFocus ? FontWeight.w700 : FontWeight.w500,
          ),
          prefixIcon: Icon(
            prefixIcon,
            size: 20,
            color: hasFocus ? AppColors.primary : const Color(0xFF94A3B8),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        validator: validator,
      ),
    );
  }

  /// Tombol Submit Morphing dengan Gradien Eco Mewah
  Widget _buildMorphingSubmitButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLoading
              ? [const Color(0xFF6EE7B7), const Color(0xFF34D399)]
              : [const Color(0xFF10B981), const Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loader'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : Text(
                  _isRegister ? 'Buat Akun Baru' : 'Masuk ke Akun',
                  key: ValueKey(_isRegister ? 'reg' : 'log'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
