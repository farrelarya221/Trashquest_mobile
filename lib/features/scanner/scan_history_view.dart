import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/category_badge.dart';
import '../../data/models/waste_scan.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_service.dart';

class ScanHistoryView extends StatefulWidget {
  const ScanHistoryView({super.key});

  @override
  State<ScanHistoryView> createState() => _ScanHistoryViewState();
}

class _ScanHistoryViewState extends State<ScanHistoryView> {
  List<WasteScan> _scans = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    final scans = await SqliteService.instance.getScans();
    if (mounted) {
      setState(() {
        _scans = scans;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    final count = await SyncService.instance.syncPendingData();
    await _loadScans();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Riwayat Scan', style: AppTextStyles.titleMedium),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sinkronisasi ke Cloud',
            onPressed: _isSyncing ? null : _syncData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : _scans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 54, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text('Belum ada riwayat scan', style: AppTextStyles.titleSmall),
                      const SizedBox(height: 4),
                      Text('Gunakan kamera AI untuk mendeteksi sampah pertamamu.', style: AppTextStyles.bodySmall),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
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
                                  '${scan.createdAt.day}/${scan.createdAt.month}/${scan.createdAt.year} • ${scan.createdAt.hour.toString().padLeft(2, '0')}:${scan.createdAt.minute.toString().padLeft(2, '0')}',
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
                ),
    );
  }
}
