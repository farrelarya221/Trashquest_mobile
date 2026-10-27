import 'package:flutter/foundation.dart';
import 'sqlite_service.dart';
import 'supabase_service.dart';

/// Sync service for offline-first data reconciliation between SQLite and Supabase
class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<int> syncPendingData() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int syncedCount = 0;

    try {
      final unsynced = await SqliteService.instance.getUnsyncedScans();
      for (final scan in unsynced) {
        final success = await SupabaseService.instance.syncScan(scan);
        if (success) {
          await SqliteService.instance.markScanSynced(scan.id);
          syncedCount++;
        }
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }
}
