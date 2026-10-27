import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/waste_item.dart';
import '../../data/models/quest_challenge.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';
import '../encyclopedia/waste_detail_view.dart';
import '../quest/waste_quiz_view.dart';
import '../quest/paw_toss_game.dart';
import 'widgets/notification_modal.dart';
import '../rewards/redeem_view.dart';

class HomeView extends StatefulWidget {
  final Function(int tabIndex) onNavigateTab;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenAssistant;
  final VoidCallback? onOpenProfile;

  const HomeView({
    super.key,
    required this.onNavigateTab,
    required this.onOpenScanner,
    required this.onOpenAssistant,
    this.onOpenProfile,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late UserProfile _profile;
  List<WasteItem> _educationItems = [];
  List<QuestChallenge> _quests = [];
  WasteCategory _selectedTipCategory = WasteCategory.organik;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animController.forward();
    SupabaseService.instance.addListener(_onProfileChanged);
    _loadData();
  }

  void _onProfileChanged() {
    if (mounted && !_isLoading) {
      SqliteService.instance.getQuests().then((quests) {
        if (mounted) {
          setState(() {
            _profile = SupabaseService.instance.currentUser;
            _quests = quests;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    SupabaseService.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _profile = SupabaseService.instance.currentUser;
    final items = await SqliteService.instance.getWasteTypes();
    final quests = await SqliteService.instance.getQuests();

    final eduItems = <WasteItem>[];
    for (final cat in [
      WasteCategory.organik,
      WasteCategory.anorganik,
      WasteCategory.b3,
      WasteCategory.residu,
    ]) {
      try {
        eduItems.add(items.firstWhere((e) => e.category == cat));
      } catch (_) {
        eduItems.add(WasteItem(
          id: 'fallback-${cat.name}',
          name: cat == WasteCategory.organik
              ? 'Sisa Sayur dan Kulit Buah'
              : cat == WasteCategory.anorganik
                  ? 'Botol Plastik PET Bening'
                  : cat == WasteCategory.b3
                      ? 'Baterai & Lampu Bekas'
                      : 'Styrofoam & Kemasan Residu',
          category: cat,
          description: cat == WasteCategory.organik
              ? 'Sampah organik basah yang mudah terurai dan dapat diolah menjadi kompos.'
              : cat == WasteCategory.anorganik
                  ? 'Sampah anorganik kering yang bernilai daur ulang tinggi di Bank Sampah.'
                  : cat == WasteCategory.b3
                      ? 'Limbah bahan berbahaya dan beracun yang memerlukan penanganan khusus.'
                      : 'Sampah residu yang tidak dapat didaur ulang dan harus ditekan timbulannya.',
          recyclable: cat == WasteCategory.organik || cat == WasteCategory.anorganik,
          disposalAdvice: cat == WasteCategory.organik
              ? 'Pisahkan sisa makanan dan dedaunan untuk pengomposan atau pakan maggot.'
              : cat == WasteCategory.anorganik
                  ? 'Bilas bersih, lipat/pipihkan, dan setorkan ke Bank Sampah.'
                  : cat == WasteCategory.b3
                      ? 'Bungkus rapat dan serahkan ke dropbox B3 resmi.'
                      : 'Gunakan wadah guna ulang dan kurangi pemakaian dari sumber.',
          decompositionTime: cat == WasteCategory.organik
              ? '2 - 4 minggu'
              : cat == WasteCategory.anorganik
                  ? '20 - 450 tahun'
                  : cat == WasteCategory.b3
                      ? 'Tidak terurai secara alami'
                      : 'Lebih dari 500 tahun',
          materialType: cat.displayName,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _educationItems = eduItems;
        _quests = quests;
        _isLoading = false;
      });
      _animController.forward(from: 0.0);
    }
  }

  Widget _buildAnimated(Widget child, int index) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval((index * 0.08).clamp(0.0, 0.7), 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animController,
          curve: Interval((index * 0.08).clamp(0.0, 0.7), 1.0, curve: Curves.easeIn),
        ),
        child: child,
      ),
    );
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
      default:
        return 'Master Ekologi';
    }
  }

  Widget _buildRealtimeMissionCard(QuestChallenge quest) {
    final canClaim = quest.progress >= quest.target && !quest.isClaimed;
    final isClaimed = quest.isClaimed;

    IconData questIcon;
    switch (quest.type) {
      case QuestType.scanWaste:
        questIcon = Icons.qr_code_scanner_rounded;
        break;
      case QuestType.visitWasteBank:
        questIcon = Icons.storefront_rounded;
        break;
      case QuestType.quiz:
        questIcon = Icons.psychology_alt_rounded;
        break;
      case QuestType.pawToss:
        questIcon = Icons.pets_rounded;
        break;
      case QuestType.sortWaste:
        questIcon = Icons.recycling_rounded;
        break;
    }

    Color iconBgColor = isClaimed
        ? const Color(0xFFF1F5F9)
        : (canClaim ? const Color(0xFFDCFCE7) : const Color(0xFFEFFDF5));
    Color iconColor = isClaimed
        ? const Color(0xFF64748B)
        : (canClaim ? const Color(0xFF15803D) : const Color(0xFF16A34A));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClaimed ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canClaim
              ? const Color(0xFF86EFAC)
              : (isClaimed ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0)),
          width: canClaim ? 1.4 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: canClaim
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClaimed ? Icons.check_circle_rounded : questIcon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isClaimed ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                    decoration: isClaimed ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (isClaimed)
                  const Text(
                    'Selesai • Hadiah telah diklaim',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (canClaim)
                  Text(
                    'Tercapai (${quest.progress}/${quest.target}) • Siap Diklaim!',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: quest.progressRatio,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${quest.progress} dari ${quest.target}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canClaim)
            ElevatedButton(
              onPressed: () async {
                final success = await SqliteService.instance.claimQuestReward(quest.id);
                if (success) {
                  _loadData();
                  NotificationService.instance.showNotification(
                    title: '🎉 Misi Diselesaikan!',
                    body: 'Hadiah +${quest.rewardXp} XP dari misi "${quest.title}" berhasil ditambahkan!',
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFF10B981),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 Berhasil klaim +${quest.rewardXp} XP!'),
                        backgroundColor: const Color(0xFF16A34A),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Klaim +${quest.rewardXp} XP',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            )
          else if (isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Diklaim ✓',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () {
                if (quest.type == QuestType.quiz) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WasteQuizView()),
                  ).then((_) => _loadData());
                } else if (quest.type == QuestType.pawToss) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackyardBattleScreen()),
                  ).then((_) {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    _loadData();
                  });
                } else if (quest.type == QuestType.scanWaste) {
                  widget.onOpenScanner();
                } else if (quest.type == QuestType.visitWasteBank) {
                  widget.onNavigateTab(1);
                } else if (quest.type == QuestType.sortWaste) {
                  widget.onNavigateTab(2);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                quest.type == QuestType.quiz
                    ? 'Mulai'
                    : (quest.type == QuestType.pawToss
                        ? 'Main'
                        : (quest.type == QuestType.scanWaste
                            ? 'Pindai'
                            : (quest.type == QuestType.visitWasteBank ? 'Peta' : 'Pilah'))),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAF8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 2.5),
        ),
      );
    }

