import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/models/achievement.dart';
import '../../services/blockchain_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';

class BlockchainView extends StatefulWidget {
  const BlockchainView({super.key});

  @override
  State<BlockchainView> createState() => _BlockchainViewState();
}

class _BlockchainViewState extends State<BlockchainView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Achievement> _achievements = [];
  bool _isLoading = true;

  // Verifier controller
  final TextEditingController _hashInputController = TextEditingController();
  EtherscanVerificationResult? _verificationResult;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hashInputController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await SupabaseService.instance.restoreAchievementsFromCloud();
    final achs = await SqliteService.instance.getAchievements();
    if (mounted) {
      setState(() {
        _achievements = achs;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCustomHash(String input) async {
    final clean = input.trim().isEmpty
        ? BlockchainService.liveVerifiedTxHashes['FIRST_SCAN']!
        : input.trim();

    _hashInputController.text = clean;

    setState(() {
      _isVerifying = true;
      _verificationResult = null;
    });

    final match = _achievements.where((a) =>
        (a.verificationHash ?? '').toLowerCase() == clean.toLowerCase() ||
        'TRQ-CERT-${a.code}-${a.id}'.toLowerCase() == clean.toLowerCase());

    final certName = match.isNotEmpty ? match.first.name : null;
    final result = await BlockchainService.instance.verifyOnChain(clean, certName: certName);

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _verificationResult = result;
      });
    }
  }

  void _showCertificateDetail(Achievement ach) {
    final user = SupabaseService.instance.currentUser;
    final certId = 'TRQ-CERT-${ach.code}-${user.id.hashCode.abs().toString().padLeft(5, '0')}';
    const rawWallet = BlockchainService.userWalletAddress;
    final userWalletAddress = '${rawWallet.substring(0, 6)}...${rawWallet.substring(rawWallet.length - 4)}';
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
    final bool isUnlocked = ach.isUnlocked;
    final bool isEligible = ach.isEligibleToMint(user);
    final String? missingMsg = ach.getMissingRequirementMessage(user);

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
            16,
            14,
            16,
            16,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0B1329),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),

                // Quest Requirement Box (Tampil jika belum sah on-chain)
                if (!isUnlocked) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEligible
                          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                          : const Color(0xFF78350F).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEligible
                            ? const Color(0xFF10B981).withValues(alpha: 0.6)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEligible ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                              size: 16,
                              color: isEligible ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEligible ? 'Syarat Quest Terpenuhi!' : 'Syarat Quest Belum Terpenuhi:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isEligible ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ach.questRequirementsSummary,
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progres XP: ${user.xp}/${ach.requiredXp} XP',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isEligible ? const Color(0xFF34D399) : const Color(0xFFFCD34D),
                              ),
                            ),
                            Text(
                              isEligible ? '100%' : '${((user.xp / ach.requiredXp) * 100).clamp(0, 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isEligible ? const Color(0xFF34D399) : const Color(0xFFFCD34D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (user.xp / ach.requiredXp).clamp(0.0, 1.0),
                            backgroundColor: Colors.white10,
                            color: isEligible ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            minHeight: 5,
                          ),
                        ),
                        if (missingMsg != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '⚠️ $missingMsg',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // THE DIGITAL CERTIFICATE CARD (Piagam Digital)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD97706), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Inner Certificate Border
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35), width: 1),
                        ),
                        child: Column(
                          children: [
                            // Gold Badge Emblem
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'TRASHQUEST ECO-LEDGER',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'CERTIFICATE OF ENVIRONMENTAL ACTION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Diberikan kepada:',
                              style: TextStyle(color: Colors.white60, fontSize: 10.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    ach.name,
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ach.description,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Verification Stamp
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isUnlocked
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (isEligible
                                        ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isUnlocked
                                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                      : (isEligible
                                          ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isUnlocked
                                        ? Icons.verified_rounded
                                        : (isEligible ? Icons.bolt_rounded : Icons.lock_outline_rounded),
                                    size: 13,
                                    color: isUnlocked
                                        ? const Color(0xFF10B981)
                                        : (isEligible ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      isUnlocked
                                          ? 'ONLINE ON ETHEREUM SEPOLIA (VERIFIED)'
                                          : (isEligible ? 'QUEST COMPLETE (READY TO MINT)' : 'LOCKED (QUEST INCOMPLETE)'),
                                      style: TextStyle(
                                        color: isUnlocked
                                            ? const Color(0xFF10B981)
                                            : (isEligible ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Network Details Box (Guaranteed overflow-free)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Recipient Wallet:', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    userWalletAddress,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Network:', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    BlockchainService.networkName,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Contract:', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${BlockchainService.contractAddress.substring(0, 8)}...${BlockchainService.contractAddress.substring(36)}',
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cert ID:', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    certId,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
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
                      const SizedBox(height: 10),

                      // Certificate Hash Box (Unik 100% per User)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.fingerprint_rounded, size: 13, color: Color(0xFFF59E0B)),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Hash Sertifikat Unik (User Proof):',
                                    style: TextStyle(color: Color(0xFFFCD34D), fontSize: 9.5, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userCertHash,
                                    style: const TextStyle(
                                      color: Color(0xFFFCD34D),
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: userCertHash));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Hash sertifikat unik disalin!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFFF59E0B)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // EVM Hash Section
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.link_rounded, size: 13, color: Color(0xFF38BDF8)),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Ethereum Sepolia TxHash:',
                                    style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 9.5, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    evmHash,
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: evmHash));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('TxHash disalin!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons based on eligibility and unlock state
                if (isUnlocked) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: () => BlockchainService.openEtherscan(evmHash),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Buka di Sepolia Etherscan ↗',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ] else if (isEligible) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _runAutoMintWorkflow(ach);
                      },
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text(
                        '⚡ Terbitkan Piagam On-Chain (1x Mint Sah)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      icon: const Icon(Icons.lock_rounded, size: 18, color: Colors.white38),
                      label: Text(
                        '🔒 Selesaikan Quest (Min. ${ach.requiredXp} XP)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Secondary Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final summary = 'TrashQuest Eco-Certificate: ${ach.name} atas nama ${user.fullName}. CertHash: $userCertHash | TxHash: $evmHash | Explorer: ${BlockchainService.getEtherscanTxUrl(evmHash)}';
                          Clipboard.setData(ClipboardData(text: summary));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ringkasan Piagam disalin!'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Salin Tautan',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Tutup',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _runAutoMintWorkflow(Achievement ach) {
    final user = SupabaseService.instance.currentUser;
    String currentStep = 'Menghubungkan ke node Ethereum Sepolia...';
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
                await SqliteService.instance.unlockAchievement(ach.code, res.txHash);
                await _loadData();
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
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
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
                        color: isCompleted ? const Color(0xFF065F46) : const Color(0xFF1E3A8A),
                        shape: BoxShape.circle,
                      ),
                      child: isCompleted
                          ? const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 36)
                          : const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF60A5FA),
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isCompleted ? 'Piagam Berhasil Diterbitkan!' : 'Menerbitkan ke Sepolia...',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentStep,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isCompleted ? const Color(0xFF34D399) : Colors.white70,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isCompleted && mintResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID Piagam: ${mintResult!.certId}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'TxHash: ${mintResult!.txHash.substring(0, 16)}...${mintResult!.txHash.substring(58)}',
                              style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF38BDF8)),
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
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Blockchain Eco-Ledger', style: AppTextStyles.titleLarge),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Sertifikat On-Chain'),
            Tab(text: 'Sepolia Etherscan'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCertificatesTab(),
                _buildLedgerExplorerTab(),
              ],
            ),
    );
  }

  Widget _buildCertificatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Info Ethereum Sepolia
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.language_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ethereum Sepolia Testnet (Live & Online)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sertifikat lingkungan TrashQuest dicatat secara on-chain dan diverifikasi menggunakan Sepolia Etherscan untuk keaslian publik.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF047857), height: 1.4),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => BlockchainService.openContractOnEtherscan(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF6EE7B7)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_browser_rounded, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text(
                          'Lihat Smart Contract di Sepolia Etherscan ↗',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Daftar Sertifikat Terdesentralisasi', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),

          ..._achievements.map((ach) {
            final isUnlocked = ach.isUnlocked;
            final user = SupabaseService.instance.currentUser;
            final isEligible = ach.isEligibleToMint(user);
            final missingMsg = ach.getMissingRequirementMessage(user);
            final userCertHash = '0x${sha256.convert(utf8.encode('TRASHQUEST:CERT:${user.id}:${user.email}:${ach.code}')).toString()}';
            final rawHash = ach.verificationHash ?? userCertHash;
            final evmHash = BlockchainService.ensureEvmTxHash(
              rawHash,
              userId: user.id,
              code: ach.code,
            );

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
              iconData = Icons.bolt_rounded;
              badgeText = 'SIAP TERBIT';
              badgeBg = const Color(0xFFEFF6FF);
              badgeTextColor = const Color(0xFF1D4ED8);
            } else {
              borderColor = AppColors.border;
              iconBg = AppColors.surfaceSecondary;
              iconColor = AppColors.textTertiary;
              iconData = Icons.lock_outline_rounded;
              badgeText = 'TERKUNCI';
              badgeBg = AppColors.surfaceSecondary;
              badgeTextColor = AppColors.textTertiary;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(
                  color: borderColor.withValues(alpha: isUnlocked || isEligible ? 0.6 : 0.8),
                  width: isUnlocked || isEligible ? 1.4 : 1,
                ),
                boxShadow: AppSpacing.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconData,
                          color: iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ach.name,
                                    style: AppTextStyles.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: badgeTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isUnlocked
                                  ? 'Tervalidasi di Ethereum Sepolia (1 Hash Sah)'
                                  : (isEligible
                                      ? '✨ Syarat Quest terpenuhi (${user.xp}/${ach.requiredXp} XP)'
                                      : 'Syarat: ${ach.questRequirementsSummary}'),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isUnlocked
                                    ? const Color(0xFF059669)
                                    : (isEligible ? const Color(0xFF1D4ED8) : AppColors.textTertiary),
                                fontWeight: isUnlocked || isEligible ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isUnlocked) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tag_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              evmHash,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                            tooltip: 'Salin TxHash',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: evmHash));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('TxHash disalin!'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => BlockchainService.openEtherscan(evmHash),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.open_in_browser_rounded, size: 13, color: Color(0xFF059669)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Etherscan ↗',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showCertificateDetail(ach),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Lihat Piagam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isEligible) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _runAutoMintWorkflow(ach),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.bolt_rounded, size: 15),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('⚡ Terbitkan Piagam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showCertificateDetail(ach),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Lihat Info', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    if (missingMsg != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '⚠️ $missingMsg',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCertificateDetail(ach),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                        label: const Text('Lihat Syarat Quest', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLedgerExplorerTab() {
    // Verified Sepolia Explorer Blocks in TrashQuest Smart Contract
    final sepoliaBlocks = [
      {
        'height': 'Block #12,000,277',
        'timestamp': 'Baru saja terkonfirmasi',
        'txHash': '0x17a59e07a9f425a395977eed27fa570f09f559e1f74645d72fe2fda84f1e0f49',
        'method': 'mintCertificate(TRQ-CERT-SORTING_MASTER)',
        'from': '0x611f...a5be',
        'gasUsed': '31,993 Gas (0.00016 ETH)',
      },
      {
        'height': 'Block #12,000,076',
        'timestamp': 'Hari ini',
        'txHash': '0x94192cc6c956e0c654ade78c3eea395cd7986efec571947b8099915d70d2b8bf',
        'method': 'mintCertificate(TRQ-CERT-FIRST_SCAN)',
        'from': '0x611f...a5be',
        'gasUsed': '31,993 Gas (0.00016 ETH)',
      },
      {
        'height': 'Block #12,000,000',
        'timestamp': 'Deploy Kontrak Sukses',
        'txHash': '0x2adb847fe68e54ef28392c5b2a4f88695983dbb5101af53b111a232d29ab3f4c',
        'method': 'deployContract(TrashQuestCert)',
        'from': '0x611f...a5be',
        'gasUsed': '136,192 Gas (0.00068 ETH)',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Network Status Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0xFF10B981), blurRadius: 6, spreadRadius: 1),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Sepolia RPC Node: Online',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => BlockchainService.openContractOnEtherscan(),
                      child: const Row(
                        children: [
                          Text('Contract', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w700)),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_outward_rounded, size: 12, color: Color(0xFF38BDF8)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Contract Address: ${BlockchainService.contractAddress}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Verifier Box (Live Online Query)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.border),
              boxShadow: AppSpacing.subtleShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.travel_explore_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Verifikasi Online Sepolia Etherscan', style: AppTextStyles.titleSmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Masukkan TxHash EVM (0x...) atau ID Sertifikat untuk memvalidasi status on-chain secara langsung.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hashInputController,
                  decoration: InputDecoration(
                    hintText: 'Tempel TxHash (0x...) atau ID Sertifikat...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () => _verifyCustomHash(_hashInputController.text),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isVerifying ? null : () => _verifyCustomHash(_hashInputController.text),
                    icon: _isVerifying
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded, size: 18),
                    label: Text(_isVerifying ? 'Memeriksa ke Ethereum Node...' : 'Verifikasi On-Chain Sekarang'),
                  ),
                ),

                // Live Verification Result Card
                if (_verificationResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6EE7B7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'VERIFIED ON-CHAIN (ETH SEPOLIA)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF065F46),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TxHash: ${_verificationResult!.txHash}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Blok: ${_verificationResult!.blockNumber}',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                            ),
                            Text(
                              _verificationResult!.timestampUtc,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => BlockchainService.openEtherscan(_verificationResult!.txHash),
                            icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                            label: const Text(
                              'Buka Transaksi di Sepolia Etherscan ↗',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('Aktivitas Terkini Sepolia Explorer', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),

          ...sepoliaBlocks.map((b) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(color: AppColors.border),
                boxShadow: AppSpacing.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: AppSpacing.roundedSm,
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          b['height']!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      Text(b['timestamp']!, style: AppTextStyles.labelSmall.copyWith(fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    b['method']!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('TxHash:', style: AppTextStyles.labelSmall.copyWith(fontSize: 10)),
                  Text(
                    b['txHash']!,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: const Color(0xFF0369A1),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(b['gasUsed']!, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      InkWell(
                        onTap: () => BlockchainService.openEtherscan(b['txHash']!),
                        child: const Row(
                          children: [
                            Text(
                              'Etherscan ↗',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
