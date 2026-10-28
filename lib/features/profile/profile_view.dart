import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/achievement.dart';
import '../../data/models/user_profile.dart';
import '../../services/biometric_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import '../blockchain/blockchain_view.dart';
import '../currency/currency_view.dart';
import '../feedback/feedback_view.dart';
import '../rewards/redeem_view.dart';
import '../scanner/scan_history_view.dart';
import '../timezone/timezone_view.dart';
import 'edit_profile_screen.dart';

class ProfileView extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileView({super.key, required this.onLogout});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  List<Achievement> _achievements = [];
  bool _biometricEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.addListener(_onProfileUpdated);
    _loadProfileData();
  }

  void _onProfileUpdated() {
    if (mounted) {
      _loadProfileData();
    }
  }

  @override
  void dispose() {
    SupabaseService.instance.removeListener(_onProfileUpdated);
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    await SupabaseService.instance.restoreAchievementsFromCloud();
    final achs = await SqliteService.instance.getAchievements();
    final bio = await BiometricService.instance.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _achievements = achs;
        _biometricEnabled = bio;
        _isLoading = false;
      });
    }
  }

  String _getLevelTitle(int level) {
    switch (level) {
      case 1:
        return 'Pemula Hijau';
      case 2:
        return 'Penyelamat Alam';
      case 3:
        return 'Pejuang Lingkungan';
      case 4:
        return 'Pahlawan Bumi';
      case 5:
        return 'Earth Guardian';
      default:
        return 'Master Ekologi';
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (mounted) {
      await _loadProfileData();
      setState(() {});
    }
  }

  void _showHelpAndEducationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pusat Bantuan & Edukasi 3R',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pedoman Reduce, Reuse, Recycle TrashQuest',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 14),

                _buildEdukasiItem(
                  icon: Icons.eco_rounded,
                  color: const Color(0xFF16A34A),
                  title: '1. Reduce (Mengurangi Sampah)',
                  desc: 'Gunakan botol minum isi ulang (tumbler), tas belanja kain, dan hindari kemasan plastik sekali pakai saat berbelanja.',
                ),
                const SizedBox(height: 14),
                _buildEdukasiItem(
                  icon: Icons.autorenew_rounded,
                  color: const Color(0xFF2563EB),
                  title: '2. Reuse (Menggunakan Kembali)',
                  desc: 'Gunakan kembali wadah kaca atau plastik tebal untuk penyimpanan serbaguna sebelum dibuang.',
                ),
                const SizedBox(height: 14),
                _buildEdukasiItem(
                  icon: Icons.recycling_rounded,
                  color: const Color(0xFFD97706),
                  title: '3. Recycle (Mendaur Ulang)',
                  desc: 'Pilah sampah berdasarkan kategori (Organik, Anorganik, B3, Residu) dan setorkan ke Bank Sampah terdekat lewat menu Peta.',
                ),
                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Setiap sampah yang kamu scan dan pilah menghasilkan XP & Koin Lestari yang tersertifikasi di blockchain.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildEdukasiItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockchainVerificationModal(Achievement ach) {
    final user = SupabaseService.instance.currentUser;
    final certId = 'TRQ-CERT-${ach.code}-${user.id.hashCode.abs() % 100000}';
    const rawWallet = BlockchainService.userWalletAddress;
    final userWalletAddress = '${rawWallet.substring(0, 6)}...${rawWallet.substring(rawWallet.length - 4)}';
    final bool isMintedOnChain = ach.isUnlocked;
    final bool isEligible = ach.isEligibleToMint(user);
    final String? missingMsg = ach.getMissingRequirementMessage(user);

    // 1. Hash Sertifikat Unik Pengguna (100% Unik & Berbeda untuk Setiap User!)
    final userCertHash = Achievement.generateUserCertHash(
      achievementCode: ach.code,
      userId: user.id,
      userEmail: user.email,
      userName: user.fullName,
      timestamp: ach.unlockedAt,
    );

    // 2. EVM Transaction Hash (Resi Transaksi di Ethereum Sepolia)
    final evmHash = BlockchainService.ensureEvmTxHash(
      ach.verificationHash ?? '',
      userId: user.id,
      userEmail: user.email,
      userName: user.fullName,
      code: ach.code,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            16,
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMintedOnChain
                            ? const Color(0xFFDCFCE7)
                            : (isEligible ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: Icon(
                        isMintedOnChain
                            ? Icons.verified_user_rounded
                            : (isEligible ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded),
                        color: isMintedOnChain
                            ? const Color(0xFF16A34A)
                            : (isEligible ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isMintedOnChain
                                      ? 'Sertifikat Verified Blockchain'
                                      : (isEligible ? 'Piagam Siap Diterbitkan' : 'Piagam Terkunci (Quest)'),
                                  style: AppTextStyles.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isMintedOnChain
                                      ? const Color(0xFFDCFCE7)
                                      : (isEligible ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isMintedOnChain
                                        ? const Color(0xFF86EFAC)
                                        : (isEligible ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  isMintedOnChain ? 'VERIFIED' : (isEligible ? 'SIAP TERBIT' : 'TERKUNCI'),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isMintedOnChain
                                        ? const Color(0xFF16A34A)
                                        : (isEligible ? const Color(0xFF1D4ED8) : const Color(0xFF64748B)),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            ach.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quest Requirement Box (Tampil jika belum dicatat on-chain)
                if (!isMintedOnChain) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEligible ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEligible ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEligible ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 16,
                              color: isEligible ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEligible ? 'Syarat Quest Terpenuhi!' : 'Syarat Quest Masuk Akal:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isEligible ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ach.questRequirementsSummary,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isEligible ? const Color(0xFF065F46) : const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // XP Progress Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progres XP: ${user.xp}/${ach.requiredXp} XP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isEligible ? const Color(0xFF047857) : const Color(0xFFB45309),
                              ),
                            ),
                            Text(
                              isEligible ? '100%' : '${((user.xp / ach.requiredXp) * 100).clamp(0, 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isEligible ? const Color(0xFF047857) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (user.xp / ach.requiredXp).clamp(0.0, 1.0),
                            backgroundColor: isEligible ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            color: isEligible ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            minHeight: 6,
                          ),
                        ),
                        if (missingMsg != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_right_rounded, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    missingMsg,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Certificate Banner Card (Menampilkan Nama User & Status Terkini)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMintedOnChain ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF334155),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'PIAGAM PENGHARGAAN RESMI',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMintedOnChain
                                  ? const Color(0xFF065F46)
                                  : (isEligible ? const Color(0xFF1E3A8A) : const Color(0xFF374151)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMintedOnChain
                                      ? Icons.verified_user_rounded
                                      : (isEligible ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded),
                                  size: 11,
                                  color: isMintedOnChain
                                      ? const Color(0xFF34D399)
                                      : (isEligible ? const Color(0xFF60A5FA) : Colors.white70),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMintedOnChain
                                      ? 'VERIFIED SEPOLIA'
                                      : (isEligible ? 'SIAP MINT' : 'TERKUNCI'),
                                  style: TextStyle(
                                    color: isMintedOnChain
                                        ? const Color(0xFF34D399)
                                        : (isEligible ? const Color(0xFF93C5FD) : Colors.white70),
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ach.name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('Penerima Sertifikat: ', style: TextStyle(color: Colors.white60, fontSize: 11.5)),
                          Flexible(
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName : 'Eco Warrior TrashQuest',
                              style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 12.5, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (ach.unlockedAt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Tanggal Terbit: ${DateFormat('dd MMM yyyy, HH:mm').format(ach.unlockedAt!)} WIB',
                          style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (isMintedOnChain) ...[
                  const Divider(),
                  const SizedBox(height: 12),

                  Text('ID Sertifikat Kanonikal (Unik per User):', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppSpacing.roundedSm,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            certId,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                          tooltip: 'Salin ID',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: certId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID Verifikasi disalin!'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                    Text('Hash Sertifikat Unik (User Proof - SHA256):', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                        borderRadius: AppSpacing.roundedSm,
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              userCertHash,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFD97706)),
                            tooltip: 'Salin Hash Unik User',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: userCertHash));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hash Sertifikat Unik disalin!'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('EVM Transaction Hash (Ethereum Sepolia):', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppSpacing.roundedSm,
                        border: Border.all(color: AppColors.borderLight),
                      ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            evmHash,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                          tooltip: 'Salin TxHash',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: evmHash));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('TxHash Ethereum disalin!'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Network & Smart Contract Metadata Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text('Penerima (Wallet User):', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                userWalletAddress,
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text('Jaringan:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                BlockchainService.networkName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text('Smart Contract:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${BlockchainService.contractAddress.substring(0, 6)}...${BlockchainService.contractAddress.substring(38)}',
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: AppSpacing.roundedSm,
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status: Online & Terverifikasi on-chain di Ethereum Sepolia Testnet via Etherscan.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF065F46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Action Buttons based on state
                if (isMintedOnChain) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => BlockchainService.openEtherscan(ach.verificationHash ?? evmHash),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                      label: const Text(
                        'Cek Hash di Sepolia Etherscan ↗',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else if (isEligible) ...[
                  // Eligible to Mint!
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _runAutoMintWorkflow(ach);
                      },
                      icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                      label: const Text(
                        'Terbitkan Piagam On-Chain (1x Mint Sah)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Nanti Saja', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
                  // Not Eligible yet - locked!
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.grey.shade600,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(missingMsg ?? 'Selesaikan quest untuk membuka piagam ini!'),
                            backgroundColor: const Color(0xFFD97706),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_rounded, size: 18),
                      label: Text(
                        '🔒 Butuh Min. ${ach.requiredXp} XP & Selesaikan Quest',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Mengerti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _runAutoMintWorkflow(Achievement ach) {
    final user = SupabaseService.instance.currentUser;
    String currentStep = 'Menyiapkan transaksi on-chain...';
    bool isCompleted = false;
    bool isStarted = false;
    AutoMintResult? mintResult;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (!isStarted) {
              isStarted = true;
              BlockchainService.instance.autoMintCertificate(
                achievementCode: ach.code,
                userId: user.id,
                recipientName: user.fullName.isNotEmpty ? user.fullName : 'Eco Warrior TrashQuest',
                onStepUpdate: (step) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      currentStep = step;
                    });
                  }
                },
              ).then((res) async {
                await SqliteService.instance.unlockAchievement(ach.code, res.txHash, targetUserId: user.id);
                await _loadProfileData();
                if (ctx.mounted) {
                  setDialogState(() {
                    isCompleted = true;
                    mintResult = res;
                  });
                }
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: isCompleted
                          ? const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 36)
                          : const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isCompleted ? 'Piagam Berhasil Diterbitkan!' : 'Menerbitkan ke Blockchain...',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentStep,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isCompleted ? const Color(0xFF047857) : AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isCompleted && mintResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID Piagam: ${mintResult!.certId}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'TxHash: ${mintResult!.txHash.substring(0, 16)}...${mintResult!.txHash.substring(58)}',
                              style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (isCompleted && mintResult != null)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dlgCtx);
                                BlockchainService.openEtherscan(mintResult!.txHash);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                              label: const Text('Cek di Etherscan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dlgCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppSpacing.subtleShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Keluar Akun?',
                style: AppTextStyles.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Kamu akan keluar dari sesi TrashQuest saat ini. Tenang, data level dan pencapaianmu tersimpan aman!',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Batal', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: AppColors.background.withValues(alpha: 0.95),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Menutup Sesi...',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sampai jumpa lagi di TrashQuest!',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      await SupabaseService.instance.logout();
      if (mounted) Navigator.pop(context); // close loading dialog
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Profil & Pengaturan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: AmbientBackground(
        heroHeight: 240,
        primaryGlowColor: const Color(0xFF10B981),
        secondaryGlowColor: const Color(0xFFF59E0B),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. User Identity Card (Concept card matching image)
                    _buildUserIdentityCard(user),

                    const SizedBox(height: 14),

                    // 2. XP Progress Card (Concept progress matching image)
                    _buildXpProgressCard(user),

                    const SizedBox(height: 14),

                    // 3. 3 Stat boxes (Pindai AI, Setor TPS, Terpilah)
                    _buildStatsRow(user),

                    const SizedBox(height: 22),

                    // 4. Pencapaian & Sertifikat (Sepolia On-Chain) Carousel
                    _buildAchievementsHeader(),
                    const SizedBox(height: 10),
                    _buildAchievementsCarousel(),

                    const SizedBox(height: 22),

                    // 5. Section Heading: PENGATURAN & AKUN:
                    const Text(
                      'PENGATURAN & AKUN:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 6. Settings items matching the mockup list
                    _buildSettingCard(
                      title: 'Ubah Bio Data & Foto Profil',
                      icon: Icons.badge_outlined,
                      accentColor: AppColors.primary,
                      onTap: _openEditProfile,
                    ),

                    _buildSettingCard(
                      title: 'Piagam & Sertifikat Blockchain',
                      icon: Icons.token_rounded,
                      accentColor: const Color(0xFF10B981),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BlockchainView()),
                        );
                        if (mounted) {
                          _loadProfileData();
                        }
                      },
                    ),

                    _buildSettingCard(
                      title: 'Riwayat Pindai & Penyetoran',
                      icon: Icons.history_rounded,
                      accentColor: const Color(0xFF2563EB),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScanHistoryView()),
                      ),
                    ),

                    // Keamanan Biometrik with Switch toggle
                    _buildBiometricSettingCard(),

                    _buildSettingCard(
                      title: 'Kritik, Saran & Feedback',
                      icon: Icons.rate_review_outlined,
                      accentColor: const Color(0xFFE7A93B),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackView()),
                      ),
                    ),

                    _buildSettingCard(
                      title: 'Pusat Bantuan & Edukasi 3R',
                      icon: Icons.menu_book_rounded,
                      accentColor: const Color(0xFF059669),
                      onTap: _showHelpAndEducationModal,
                    ),

                    _buildSettingCard(
                      title: 'Dompet & Tukar Poin Koin Lestari',
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: const Color(0xFFD97706),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RedeemView()),
                      ),
                    ),

                    _buildSettingCard(
                      title: 'Konversi Mata Uang & Zona Waktu',
                      icon: Icons.language_rounded,
                      accentColor: const Color(0xFF7C3AED),
                      onTap: _showCurrencyAndTimezoneModal,
                    ),

                    const SizedBox(height: 14),

                    // Dedicated Modern Logout Card
                    InkWell(
                      onTap: _handleLogout,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA), width: 1.4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Keluar dari Akun',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
      ),
    );
  }

  /// Card 1: User Profile Card (Mockup top card)
  Widget _buildUserIdentityCard(UserProfile user) {
    final levelTitle = _getLevelTitle(user.level);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // UserAvatar with interactive preview & tap
          UserAvatar(
            profilePicture: user.avatarUrl,
            radius: 32,
            borderColor: AppColors.primary,
            borderWidth: 2.5,
            showBadge: true,
            userName: user.fullName,
            onBadgeTap: _openEditProfile,
            onEditPhoto: _openEditProfile,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isNotEmpty ? user.fullName : 'Raditya Pratama',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email.isNotEmpty ? user.email : 'raditya@ecohunter.id',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'Level ${user.level}: $levelTitle',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
            tooltip: 'Ubah Data & Foto Profil',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 2: XP Progress Card matching the mockup:
  /// PROGRES PENGALAMAN (XP):       1.250 / 2.000 XP
  /// [============== progress bar ===============]
  /// 750 XP lagi untuk naik ke Level 5 (Earth Guardian)
  Widget _buildXpProgressCard(UserProfile user) {
    final nextLevel = user.level + 1;
    final nextLevelTitle = _getLevelTitle(nextLevel);

    // Dynamic calculation: target XP for level
    final targetXp = user.level * 500;
    final displayXp = user.xp;
    final xpNeeded = (targetXp - displayXp).clamp(0, targetXp);
    final progress = targetXp > 0 ? (displayXp / targetXp).clamp(0.0, 1.0) : 1.0;

    final formatter = NumberFormat.decimalPattern('id');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROGRES PENGALAMAN (XP):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF047857),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${formatter.format(displayXp)} / ${formatter.format(targetXp)} XP',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Linear progress bar
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Bottom label
          Text(
            '$xpNeeded XP lagi untuk naik ke Level $nextLevel ($nextLevelTitle)',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 3: 3 Stats boxes in a row matching mockup:
  /// [ 42x / Pindai AI ]  [ 18x / Setor TPS ]  [ 28.4 kg / Terpilah ]
  Widget _buildStatsRow(UserProfile user) {
    final scanCount = user.totalScans;
    final tpsCount = (user.totalSorted / 2).ceil();
    final weightKg = user.formattedSortedKg;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            value: '${scanCount}x',
            label: 'Pindai AI',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            value: '${tpsCount}x',
            label: 'Setor TPS',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            value: '$weightKg kg',
            label: 'Terpilah',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FDF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF065F46),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Achievements section header with blockchain ledger link
  Widget _buildAchievementsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'Pencapaian & Sertifikat:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockchainView()),
            );
            if (mounted) {
              _loadProfileData();
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.token_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Sepolia Ledger →',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Carousel of blockchain verified achievements
  Widget _buildAchievementsCarousel() {
    if (_achievements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Text(
            'Belum ada pencapaian. Selesaikan quest untuk membukanya!',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final user = SupabaseService.instance.currentUser;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _achievements.map((ach) {
          final isUnlocked = ach.isUnlocked;
          final isEligible = ach.isEligibleToMint(user);

          Color borderColor;
          Color iconBg;
          Color iconColor;
          IconData iconData;
          String badgeText;
          Color badgeBg;
          Color badgeTextColor;

          if (isUnlocked) {
            borderColor = const Color(0xFF10B981);
            iconBg = const Color(0xFFDCFCE7);
            iconColor = const Color(0xFF16A34A);
            iconData = Icons.verified_user_rounded;
            badgeText = 'VERIFIED';
            badgeBg = const Color(0xFFDCFCE7);
            badgeTextColor = const Color(0xFF16A34A);
          } else if (isEligible) {
            borderColor = const Color(0xFF2563EB);
            iconBg = const Color(0xFFEFF6FF);
            iconColor = const Color(0xFF2563EB);
            iconData = Icons.workspace_premium_rounded;
            badgeText = 'SIAP TERBIT';
            badgeBg = const Color(0xFFEFF6FF);
            badgeTextColor = const Color(0xFF1D4ED8);
          } else {
            borderColor = const Color(0xFFE2E8F0);
            iconBg = const Color(0xFFF1F5F9);
            iconColor = const Color(0xFF94A3B8);
            iconData = Icons.lock_outline_rounded;
            badgeText = 'TERKUNCI';
            badgeBg = const Color(0xFFF1F5F9);
            badgeTextColor = const Color(0xFF64748B);
          }

          return InkWell(
            onTap: () => _showBlockchainVerificationModal(ach),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 175,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, size: 16, color: iconColor),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: badgeTextColor,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ach.name,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUnlocked
                        ? 'Tervalidasi di Ethereum Sepolia (1 Hash Sah)'
                        : (isEligible
                            ? '✨ Syarat Quest terpenuhi (${user.xp}/${ach.requiredXp} XP)'
                            : 'Syarat: ${ach.questRequirementsSummary}'),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUnlocked
                          ? const Color(0xFF059669)
                          : (isEligible ? const Color(0xFF1D4ED8) : AppColors.textSecondary),
                      fontWeight: isUnlocked || isEligible ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Reusable setting card matching the mockup style
  Widget _buildSettingCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Biometric switch card matching the mockup switch
  Widget _buildBiometricSettingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Keamanan Biometrik (Sidik Jari)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: _biometricEnabled,
            activeTrackColor: const Color(0xFF10B981),
            activeThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            onChanged: (val) async {
              await BiometricService.instance.setBiometricEnabled(val);
              setState(() => _biometricEnabled = val);
            },
          ),
        ],
      ),
    );
  }

  void _showCurrencyAndTimezoneModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Alat Konversi Global',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih fitur konversi yang ingin kamu gunakan:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.currency_exchange_rounded, color: AppColors.primary),
                ),
                title: const Text('Konversi Kurs Mata Uang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Kalkulator kurs realtime IDR, USD, SGD, EUR', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyView()));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.access_time_rounded, color: Colors.purple),
                ),
                title: const Text('Konversi Zona Waktu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Perbandingan jam WIB, WITA, WIT, dan London GMT', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TimezoneView()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