    final totalKg = _profile.formattedSortedKg;
    final co2Kg = _profile.formattedCo2Kg;
    const monthlyTargetKg = 35.0;
    final currentWeightKg = _profile.totalSortedWeightKg;
    final progressFactor = (monthlyTargetKg > 0 ? (currentWeightKg / monthlyTargetKg) : 0.0).clamp(0.0, 1.0);
    final percentAchieved = (monthlyTargetKg > 0 ? ((currentWeightKg / monthlyTargetKg) * 100).round() : 0);
    final displayName = _profile.fullName.isNotEmpty ? _profile.fullName : 'Raditya Pratama';
    final levelTitle = _getLevelTitle(_profile.level);
    final xpValue = _profile.xp > 0 ? _profile.xp : 1250;
    final xpText = NumberFormat.decimalPattern('id').format(xpValue);
    final completedQuests = _quests.where((q) => q.isCompleted).length;
    final totalQuests = _quests.isNotEmpty ? _quests.length : 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: Stack(
        children: [
          AmbientBackground(
            heroHeight: 220,
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF16A34A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  MediaQuery.paddingOf(context).top + 8,
                  AppSpacing.screenPadding,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP HEADER: AVATAR + GREETING + NOTIFICATION BELL
                    _buildAnimated(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            UserAvatar(
                              profilePicture: _profile.avatarUrl,
                              radius: 23,
                              borderColor: const Color(0xFF16A34A),
                              borderWidth: 1.8,
                              enablePreview: false,
                              userName: _profile.fullName,
                              onTap: widget.onOpenProfile,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hallo, $displayName 👋',
                                    style: const TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Level ${_profile.level}: $levelTitle • $xpText XP',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // LOGO NOTIFIKASI
                            IconButton(
                              onPressed: () => NotificationModal.show(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.notifications_outlined, color: Color(0xFF334155), size: 21),
                                  ),
                                  ValueListenableBuilder<int>(
                                    valueListenable: NotificationService.instance.unreadCountNotifier,
                                    builder: (context, unreadCount, _) {
                                      if (unreadCount <= 0) return const SizedBox.shrink();
                                      return Positioned(
                                        top: 1,
                                        right: 1,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              tooltip: 'Pusat Notifikasi',
                            ),
                          ],
                        ),
                      ),
                      0,
                    ),

                    // 2. TARGET PILAH BULAN INI CARD (WARNA ASLI HIJAU & MINT, ZERO OVERFLOW)
                    _buildAnimated(
                      Container(
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEFFDF5), Color(0xFFE2F8EC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBBF7D0), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Badge & Deadline
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.eco_rounded, size: 14, color: Color(0xFF16A34A)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Target Bulanan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'Batas: 6 Hari Lagi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Big Metric Row: 28.4 / 35 kg & 81% Tercapai
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  totalKg,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Text(
                                  ' / 35 kg',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
                                  ),
                                  child: Text(
                                    '$percentAchieved% Tercapai',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Total Sampah Terpilah & Didaur Ulang',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),

                            // Ultra-smooth vector rounded progress bar (Zero pixelation)
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressFactor,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Sub-metrics: Karbon Dicegah & Poin Ekologis
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFDCFCE7), width: 1.0),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF1F5F9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.cloud_outlined, size: 14, color: Color(0xFF475569)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Karbon Dicegah',
                                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '$co2Kg kg',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RedeemView()),
                                    ).then((_) => _loadData()),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.0),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFDCFCE7),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF16A34A)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Poin Ekologis',
                                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${NumberFormat.decimalPattern('id').format(_profile.xp)} Poin',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      1,
                    ),
                    const SizedBox(height: 16),

                    // 3. SECTION: AKSI CEPAT (TAMPILAN SEBELUMNYA)
                    _buildAnimated(
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onOpenScanner,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
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
                                          padding: const EdgeInsets.all(10),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF22C55E),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                                        ),
                                        const Icon(Icons.arrow_outward_rounded, size: 16, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Pindai Sampah',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Deteksi via AI',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onNavigateTab(1),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
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
                                          padding: const EdgeInsets.all(10),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFDCFCE7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.location_on_rounded, color: Color(0xFF16A34A), size: 20),
                                        ),
                                        const Icon(Icons.arrow_outward_rounded, size: 16, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Bank Sampah',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Drop terdekat',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      2,
                    ),
                    const SizedBox(height: 22),

                    // 4. SECTION: MISI PILAH HARI INI (REALTIME DARI SQLITE/DATABASE)
                    _buildAnimated(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Misi Pilah Hari Ini ($completedQuests/$totalQuests Selesai)',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => widget.onNavigateTab(2),
                                child: const Text(
                                  'Semua Misi',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_quests.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Center(
                                child: Text(
                                  'Memuat misi hari ini...',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ] else ...[
                            ..._quests.take(3).map((q) => _buildRealtimeMissionCard(q)),
                          ],
                        ],
                      ),
                      3,
                    ),
                    const SizedBox(height: 20),

                // KABAR & TIPS KEBERLANJUTAN
                _buildAnimated(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.menu_book_rounded, color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Kabar & Tips Keberlanjutan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          final tip = _getTipContent(_selectedTipCategory);
                          _openWasteDetail(_selectedTipCategory, tip.imageAsset);
                        },
                        child: const Text(
                          'Jelajahi',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ],
                  ),
                  5,
                ),
                const SizedBox(height: 12),

                // Kategori Filter Chips: Organik, Anorganik, Limbah B3, Residu
                _buildAnimated(
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        _buildCategoryFilterChip(WasteCategory.organik, 'Organik', Icons.eco_rounded, const Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        _buildCategoryFilterChip(WasteCategory.anorganik, 'Anorganik', Icons.recycling_rounded, const Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        _buildCategoryFilterChip(WasteCategory.b3, 'Limbah B3', Icons.warning_amber_rounded, const Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        _buildCategoryFilterChip(WasteCategory.residu, 'Residu', Icons.delete_outline_rounded, const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                  6,
                ),
                const SizedBox(height: 14),

                // CARD 1: Featured Post (sesuai kategori terpilih)
                _buildAnimated(
                  _buildFeaturedTipCard(_getTipContent(_selectedTipCategory)),
                  7,
                ),
                const SizedBox(height: 12),

                // CARD 2: Compact Post (sesuai kategori terpilih)
                _buildAnimated(
                  _buildCompactTipCard(_getTipContent(_selectedTipCategory)),
                  8,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 20,
        right: 18,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpenAssistant,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF065F46).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_rounded, color: Color(0xFF6EE7B7), size: 19),
                  SizedBox(width: 6),
                  Text(
                    'Tanya AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildCategoryFilterChip(
    WasteCategory category,
    String label,
    IconData icon,
    Color categoryColor,
  ) {
    final isSelected = _selectedTipCategory == category;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTipCategory = category;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? categoryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? categoryColor : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : categoryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWasteDetail(WasteCategory category, String imageUrl) {
    WasteItem? targetItem;
    try {
      targetItem = _educationItems.firstWhere((e) => e.category == category);
    } catch (_) {
      targetItem = null;
    }

    final item = targetItem ??
        WasteItem(
          id: 'edu-${category.name}',
          name: category.displayName,
          category: category,
          description: 'Edukasi dan panduan pemilahan sampah ${category.displayName}.',
          recyclable: category == WasteCategory.organik || category == WasteCategory.anorganik,
          disposalAdvice: 'Pilah secara bertanggung jawab sesuai panduan yang berlaku.',
          decompositionTime: category == WasteCategory.organik ? '2 - 4 minggu' : 'Ratusan tahun',
          materialType: category.displayName,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WasteDetailView(
          item: item,
          imageUrl: imageUrl,
          onFindBankSampah: () {
            widget.onNavigateTab(1);
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedTipCard(_TipContent tip) {
    return GestureDetector(
      onTap: () => _openWasteDetail(tip.category, tip.imageAsset),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.asset(
                    tip.imageAsset,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: tip.badgeColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tip.categoryBadge,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tip.badgeColor),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF334155)),
                        const SizedBox(width: 4),
                        Text(
                          tip.readTime,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.featuredTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.featuredDesc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: tip.badgeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          'TQ',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tip.badgeColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'TrashQuest Editorial',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTipCard(_TipContent tip) {
    return GestureDetector(
      onTap: () => _openWasteDetail(tip.category, tip.imageAsset),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Image.asset(
                  tip.imageAsset,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.compactTag,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tip.badgeColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tip.compactTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        tip.compactTime,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '• ${tip.compactSubtitle}',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  _TipContent _getTipContent(WasteCategory category) {
    switch (category) {
      case WasteCategory.organik:
        return const _TipContent(
          category: WasteCategory.organik,
          categoryBadge: 'Panduan Praktis • Organik',
          badgeColor: Color(0xFF16A34A),
          imageAsset: 'assets/images/organik.jpg',
          readTime: '3 mnt baca',
          featuredTitle: '5 Langkah Mudah Memulai Kompos Organik Rumahan Tanpa Bau',
          featuredDesc: 'Ubah sisa sayuran dapur dan kulit buah menjadi pupuk kompos kaya nutrisi bagi tanaman hias tanpa mengundang hama dan bau menyengat.',
          compactTag: 'Teknik Biopori',
          compactTitle: 'Membuat Lubang Biopori Sederhana di Pekarangan Rumah',
          compactTime: '2 jam yang lalu',
          compactSubtitle: 'Resapkan air hujan & olah sampah organik mandiri.',
        );
      case WasteCategory.anorganik:
        return const _TipContent(
          category: WasteCategory.anorganik,
          categoryBadge: 'Wawasan Daur Ulang • Anorganik',
          badgeColor: Color(0xFF2563EB),
          imageAsset: 'assets/images/anorganik.jpg',
          readTime: '4 mnt baca',
          featuredTitle: 'Arti Kode Simbol Daur Ulang Plastik 1–7 & Panduan Bank Sampah',
          featuredDesc: 'Kenali perbedaan botol PET, HDPE, hingga kardus yang bernilai jual tinggi sebelum menyetor ke bank sampah terdekat.',
          compactTag: 'Kardus & Kertas',
          compactTitle: 'Cara Tepat Melipat & Menyimpan Kardus Agar Bernilai Tinggi',
          compactTime: '1 jam yang lalu',
          compactSubtitle: 'Kardus kering dihargai lebih tinggi di bank sampah.',
        );
      case WasteCategory.b3:
        return const _TipContent(
          category: WasteCategory.b3,
          categoryBadge: 'Bahaya & Regulasi • Limbah B3',
          badgeColor: Color(0xFFDC2626),
          imageAsset: 'assets/images/b3.jpg',
          readTime: '5 mnt baca',
          featuredTitle: 'Prosedur Aman Membuang Baterai, Lampu Neon, & E-Waste Beracun',
          featuredDesc: 'Jangan campur baterai bekas dan lampu neon ke tong biasa untuk mencegah bahaya kebocoran uap merkuri dan logam berat ke tanah.',
          compactTag: 'Dropbox Resmi',
          compactTitle: 'Titik Pengumpulan & Drop-Box Limbah B3 Rumah Tangga',
          compactTime: '3 jam yang lalu',
          compactSubtitle: 'Daftar lokasi penampungan limbah berbahaya berstandar.',
        );
      case WasteCategory.residu:
        return const _TipContent(
          category: WasteCategory.residu,
          categoryBadge: 'Edukasi Khusus • Residu',
          badgeColor: Color(0xFF64748B),
          imageAsset: 'assets/images/residu.jpg',
          readTime: '3 mnt baca',
          featuredTitle: 'Mengenal Sampah Residu: Styrofoam, Popok, & Sachet Non-Recycle',
          featuredDesc: 'Sampah residu tidak dapat didaur ulang dan butuh 500+ tahun terurai di TPA. Pelajari strategi bijak mengurangi timbulannya dari rumah.',
          compactTag: 'Gaya Hidup Minim Sampah',
          compactTitle: '3 Alternatif Pengganti Kemasan Styrofoam Sekali Pakai',
          compactTime: '5 jam yang lalu',
          compactSubtitle: 'Gunakan wadah guna ulang untuk menekan timbulan residu.',
        );
    }
  }
}

class _TipContent {
  final WasteCategory category;
  final String categoryBadge;
  final Color badgeColor;
  final String imageAsset;
  final String readTime;
  final String featuredTitle;
  final String featuredDesc;
  final String compactTag;
  final String compactTitle;
  final String compactTime;
  final String compactSubtitle;

  const _TipContent({
    required this.category,
    required this.categoryBadge,
    required this.badgeColor,
    required this.imageAsset,
    required this.readTime,
    required this.featuredTitle,
    required this.featuredDesc,
    required this.compactTag,
    required this.compactTitle,
    required this.compactTime,
    required this.compactSubtitle,
  });
}
