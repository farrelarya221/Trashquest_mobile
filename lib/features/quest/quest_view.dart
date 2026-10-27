import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/quest_challenge.dart';
import '../../data/models/user_profile.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import '../blockchain/blockchain_view.dart';
import '../home/widgets/notification_modal.dart';
import 'trash_sorter_game_view.dart';
import 'trash_ninja_game_view.dart';
import 'waste_quiz_view.dart';
import 'bio_eater_game_view.dart';
import 'paw_toss_game.dart';
import '../../app/theme/app_spacing.dart';
import '../rewards/redeem_view.dart';

class QuestView extends StatefulWidget {
  final VoidCallback? onOpenProfile;

  const QuestView({super.key, this.onOpenProfile});

  @override
  State<QuestView> createState() => _QuestViewState();
}

class _QuestViewState extends State<QuestView> {
  int _selectedTab = 0; // 0 = Mini-Games Edukasi, 1 = Papan Peringkat
  int _leaderboardPeriod = 0; // 0 = Minggu Ini, 1 = Bulan Ini, 2 = All-Time
  List<QuestChallenge> _quests = [];
  bool _isLoading = true;
  StreamSubscription? _leaderboardSub;
  List<Map<String, dynamic>> _remoteLeaderboard = [];

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.addListener(_onUserDataChanged);
    _loadQuests();
    _initLeaderboard();
  }

  void _onUserDataChanged() {
    if (mounted) {
      _loadQuests();
    }
  }

  void _initLeaderboard() {
    _loadRemoteLeaderboard();
    final stream = SupabaseService.instance.getLeaderboardStream();
    if (stream != null) {
      _leaderboardSub = stream.listen((data) {
        if (mounted) {
          setState(() {
            _remoteLeaderboard = data;
          });
        }
      }, onError: (err) {
        debugPrint('Leaderboard stream error: $err');
      });
    }
  }

  Future<void> _loadRemoteLeaderboard() async {
    final data = await SupabaseService.instance.fetchLeaderboardUsers();
    if (mounted && data.isNotEmpty) {
      setState(() {
        _remoteLeaderboard = data;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadQuests(),
      _loadRemoteLeaderboard(),
    ]);
  }

  @override
  void dispose() {
    SupabaseService.instance.removeListener(_onUserDataChanged);
    _leaderboardSub?.cancel();
    super.dispose();
  }

  bool _isChestClaimedToday = false;

  Future<void> _checkChestClaimStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = SupabaseService.instance.currentUser.id.isNotEmpty
        ? SupabaseService.instance.currentUser.id
        : 'guest';
    final todayKey = 'daily_chest_claimed_${userId}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    final claimed = prefs.getBool(todayKey) ?? false;
    if (mounted) {
      setState(() {
        _isChestClaimedToday = claimed;
      });
    }
  }

  Future<void> _loadQuests() async {
    final quests = await SqliteService.instance.getQuests();
    await _checkChestClaimStatus();
    if (mounted) {
      setState(() {
        _quests = quests;
        _isLoading = false;
      });
    }
  }

  Future<void> _claimChestReward() async {
    if (_isChestClaimedToday) return;

    final completedCount = _quests.where((q) => q.isCompleted).length;
    if (completedCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selesaikan minimal 3 misi harian untuk membuka peti ini! ($completedCount/3 selesai)'),
          backgroundColor: const Color(0xFFE11D48),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = SupabaseService.instance.currentUser.id.isNotEmpty
        ? SupabaseService.instance.currentUser.id
        : 'guest';
    final todayKey = 'daily_chest_claimed_${userId}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    await prefs.setBool(todayKey, true);

    setState(() {
      _isChestClaimedToday = true;
    });

    SupabaseService.instance.addXp(100);
    NotificationService.instance.showNotification(
      title: '🎁 Hadiah Peti Misi Terbuka!',
      body: 'Selamat! Kamu berhasil membuka Peti Misi Harian dan mendapatkan +100 XP.',
      icon: Icons.card_giftcard_rounded,
      iconColor: const Color(0xFF10B981),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Berhasil klaim Peti Misi! +100 XP ditambahkan.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _claimQuest(QuestChallenge quest) async {
    if (quest.isClaimed) return;
    final success = await SqliteService.instance.claimQuestReward(quest.id);
    if (success) {
      await _loadQuests();
      if (mounted) {
        NotificationService.instance.showNotification(
          title: '🎉 Misi Diselesaikan!',
          body: 'Hadiah +${quest.rewardXp} XP dari misi "${quest.title}" berhasil ditambahkan!',
          icon: Icons.emoji_events_rounded,
          iconColor: const Color(0xFF10B981),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Berhasil mengklaim +${quest.rewardXp} XP!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.screenPadding,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TrashQuest',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RedeemView()),
                ).then((_) {
                  if (mounted) setState(() {});
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_rounded, size: 11, color: Color(0xFF16A34A)),
                      const SizedBox(width: 3),
                      Text(
                        '${NumberFormat.decimalPattern('id').format(user.xp)} XP',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenPadding),
            child: IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Color(0xFF334155), size: 20),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: NotificationService.instance.unreadCountNotifier,
                    builder: (context, unreadCount, _) {
                      if (unreadCount <= 0) return const SizedBox.shrink();
                      return Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 9, minHeight: 9),
                        ),
                      );
                    },
                  ),
                ],
              ),
              tooltip: 'Pusat Notifikasi',
              onPressed: () => NotificationModal.show(context),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: _refreshAll,
              color: const Color(0xFF10B981),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title & Subtitle matching aesthetic of Beranda
                    const Text(
                      'Quest Dan Game',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Selesaikan misi harian dan raih skor tertinggi di mini-game.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                      // Segmented Tab Switcher (Mini-Games Edukasi vs Papan Peringkat)
                      _buildSegmentedSwitcher(),
                      const SizedBox(height: 18),

                      if (_selectedTab == 0) ...[
                        // Seasonal Event Card Banner
                        _buildSeasonalEventBanner(),
                        const SizedBox(height: 18),

                        // Daily Mission Progress Bar Card
                        _buildDailyMissionCard(),
                        const SizedBox(height: 22),

                        // Arcade Mini-Games Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.videogame_asset_rounded, color: Color(0xFF10B981), size: 22),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Arcade Mini-Games',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '5 Game Tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Game 1: Bio-Eater: Plastic Hunter
                        _buildGameCard(
                          title: 'Bio-Eater: Plastic Hunter',
                          description: 'Kendalikan amoeba mutan pembersih untuk melahap mikroplastik sebelum...',
                          tag1: 'Unggulan',
                          tag1Color: const Color(0xFF10B981),
                          tag2: 'Aksi Mikro',
                          bestScore: '14.850',
                          xpReward: '+200 XP',
                          icon: Icons.bubble_chart_rounded,
                          iconGradient: const [Color(0xFF34D399), Color(0xFF059669)],
                          onPlay: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BioEaterGameView()),
                            ).then((_) => _loadQuests());
                          },
                        ),

                        // Game 2: Trash Sorter
                        _buildGameCard(
                          title: 'Trash Sorter',
                          description: 'Goyangkan dan miringkan smartphone untuk mengarahkan sampah ke tong...',
                          tag1: 'Sensor Gyro',
                          tag1Color: const Color(0xFF059669),
                          tag2: 'Fokus Keseimbangan',
                          bestScore: '8.420',
                          xpReward: '+120 XP',
                          icon: Icons.screen_rotation_rounded,
                          iconGradient: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
                          onPlay: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TrashSorterGameView()),
                            ).then((_) => _loadQuests());
                          },
                        ),

                        // Game 3: Paw Toss: Dog vs Cat
                        _buildGameCard(
                          title: 'Paw Toss: Dog vs Cat',
                          description: 'Perhitungkan sudut lemparan dan hembusan angin untuk memasukkan...',
                          tag1: 'Fisika Seru',
                          tag1Color: const Color(0xFF0D9488),
                          tag2: 'Duel Karakter',
                          bestScore: '22 Streaks',
                          xpReward: '+150 XP',
                          icon: Icons.pets_rounded,
                          iconGradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
                          onPlay: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BackyardBattleScreen()),
                            ).then((_) {
                              SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                              _loadQuests();
                            });
                          },
                        ),

                        // Game 4: Trash Ninja
                        _buildGameCard(
                          title: 'Trash Ninja',
                          description: 'Tebas cepat sampah organik dan anorganik yang melayang di layar...',
                          tag1: 'Swipe Cepat',
                          tag1Color: const Color(0xFF059669),
                          tag2: 'Refleks',
                          bestScore: '31.200',
                          xpReward: '+180 XP',
                          icon: Icons.flash_on_rounded,
                          iconGradient: const [Color(0xFFF87171), Color(0xFFDC2626)],
                          onPlay: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TrashNinjaGameView()),
                            ).then((_) => _loadQuests());
                          },
                        ),

                        // Game 5: Kuis Pilah Cerdas
                        _buildGameCard(
                          title: 'Kuis Pilah Cerdas',
                          description: 'Uji ketelitianmu mengenai simbol resin daur ulang plastik, masa urai kardus...',
                          tag1: 'Edukasi +150 XP',
                          tag1Color: const Color(0xFF10B981),
                          tag2: '10 Soal',
                          bestScore: '10/10 Benar',
                          xpReward: '+150 XP',
                          icon: Icons.menu_book_rounded,
                          iconGradient: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
                          onPlay: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WasteQuizView()),
                            ).then((_) => _loadQuests());
                          },
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Live Community Leaderboard Screen
                        _buildLeaderboardSection(user),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }



  // Segmented Pill Bar: [ 🎮 Mini-Games Edukasi ]  [ 🏛️ Papan Peringkat ]
  Widget _buildSegmentedSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 0),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_esports_rounded,
                        size: 17,
                        color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mini-Games Edukasi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 1),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.leaderboard_rounded,
                        size: 17,
                        color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Papan Peringkat',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569),
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

  // Seasonal Event Banner (Battle Lempar Sampah: Dog vs Cat)
  Widget _buildSeasonalEventBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Top Illustration with Photo
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/paw_battle_banner.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/paw_toss_banner.jpg',
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pets_rounded, size: 13, color: Color(0xFFD97706)),
                      SizedBox(width: 5),
                      Text(
                        'Event Spesial: Battle Anjing vs Kucing',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Sisa 3 Hari',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Banner Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Battle Lempar Sampah: Dog vs Cat',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Duel lempar-lemparan seru melewati pagar halaman! Perhitungkan arah angin & sudut tembakan, lalu lempar kaleng, sandal, dan tulang daur ulang ke arah lawan untuk memenangkan duel!',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hadiah Battle',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '+500 XP Pool',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BackyardBattleScreen()),
                        ).then((_) {
                          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                          _loadQuests();
                        });
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sports_esports_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Mulai Battle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Daily Mission Card: Misi Harian Pembersih
  Widget _buildDailyMissionCard() {
    final completedCount = _quests.where((q) => q.isCompleted).length;
    final totalCount = _quests.isNotEmpty ? _quests.length : 6;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 17),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Misi Harian Pembersih',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$completedCount dari $totalCount Selesai',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Progress Update Otomatis Real-time',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _claimChestReward,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isChestClaimedToday
                        ? const Color(0xFFF1F5F9)
                        : (completedCount >= 3 ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isChestClaimedToday
                          ? const Color(0xFFCBD5E1)
                          : (completedCount >= 3 ? const Color(0xFF86EFAC) : Colors.transparent),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isChestClaimedToday ? Icons.check_circle_rounded : Icons.card_giftcard_rounded,
                        size: 14,
                        color: _isChestClaimedToday
                            ? const Color(0xFF64748B)
                            : (completedCount >= 3 ? const Color(0xFF15803D) : const Color(0xFF334155)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isChestClaimedToday
                            ? 'Peti Diklaim ✓'
                            : (completedCount >= 3 ? 'Klaim Peti (+100 XP)' : 'Peti ($completedCount/3)'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isChestClaimedToday
                              ? const Color(0xFF64748B)
                              : (completedCount >= 3 ? const Color(0xFF15803D) : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_quests.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),
            ..._quests.map((q) => _buildQuestTile(q)),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestTile(QuestChallenge quest) {
    final canClaim = quest.progress >= quest.target && !quest.isClaimed;
    final isClaimed = quest.isClaimed;

    IconData icon;
    switch (quest.type) {
      case QuestType.scanWaste:
        icon = Icons.qr_code_scanner_rounded;
        break;
      case QuestType.visitWasteBank:
        icon = Icons.storefront_rounded;
        break;
      case QuestType.quiz:
        icon = Icons.psychology_alt_rounded;
        break;
      case QuestType.pawToss:
        icon = Icons.pets_rounded;
        break;
      case QuestType.sortWaste:
        icon = Icons.recycling_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isClaimed ? const Color(0xFFF8FAFC) : const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canClaim
              ? const Color(0xFF86EFAC)
              : (isClaimed ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isClaimed
                  ? const Color(0xFFE2E8F0)
                  : (canClaim ? const Color(0xFFDCFCE7) : const Color(0xFFEFFDF5)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClaimed ? Icons.check_circle_rounded : icon,
              size: 16,
              color: isClaimed
                  ? const Color(0xFF64748B)
                  : (canClaim ? const Color(0xFF15803D) : const Color(0xFF16A34A)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isClaimed ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                    decoration: isClaimed ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (isClaimed)
                  const Text(
                    'Selesai • Hadiah telah diklaim',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                  )
                else if (canClaim)
                  Text(
                    'Tercapai (${quest.progress}/${quest.target}) • Siap Klaim!',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                  )
                else
                  Text(
                    'Progress: ${quest.progress}/${quest.target}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canClaim)
            ElevatedButton(
              onPressed: () => _claimQuest(quest),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Klaim +${quest.rewardXp} XP',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else if (isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Diklaim ✓',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+${quest.rewardXp} XP',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
            ),
        ],
      ),
    );
  }

  // Individual Arcade Game Card matching Screenshot 3
  Widget _buildGameCard({
    required String title,
    required String description,
    required String tag1,
    required Color tag1Color,
    required String tag2,
    required String bestScore,
    required String xpReward,
    required IconData icon,
    required List<Color> iconGradient,
    required VoidCallback onPlay,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular Game Icon
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tag1Color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: tag1Color,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag2,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 32,
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_outlined, size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Skor: $bestScore',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      xpReward,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(106, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onPlay,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 16),
                    SizedBox(width: 2),
                    Text(
                      'Mulai Main',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Leaderboard Section when Tab 1 is active (Papan Peringkat Warga)
  Widget _buildLeaderboardSection(UserProfile currentUser) {
    final members = _getLeaderboardEntries(currentUser);
    final formatter = NumberFormat.decimalPattern('id');

    final myIndex = members.indexWhere((m) => m.isMe);
    final myRank = myIndex != -1 ? myIndex + 1 : 1;
    final userMember = myIndex != -1
        ? members[myIndex]
        : _LeaderboardMember(
            id: currentUser.id,
            name: currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Kamu',
            xp: currentUser.xp,
            level: currentUser.level,
            isMe: true,
            avatarInitials: 'K',
          );

    final _LeaderboardMember? firstMember = members.isNotEmpty ? members[0] : null;
    final _LeaderboardMember? secondMember = members.length > 1 ? members[1] : null;
    final _LeaderboardMember? thirdMember = members.length > 2 ? members[2] : null;

    // Remaining members from rank 4 onwards, skipping the current user if already highlighted in user card
    final remainingMembers = members.skip(3).toList();

    // Calculate gap to Top 3
    String gapText;
    if (myRank <= 3) {
      gapText = '🎉 Hebat! Kamu bertahan di Top 3 Komunitas!';
    } else if (thirdMember != null) {
      final neededXp = (thirdMember.xp - userMember.xp) + 1;
      gapText = 'Butuh ${formatter.format(neededXp > 0 ? neededXp : 50)} XP lagi untuk masuk Top 3!';
    } else {
      gapText = 'Kumpulkan lebih banyak XP dari pilah sampah!';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Papan Peringkat Warga',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                  SizedBox(width: 4),
                  Text(
                    'Realtime',
                    style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Time Period Filter Pills: [ Minggu Ini ]  [ Bulan Ini ]  [ All-Time ]
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildTimeFilterPill('Minggu Ini', 0),
              _buildTimeFilterPill('Bulan Ini', 1),
              _buildTimeFilterPill('All-Time', 2),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Top 3 Podium
        if (firstMember != null && secondMember != null && thirdMember != null)
          _buildPodiumSection(firstMember, secondMember, thirdMember, formatter),

        const SizedBox(height: 20),

        // Highlighted Current User Card
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF0F172A), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                '#$myRank',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    userMember.avatarInitials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kamu (${userMember.name})',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gapText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: myRank <= 3 ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatter.format(userMember.xp)} XP',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),

        // List of other ranks (#5, #6, #7, etc.)
        ...remainingMembers.map((m) {
          final rank = members.indexOf(m) + 1;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Center(
                    child: Text(
                      m.avatarInitials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${formatter.format(m.xp)} XP',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 14),

        // Bottom Blockchain Ledger Verification Button
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockchainView())),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0F172A), width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_outlined, size: 16, color: Color(0xFF0F172A)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Terverifikasi pada Konsorsium Ledger Blockchain',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeFilterPill(String title, int index) {
    final isSelected = _leaderboardPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _leaderboardPeriod = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumSection(
    _LeaderboardMember first,
    _LeaderboardMember second,
    _LeaderboardMember third,
    NumberFormat formatter,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank #2 (Left)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPodiumAvatar(
                member: second,
                rank: 2,
                ringColor: const Color(0xFF94A3B8),
                badgeColor: const Color(0xFF64748B),
              ),
              const SizedBox(height: 6),
              Text(
                second.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '${formatter.format(second.xp)} XP',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                height: 95,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: const Center(
                  child: Text(
                    '#2',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Rank #1 (Center - Tallest & Crowned)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('👑', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 3),
                  Text(
                    '#1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              _buildPodiumAvatar(
                member: first,
                rank: 1,
                ringColor: const Color(0xFFF59E0B),
                badgeColor: const Color(0xFFD97706),
                isFirst: true,
              ),
              const SizedBox(height: 6),
              Text(
                first.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '${formatter.format(first.xp)} XP',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFFD97706)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border.all(color: const Color(0xFF334155), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '#1',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Rank #3 (Right)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPodiumAvatar(
                member: third,
                rank: 3,
                ringColor: const Color(0xFFD97706),
                badgeColor: const Color(0xFFC2410C),
              ),
              const SizedBox(height: 6),
              Text(
                third.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '${formatter.format(third.xp)} XP',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                height: 75,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border.all(color: const Color(0xFF0F172A), width: 1.3),
                ),
                child: const Center(
                  child: Text(
                    '#3',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumAvatar({
    required _LeaderboardMember member,
    required int rank,
    required Color ringColor,
    required Color badgeColor,
    bool isFirst = false,
  }) {
    final double size = isFirst ? 58 : 50;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: ringColor, width: isFirst ? 3.0 : 2.2),
        boxShadow: [
          BoxShadow(
            color: ringColor.withValues(alpha: isFirst ? 0.35 : 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          member.avatarInitials,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: isFirst ? 19 : 16,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  List<_LeaderboardMember> _getLeaderboardEntries(UserProfile currentUser) {
    // Period multipliers: 0 = Minggu Ini, 1 = Bulan Ini, 2 = All-Time
    final double periodMult = _leaderboardPeriod == 0 ? 0.65 : (_leaderboardPeriod == 1 ? 1.0 : 2.4);

    final benchmarkPeers = [
      _LeaderboardMember(id: 'bm-1', name: 'Dimas Satria', xp: (2430 * periodMult).round(), level: 10, isMe: false, avatarInitials: 'DS'),
      _LeaderboardMember(id: 'bm-2', name: 'Nadia P.', xp: (2180 * periodMult).round(), level: 9, isMe: false, avatarInitials: 'NP'),
      _LeaderboardMember(id: 'bm-3', name: 'Rian P.', xp: (1620 * periodMult).round(), level: 7, isMe: false, avatarInitials: 'RP'),
      _LeaderboardMember(id: 'bm-4', name: 'Siti Rahma', xp: (1180 * periodMult).round(), level: 5, isMe: false, avatarInitials: 'SR'),
      _LeaderboardMember(id: 'bm-5', name: 'Budi Handoko', xp: (950 * periodMult).round(), level: 4, isMe: false, avatarInitials: 'BH'),
      _LeaderboardMember(id: 'bm-6', name: 'Agus Setiawan', xp: (890 * periodMult).round(), level: 3, isMe: false, avatarInitials: 'AS'),
      _LeaderboardMember(id: 'bm-7', name: 'Maya Lestari', xp: (740 * periodMult).round(), level: 3, isMe: false, avatarInitials: 'ML'),
    ];

    final Map<String, _LeaderboardMember> memberMap = {};

    for (final p in benchmarkPeers) {
      memberMap[p.id] = p;
    }

    for (final raw in _remoteLeaderboard) {
      final id = raw['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final isMe = id == currentUser.id;
      final rawName = raw['full_name']?.toString() ?? 'Eco Warrior';
      final xp = (raw['xp'] as num?)?.toInt() ?? 0;
      final adjustedXp = (xp * periodMult).round();
      final level = (raw['level'] as num?)?.toInt() ?? ((xp ~/ 250) + 1);

      memberMap[id] = _LeaderboardMember(
        id: id,
        name: isMe ? (currentUser.fullName.isNotEmpty ? currentUser.fullName : rawName) : rawName,
        xp: isMe ? (currentUser.xp * periodMult).round() : adjustedXp,
        level: isMe ? currentUser.level : level,
        isMe: isMe,
        avatarInitials: rawName.isNotEmpty ? rawName.substring(0, 1).toUpperCase() : 'W',
      );
    }

    final userXp = (currentUser.xp * periodMult).round();
    final userName = currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Raditya Pratama';
    memberMap[currentUser.id] = _LeaderboardMember(
      id: currentUser.id,
      name: userName,
      xp: userXp,
      level: currentUser.level,
      isMe: true,
      avatarInitials: userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'K',
    );

    final sorted = memberMap.values.toList();
    sorted.sort((a, b) {
      final cmp = b.xp.compareTo(a.xp);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    return sorted;
  }
}

class _LeaderboardMember {
  final String id;
  final String name;
  final int xp;
  final int level;
  final bool isMe;
  final String avatarInitials;

  const _LeaderboardMember({
    required this.id,
    required this.name,
    required this.xp,
    required this.level,
    required this.isMe,
    this.avatarInitials = 'W',
  });
}
