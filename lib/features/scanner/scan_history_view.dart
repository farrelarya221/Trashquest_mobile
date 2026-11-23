import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/category_badge.dart';
import '../../data/models/quest_challenge.dart';
import '../../data/models/waste_scan.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';

class ScanHistoryView extends StatefulWidget {
  const ScanHistoryView({super.key});

  @override
  State<ScanHistoryView> createState() => _ScanHistoryViewState();
}

class _ScanHistoryViewState extends State<ScanHistoryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WasteScan> _scans = [];
  List<Map<String, dynamic>> _deposits = [];
  bool _isLoadingScans = true;
  bool _isLoadingDeposits = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final user = SupabaseService.instance.currentUser;
    final scans = await SqliteService.instance.getScans(userId: user.id);
    final txs = await SqliteService.instance.getTransactions(userId: user.id);

    if (mounted) {
      setState(() {
        _scans = scans;
        _deposits = txs;
        _isLoadingScans = false;
        _isLoadingDeposits = false;
      });
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    final count = await SyncService.instance.syncPendingData();
    await _loadAllData();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0 ? '✓ $count data berhasil disinkronkan ke cloud!' : 'Semua data sudah tersinkronisasi.',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDepositDialog() {
    final weightCtrl = TextEditingController(text: '1.0');
    String selectedCategory = 'Plastik (Botol / Gelas)';
    String selectedBank = 'Bank Sampah Mandiri (Pusat)';

    final categories = [
      'Plastik (Botol / Gelas)',
      'Kardus & Kertas Kering',
      'Logam & Kaleng Aluminium',
      'Kaca & Botol Beling',
      'Minyak Jelantah & B3',
    ];

    final banks = [
      'Bank Sampah Mandiri (Pusat)',
      'TPS 3R Hijau Lestari',
      'Smart Drop Box Kampus',
      'Bank Sampah Berkah Daur Ulang',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final weight = double.tryParse(weightCtrl.text) ?? 1.0;
          final earnedPoints = (weight * 50).round();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.recycling_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text('Catat Setoran Sampah TPS', style: AppTextStyles.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Material Sampah',
                      prefixIcon: Icon(Icons.category_rounded, size: 20),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppTextStyles.bodyMedium))).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Tujuan Bank Sampah / TPS',
                      prefixIcon: Icon(Icons.location_on_rounded, size: 20),
                    ),
                    items: banks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: AppTextStyles.bodyMedium))).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedBank = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Estimasi Berat (Kg)',
                      prefixIcon: Icon(Icons.scale_rounded, size: 20),
                      suffixText: 'kg',
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Estimasi Poin Diperoleh:', style: AppTextStyles.bodySmall),
                        const Spacer(),
                        Text('+$earnedPoints Poin & XP', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final w = double.tryParse(weightCtrl.text) ?? 1.0;
                      final pts = (w * 50).round();
                      final user = SupabaseService.instance.currentUser;

                      await SqliteService.instance.insertTransaction({
                        'id': 'dep-${DateTime.now().millisecondsSinceEpoch}',
                        'user_id': user.id,
                        'item_name': 'Setor $selectedCategory ($w kg)',
                        'cost': pts,
                        'type': 'deposit',
                        'created_at': DateTime.now().toIso8601String(),
                        'account_info': selectedBank,
                        'status': 'Berhasil',
                      });

                      SupabaseService.instance.addXp(pts);
                      SupabaseService.instance.incrementSortedCount(w.round().clamp(1, 100));
                      await SqliteService.instance.incrementQuestProgressByType(QuestType.visitWasteBank, amount: 1);

                      await _loadAllData();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Berhasil menyetor $w kg sampah! +$pts Poin ditambahkan ke akun ${user.fullName}.'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Konfirmasi Penyetoran'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Riwayat Pindai & Penyetoran', style: AppTextStyles.titleMedium),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sinkronisasi ke Cloud',
            onPressed: _isSyncing ? null : _syncData,
          ),
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            tooltip: 'Catat Setoran TPS',
            onPressed: _showDepositDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.qr_code_scanner_rounded, size: 20),
              text: 'Riwayat Pindai',
            ),
            Tab(
              icon: Icon(Icons.inventory_2_outlined, size: 20),
              text: 'Riwayat Penyetoran',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Riwayat Pindai AI
          _buildScanHistoryTab(),

          // Tab 2: Riwayat Penyetoran & Transaksi
          _buildDepositHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDepositDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catat Setoran TPS', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildScanHistoryTab() {
    if (_isLoadingScans) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }

    if (_scans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_rounded, size: 54, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Belum ada riwayat pindai', style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Riwayat pindai terisolasi untuk setiap akun. Pindai sampah pertamamu dengan AI Scanner!',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.screenPadding, AppSpacing.screenPadding, 80),
      itemCount: _scans.length,
      itemBuilder: (context, index) {
        final scan = _scans[index];
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
                  Expanded(
                    child: Text(scan.detectedName, style: AppTextStyles.titleSmall),
                  ),
                  CategoryBadge(category: scan.category, isCompact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(scan.disposalAdvice, style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${scan.createdAt.day.toString().padLeft(2, '0')}/${scan.createdAt.month.toString().padLeft(2, '0')}/${scan.createdAt.year} • ${scan.createdAt.hour.toString().padLeft(2, '0')}:${scan.createdAt.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.labelSmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        scan.isSynced ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                        size: 15,
                        color: scan.isSynced ? AppColors.success : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        scan.isSynced ? 'Synced' : 'Lokal',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: scan.isSynced ? AppColors.success : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDepositHistoryTab() {
    if (_isLoadingDeposits) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }

    if (_deposits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Belum ada riwayat penyetoran', style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Data penyetoran terisolasi secara khusus untuk akun ini. Tekan tombol di bawah untuk mencatat setoran.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showDepositDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Catat Setoran TPS'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.screenPadding, AppSpacing.screenPadding, 80),
      itemCount: _deposits.length,
      itemBuilder: (context, index) {
        final tx = _deposits[index];
        final isDeposit = tx['type'] == 'deposit';
        final rawDate = tx['created_at'] != null ? DateTime.tryParse(tx['created_at'].toString()) : null;
        final dateStr = rawDate != null
            ? '${rawDate.day.toString().padLeft(2, '0')}/${rawDate.month.toString().padLeft(2, '0')}/${rawDate.year} • ${rawDate.hour.toString().padLeft(2, '0')}:${rawDate.minute.toString().padLeft(2, '0')}'
            : 'Baru saja';
        final itemName = tx['item_name']?.toString() ?? 'Penyetoran Sampah';
        final cost = tx['cost'] ?? 0;
        final accountInfo = tx['account_info']?.toString();
        final voucherCode = tx['voucher_code']?.toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.roundedLg,
            border: Border.all(color: isDeposit ? const Color(0xFFA7F3D0) : AppColors.border),
            boxShadow: AppSpacing.subtleShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDeposit ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDeposit ? Icons.recycling_rounded : (tx['type'] == 'digital' ? Icons.phone_android_rounded : Icons.storefront_rounded),
                  color: isDeposit ? const Color(0xFF059669) : const Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      accountInfo != null ? '$accountInfo • $dateStr' : (voucherCode != null ? 'Kode: $voucherCode • $dateStr' : dateStr),
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isDeposit ? '+$cost Poin' : '-$cost XP',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDeposit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Berhasil',
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF059669),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
