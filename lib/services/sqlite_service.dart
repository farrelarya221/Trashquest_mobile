import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../data/models/waste_item.dart';
import '../data/models/waste_scan.dart';
import '../data/models/waste_bank.dart';
import '../data/models/quest_challenge.dart';
import '../data/models/achievement.dart';
import '../data/models/app_notification.dart';
import 'supabase_service.dart';

/// Local SQLite database service providing full offline-first capabilities.
class SqliteService {
  static final SqliteService instance = SqliteService._internal();
  SqliteService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    String dbPath;
    try {
      final databasesPath = await getDatabasesPath();
      dbPath = p.join(databasesPath, 'trashquest_local.db');
    } catch (e) {
      dbPath = 'trashquest_local.db';
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_transactions (
            id TEXT PRIMARY KEY,
            item_name TEXT NOT NULL,
            cost INTEGER NOT NULL,
            type TEXT NOT NULL,
            created_at TEXT NOT NULL,
            account_info TEXT,
            voucher_code TEXT,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_notifications (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            type TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_read INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_quests (
            user_id TEXT NOT NULL,
            quest_id TEXT NOT NULL,
            progress INTEGER DEFAULT 0,
            target INTEGER DEFAULT 1,
            is_completed INTEGER DEFAULT 0,
            is_claimed INTEGER DEFAULT 0,
            updated_at TEXT,
            PRIMARY KEY (user_id, quest_id)
          )
        ''');
        try {
          await db.execute('ALTER TABLE offline_quests ADD COLUMN is_claimed INTEGER DEFAULT 0');
        } catch (_) {}
        // Clean Slate Reset (Semua user belum pernah terbitkan piagam & misi terisolasi per user)
        try {
          final prefs = await db.query('app_preferences', where: 'pref_key = ?', whereArgs: ['clean_slate_reset_v6']);
          if (prefs.isEmpty) {
            await db.update('offline_achievements', {'is_unlocked': 0, 'verification_hash': null, 'unlocked_at': null});
            await db.update('offline_quests', {'progress': 0, 'is_completed': 0, 'is_claimed': 0});
            await db.delete('user_quests');
            await db.insert('app_preferences', {'pref_key': 'clean_slate_reset_v6', 'pref_value': 'done'});
            debugPrint('🧹 [CLEAN SLATE] Semua piagam telah di-reset ke belum terbit & misi bersih per user!');
          }
        } catch (_) {}
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Local Scan History
    await db.execute('''
      CREATE TABLE local_scan_history (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        image_path TEXT,
        detected_name TEXT NOT NULL,
        category TEXT NOT NULL,
        recyclable INTEGER NOT NULL,
        disposal_advice TEXT NOT NULL,
        notes TEXT,
        confidence REAL,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Cached Waste Encyclopedia
    await db.execute('''
      CREATE TABLE cached_waste_types (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        recyclable INTEGER NOT NULL,
        disposal_advice TEXT,
        decomposition_time TEXT,
        material_type TEXT
      )
    ''');

    // 3. Cached Waste Banks
    await db.execute('''
      CREATE TABLE cached_waste_banks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        opening_hours TEXT,
        accepted_materials TEXT,
        phone_number TEXT,
        rating REAL,
        total_reviews INTEGER
      )
    ''');

    // 4. Offline Quests
    await db.execute('''
      CREATE TABLE offline_quests (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL,
        difficulty TEXT,
        reward_xp INTEGER,
        progress INTEGER DEFAULT 0,
        target INTEGER DEFAULT 1,
        is_completed INTEGER DEFAULT 0,
        is_claimed INTEGER DEFAULT 0
      )
    ''');

    // 5. Offline Achievements
    await db.execute('''
      CREATE TABLE offline_achievements (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        icon_key TEXT,
        required_xp INTEGER,
        is_unlocked INTEGER DEFAULT 0,
        unlocked_at TEXT,
        verification_hash TEXT
      )
    ''');

    // 6. User Profile Cache & Settings
    await db.execute('''
      CREATE TABLE app_preferences (
        pref_key TEXT PRIMARY KEY,
        pref_value TEXT
      )
    ''');

    // 7. Local Redeem Transactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_transactions (
        id TEXT PRIMARY KEY,
        item_name TEXT NOT NULL,
        cost INTEGER NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        account_info TEXT,
        voucher_code TEXT,
        status TEXT NOT NULL
      )
    ''');

    // Seed initial dataset
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final batch = db.batch();

    // Seed default waste encyclopedia
    for (final item in _defaultWasteEncyclopedia) {
      batch.insert('cached_waste_types', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Seed default waste banks (Jogja & Jakarta realistic demo collection points)
    for (final bank in _defaultWasteBanks) {
      batch.insert('cached_waste_banks', bank.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Seed default quests
    for (final quest in _defaultQuests) {
      batch.insert('offline_quests', quest.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Seed default achievements
    for (final ach in _defaultAchievements) {
      batch.insert('offline_achievements', ach.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  // --- Scan Operations ---
  Future<void> insertScan(WasteScan scan) async {
    try {
      final db = await database;
      await db.insert('local_scan_history', scan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      // Real-time quest progress update
      await incrementQuestProgressByType(QuestType.scanWaste, amount: 1);
    } catch (e) {
      debugPrint('Error inserting scan: $e');
    }
  }

  Future<List<WasteScan>> getScans({int limit = 50}) async {
    try {
      final db = await database;
      final maps = await db.query('local_scan_history', orderBy: 'created_at DESC', limit: limit);
      return maps.map((m) => WasteScan.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting scans: $e');
      return [];
    }
  }

  Future<List<WasteScan>> getUnsyncedScans() async {
    try {
      final db = await database;
      final maps = await db.query('local_scan_history', where: 'is_synced = ?', whereArgs: [0]);
      return maps.map((m) => WasteScan.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markScanSynced(String id) async {
    try {
      final db = await database;
      await db.update('local_scan_history', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error marking scan synced: $e');
    }
  }

  // --- Waste Encyclopedia ---
  Future<List<WasteItem>> getWasteTypes({String? query, WasteCategory? category}) async {
    try {
      final db = await database;
      String? where;
      List<dynamic>? whereArgs;

      if (query != null && query.isNotEmpty && category != null) {
        where = 'name LIKE ? AND category = ?';
        whereArgs = ['%$query%', category.name];
      } else if (query != null && query.isNotEmpty) {
        where = 'name LIKE ? OR description LIKE ?';
        whereArgs = ['%$query%', '%$query%'];
      } else if (category != null) {
        where = 'category = ?';
        whereArgs = [category.name];
      }

      final maps = await db.query('cached_waste_types', where: where, whereArgs: whereArgs, orderBy: 'name ASC');
      return maps.map((m) => WasteItem.fromMap(m)).toList();
    } catch (e) {
      return _defaultWasteEncyclopedia;
    }
  }

  // --- Waste Banks ---
  Future<List<WasteBank>> getWasteBanks({String? query}) async {
    try {
      final db = await database;
      // Ensure real-life TPS 3R & Bank Sampah are seeded
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cached_waste_banks')) ?? 0;
      if (count < _defaultWasteBanks.length) {
        final batch = db.batch();
        for (final b in _defaultWasteBanks) {
          batch.insert('cached_waste_banks', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }

      List<Map<String, dynamic>> maps;
      if (query != null && query.isNotEmpty) {
        maps = await db.query('cached_waste_banks', where: 'name LIKE ? OR address LIKE ?', whereArgs: ['%$query%', '%$query%']);
      } else {
        maps = await db.query('cached_waste_banks');
      }
      return maps.map((m) => WasteBank.fromMap(m)).toList();
    } catch (e) {
      return _defaultWasteBanks;
    }
  }

  // --- Quests (Terisolasi 100% Per User) ---
  Future<void> _ensureUserQuestsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_quests (
        user_id TEXT NOT NULL,
        quest_id TEXT NOT NULL,
        progress INTEGER DEFAULT 0,
        target INTEGER DEFAULT 1,
        is_completed INTEGER DEFAULT 0,
        is_claimed INTEGER DEFAULT 0,
        updated_at TEXT,
        PRIMARY KEY (user_id, quest_id)
      )
    ''');
  }

  Future<List<QuestChallenge>> getQuests({String? targetUserId}) async {
    try {
      final db = await database;
      await _ensureUserQuestsTable(db);

      final uid = (targetUserId != null && targetUserId.isNotEmpty)
          ? targetUserId
          : SupabaseService.instance.currentUser.id.isNotEmpty
              ? SupabaseService.instance.currentUser.id
              : 'guest';

      final userMaps = await db.query(
        'user_quests',
        where: 'user_id = ?',
        whereArgs: [uid],
      );

      final userMapById = <String, Map<String, dynamic>>{
        for (final m in userMaps) m['quest_id'].toString(): m,
      };

      final result = <QuestChallenge>[];
      for (final def in _defaultQuests) {
        final existing = userMapById[def.id];
        if (existing != null) {
          final progress = (existing['progress'] as num?)?.toInt() ?? 0;
          final target = (existing['target'] as num?)?.toInt() ?? def.target;
          final isCompleted = existing['is_completed'] == 1 || existing['is_completed'] == true || progress >= target;
          final isClaimed = existing['is_claimed'] == 1 || existing['is_claimed'] == true;

          result.add(def.copyWith(
            progress: progress,
            target: target,
            isCompleted: isCompleted,
            isClaimed: isClaimed,
          ));
        } else {
          // User baru belum punya progres untuk quest ini -> buat record bersih (0 progres)
          await db.insert(
            'user_quests',
            {
              'user_id': uid,
              'quest_id': def.id,
              'progress': 0,
              'target': def.target,
              'is_completed': 0,
              'is_claimed': 0,
              'updated_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          result.add(def.copyWith(
            progress: 0,
            isCompleted: false,
            isClaimed: false,
          ));
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error getting per-user quests: $e');
      return _defaultQuests;
    }
  }

  Future<void> updateQuestProgress(String questId, int progress, bool isCompleted, {String? targetUserId}) async {
    try {
      final db = await database;
      await _ensureUserQuestsTable(db);

      final uid = (targetUserId != null && targetUserId.isNotEmpty)
          ? targetUserId
          : SupabaseService.instance.currentUser.id.isNotEmpty
              ? SupabaseService.instance.currentUser.id
              : 'guest';

      await db.insert(
        'user_quests',
        {
          'user_id': uid,
          'quest_id': questId,
          'progress': progress,
          'is_completed': isCompleted ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error updating user quest: $e');
    }
  }

  /// Real-time increment for quest progress based on user actions (Khusus User yang Sedang Login)
  Future<void> incrementQuestProgressByType(QuestType type, {int amount = 1, String? targetUserId}) async {
    try {
      final db = await database;
      await _ensureUserQuestsTable(db);

      final uid = (targetUserId != null && targetUserId.isNotEmpty)
          ? targetUserId
          : SupabaseService.instance.currentUser.id.isNotEmpty
              ? SupabaseService.instance.currentUser.id
              : 'guest';

      final matchingQuests = _defaultQuests.where((q) => q.type == type).toList();
      for (final q in matchingQuests) {
        final rows = await db.query(
          'user_quests',
          where: 'user_id = ? AND quest_id = ?',
          whereArgs: [uid, q.id],
        );

        int currentProgress = 0;
        bool isClaimed = false;
        if (rows.isNotEmpty) {
          isClaimed = rows.first['is_claimed'] == 1 || rows.first['is_claimed'] == true;
          currentProgress = (rows.first['progress'] as num?)?.toInt() ?? 0;
        }
        if (isClaimed) continue; // Sudah diklaim oleh user ini

        final newProgress = (currentProgress + amount).clamp(0, q.target);
        final isCompleted = newProgress >= q.target;

        await db.insert(
          'user_quests',
          {
            'user_id': uid,
            'quest_id': q.id,
            'progress': newProgress,
            'target': q.target,
            'is_completed': isCompleted ? 1 : 0,
            'is_claimed': isClaimed ? 1 : 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('Error incrementing per-user quest progress: $e');
    }
  }

  /// Claim quest reward strictly once per user.
  Future<bool> claimQuestReward(String questId, {String? targetUserId}) async {
    try {
      final db = await database;
      await _ensureUserQuestsTable(db);

      final uid = (targetUserId != null && targetUserId.isNotEmpty)
          ? targetUserId
          : SupabaseService.instance.currentUser.id.isNotEmpty
              ? SupabaseService.instance.currentUser.id
              : 'guest';

      final rows = await db.query(
        'user_quests',
        where: 'user_id = ? AND quest_id = ?',
        whereArgs: [uid, questId],
      );

      QuestChallenge? defQuest;
      try {
        defQuest = _defaultQuests.firstWhere((q) => q.id == questId);
      } catch (_) {}
      final rewardXp = defQuest?.rewardXp ?? 50;
      final target = defQuest?.target ?? 1;

      int progress = 0;
      bool isClaimed = false;
      if (rows.isNotEmpty) {
        progress = (rows.first['progress'] as num?)?.toInt() ?? 0;
        isClaimed = rows.first['is_claimed'] == 1 || rows.first['is_claimed'] == true;
      }

      if (isClaimed || progress < target) {
        return false;
      }

      await db.insert(
        'user_quests',
        {
          'user_id': uid,
          'quest_id': questId,
          'progress': progress,
          'target': target,
          'is_completed': 1,
          'is_claimed': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      SupabaseService.instance.addXp(rewardXp);
      return true;
    } catch (e) {
      debugPrint('Error claiming per-user quest: $e');
      return false;
    }
  }

  // --- Achievements ---
  Future<List<Achievement>> getAchievements() async {
    try {
      final db = await database;
      // Pastikan piagam default yang sebelumnya otomatis terbuka di-reset agar harus dicapai via quest
      await db.update(
        'offline_achievements',
        {'is_unlocked': 0, 'verification_hash': null},
        where: "verification_hash = '0x94192cc6c956e0c654ade78c3eea395cd7986efec571947b8099915d70d2b8bf' OR verification_hash = '0x354b6135f3fdfeae638767bf5470232b228d6b012255f994ba358ba81707c630' OR verification_hash = '0x5788d7e49e76d1ff1b9789a9545ecbfa9e0e961d002fb60433c3a9466b41f262' OR verification_hash LIKE '%dummy%' OR verification_hash LIKE '%mock%' OR verification_hash = '0x82592d322e0a703a47c92ae3ce03d94af440458024e756bf42e14231d58bb6de' OR verification_hash = '0x18585dbb0b06114708b551a3dac01ffef189ed9112ed650e35f456622d73478f'",
      );
      // Sinkronisasi required_xp dan deskripsi quest
      for (final def in _defaultAchievements) {
        await db.update(
          'offline_achievements',
          {
            'required_xp': def.requiredXp,
            'description': def.description,
            'name': def.name,
          },
          where: 'code = ?',
          whereArgs: [def.code],
        );
      }
      final maps = await db.query('offline_achievements', orderBy: 'required_xp ASC');
      return maps.map((m) => Achievement.fromMap(m)).toList();
    } catch (e) {
      return _defaultAchievements;
    }
  }

  Future<void> unlockAchievement(String code, String hash, {bool syncToCloud = true}) async {
    try {
      final db = await database;
      await db.update(
        'offline_achievements',
        {
          'is_unlocked': 1,
          'unlocked_at': DateTime.now().toIso8601String(),
          'verification_hash': hash,
        },
        where: 'code = ?',
        whereArgs: [code],
      );
      if (syncToCloud) {
        SupabaseService.instance.syncAchievementToCloud(code, hash);
      }
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
    }
  }

  Future<void> restoreAchievementFromCloud(String code, String hash, {String? unlockedAt}) async {
    try {
      final db = await database;
      await db.update(
        'offline_achievements',
        {
          'is_unlocked': 1,
          'unlocked_at': unlockedAt ?? DateTime.now().toIso8601String(),
          'verification_hash': hash,
        },
        where: 'code = ?',
        whereArgs: [code],
      );
    } catch (e) {
      debugPrint('Error restoring achievement from cloud: $e');
    }
  }

  Future<void> resetLocalAchievementsForNewUser() async {
    try {
      final db = await database;
      await db.update(
        'offline_achievements',
        {'is_unlocked': 0, 'verification_hash': null, 'unlocked_at': null},
      );
    } catch (e) {
      debugPrint('Error resetting achievements for new user: $e');
    }
  }

  Future<void> resetAllAchievementsGlobally() async {
    try {
      final db = await database;
      await db.update(
        'offline_achievements',
        {'is_unlocked': 0, 'verification_hash': null, 'unlocked_at': null},
      );
      debugPrint('🧹 [ACHIEVEMENTS RESET] Semua piagam telah di-reset ke status BELUM TERBIT!');
    } catch (e) {
      debugPrint('Error resetting achievements globally: $e');
    }
  }

  // --- Transaction Operations ---
  Future<void> insertTransaction(Map<String, dynamic> tx) async {
    try {
      final db = await database;
      await db.insert('user_transactions', tx, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final db = await database;
      return await db.query('user_transactions', orderBy: 'created_at DESC');
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  // --- User Notifications ---
  Future<void> insertNotification(AppNotification notif) async {
    try {
      final db = await database;
      await db.insert('user_notifications', notif.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error inserting notification: $e');
    }
  }

  Future<List<AppNotification>> getNotifications() async {
    try {
      final db = await database;
      final maps = await db.query('user_notifications', orderBy: 'created_at DESC');
      return maps.map((m) => AppNotification.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      final db = await database;
      await db.update('user_notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final db = await database;
      await db.update('user_notifications', {'is_read': 1});
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      final db = await database;
      await db.delete('user_notifications', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final db = await database;
      await db.delete('user_notifications');
    } catch (e) {
      debugPrint('Error deleting notifications: $e');
    }
  }

  // Seed data definitions
  static const List<WasteItem> _defaultWasteEncyclopedia = [
    WasteItem(
      id: 'w-1',
      name: 'Botol Plastik PET',
      category: WasteCategory.anorganik,
      description: 'Botol minuman bening seperti air mineral atau soda bertanda daur ulang #1.',
      recyclable: true,
      disposalAdvice: 'Kosongkan isi, bilas ringan, lepaskan label jika mudah, dan remas untuk menghemat ruang.',
      decompositionTime: '450 tahun',
      materialType: 'Plastik PET (Polyethylene Terephthalate)',
    ),
    WasteItem(
      id: 'w-2',
      name: 'Kulit Buah & Sayuran',
      category: WasteCategory.organik,
      description: 'Sisa makanan nabati seperti kulit pisang, wortel, dan apel.',
      recyclable: true,
      disposalAdvice: 'Masukkan ke komposter rumahan atau lubang biopori. Hindari mencampur dengan plastik.',
      decompositionTime: '2 - 6 minggu',
      materialType: 'Bahan Organik Hayati',
    ),
    WasteItem(
      id: 'w-3',
      name: 'Baterai Bekas',
      category: WasteCategory.b3,
      description: 'Baterai alkaline atau lithium dari remote control, jam, dan perangkat elektronik.',
      recyclable: false,
      disposalAdvice: 'Limbah B3 beracun! Jangan buang ke tempat sampah umum. Simpan dalam wadah kering khusus dan serahkan ke drop point e-waste.',
      decompositionTime: '100 tahun (melepaskan logam berat)',
      materialType: 'Limbah Elektronik / Logam Beracun',
    ),
    WasteItem(
      id: 'w-4',
      name: 'Kardus dan Box Paket',
      category: WasteCategory.anorganik,
      description: 'Kardus coklat tebal dari kemasan belanja online atau bahan makanan.',
      recyclable: true,
      disposalAdvice: 'Lepaskan selotip/lakban plastik, lipat hingga rata dan keringkan sebelum disetor ke Bank Sampah.',
      decompositionTime: '2 - 3 bulan',
      materialType: 'Serat Selulosa / Kertas',
    ),
    WasteItem(
      id: 'w-5',
      name: 'Styrofoam Makanan',
      category: WasteCategory.residu,
      description: 'Wadah makanan sekali pakai berbahan gabus polistirena.',
      recyclable: false,
      disposalAdvice: 'Kategori sampah residu. Sangat sulit didaur ulang secara konvensional. Buang ke tempat sampah residu.',
      decompositionTime: 'Lebih dari 500 tahun',
      materialType: 'Expanded Polystyrene (Residu)',
    ),
    WasteItem(
      id: 'w-6',
      name: 'Lampu Neon / Bohlam',
      category: WasteCategory.b3,
      description: 'Lampu hemat energi atau tabung TL yang mengandung uap merkuri berbahaya.',
      recyclable: false,
      disposalAdvice: 'Limbah B3 berbahaya! Bungkus dengan kertas/kardus agar tidak pecah dan bawa ke tempat pengumpulan limbah B3.',
      decompositionTime: 'Tidak terurai secara alami',
      materialType: 'Kaca & Uap Merkuri',
    ),
  ];

  static const List<WasteBank> _defaultWasteBanks = [
    WasteBank(
      id: 'wb-1',
      name: 'Bank Sampah Induk (BSI) Kota Yogyakarta',
      address: 'Jl. Kemasan No. 66, Purbayan, Kotagede, Kota Yogyakarta',
      latitude: -7.828854,
      longitude: 110.398642,
      openingHours: '08:00 - 15:00 WIB',
      acceptedMaterials: ['Plastik', 'Kertas', 'Kardus', 'Logam'],
      phoneNumber: '+62 811-1122-3344',
      rating: 4.8,
      totalReviews: 124,
    ),
    WasteBank(
      id: 'wb-2',
      name: 'Bank Sampah Sukunan (Desa Wisata Lingkungan)',
      address: 'Dusun Sukunan, Banyuraden, Gamping, Sleman, D.I. Yogyakarta',
      latitude: -7.781845,
      longitude: 110.324567,
      openingHours: '09:00 - 16:00 WIB',
      acceptedMaterials: ['Plastik PET', 'Kardus', 'Kaleng Logam', 'Kaca', 'Minyak Jelantah'],
      phoneNumber: '+62 822-5566-7788',
      rating: 4.9,
      totalReviews: 215,
    ),
    WasteBank(
      id: 'wb-3',
      name: 'Bank Sampah Gemah Ripah',
      address: 'Dusun Badegan RT 01, Trirenggo, Bantul, D.I. Yogyakarta',
      latitude: -7.884789,
      longitude: 110.329456,
      openingHours: '07:30 - 14:00 WIB',
      acceptedMaterials: ['E-Waste', 'Plastik', 'Kertas', 'Besi', 'Logam'],
      phoneNumber: '+62 813-9988-7766',
      rating: 4.9,
      totalReviews: 180,
    ),
    WasteBank(
      id: 'wb-4',
      name: 'Pusat Daur Ulang & TPS 3R Nitikan',
      address: 'Jl. Nitikan Indah No. 45, Sorosutan, Umbulharjo, Kota Yogyakarta',
      latitude: -7.822987,
      longitude: 110.383124,
      openingHours: '06:00 - 16:00 WIB',
      acceptedMaterials: ['Semua Jenis Anorganik', 'Organik', 'Kardus', 'Plastik'],
      phoneNumber: '+62 812-3344-5566',
      rating: 4.9,
      totalReviews: 310,
    ),
    WasteBank(
      id: 'wb-5',
      name: 'TPS 3R Tamantirto Resi Lestari',
      address: 'Brajan RT 01, Tamantirto, Kasihan, Kabupaten Bantul',
      latitude: -7.818450,
      longitude: 110.325600,
      openingHours: '08:00 - 16:30 WIB',
      acceptedMaterials: ['Plastik', 'Kardus', 'Logam', 'Kaca'],
      phoneNumber: '+62 812-4433-2211',
      rating: 4.7,
      totalReviews: 85,
    ),
    WasteBank(
      id: 'wb-6',
      name: 'Bank Sampah Bersih Lestari',
      address: 'Jl. Bausasran No. 34, Danurejan, Kota Yogyakarta',
      latitude: -7.794500,
      longitude: 110.373200,
      openingHours: '08:00 - 16:00 WIB',
      acceptedMaterials: ['Plastik PET', 'Kertas', 'Kardus', 'Kaleng'],
      phoneNumber: '+62 813-2211-4455',
      rating: 4.8,
      totalReviews: 96,
    ),
  ];

  static const List<QuestChallenge> _defaultQuests = [
    QuestChallenge(
      id: 'q-1',
      title: 'Pilah Sampah Gyro',
      description: 'Mainkan Trash Sorter dan pilah 5 sampah dengan memiringkan HP.',
      type: QuestType.sortWaste,
      difficulty: 'Mudah',
      rewardXp: 50,
      progress: 0,
      target: 5,
    ),
    QuestChallenge(
      id: 'q-2',
      title: 'Deteksi dengan AI',
      description: 'Lakukan scan foto sampah dengan kamera pintar AI.',
      type: QuestType.scanWaste,
      difficulty: 'Sedang',
      rewardXp: 75,
      progress: 0,
      target: 2,
    ),
    QuestChallenge(
      id: 'q-3',
      title: 'Kuis Edukasi Lingkungan',
      description: 'Jawab 3 pertanyaan kuis pilah sampah dengan tepat.',
      type: QuestType.quiz,
      difficulty: 'Mudah',
      rewardXp: 40,
      progress: 0,
      target: 3,
    ),
    QuestChallenge(
      id: 'q-4',
      title: 'Duel Paw Toss Spesial',
      description: 'Mainkan 1 ronde lempar daur ulang di Paw Toss.',
      type: QuestType.pawToss,
      difficulty: 'Mudah',
      rewardXp: 60,
      progress: 0,
      target: 1,
    ),
    QuestChallenge(
      id: 'q-5',
      title: 'Jelajah Bank Sampah',
      description: 'Buka rute peta navigasi menuju TPS 3R terdekat.',
      type: QuestType.visitWasteBank,
      difficulty: 'Sedang',
      rewardXp: 80,
      progress: 0,
      target: 1,
    ),
    QuestChallenge(
      id: 'q-6',
      title: 'Tebas Sampah Trash Ninja',
      description: 'Tebas dan pilah 8 sampah di arcade mini-game Trash Ninja.',
      type: QuestType.sortWaste,
      difficulty: 'Tantangan',
      rewardXp: 90,
      progress: 0,
      target: 8,
    ),
  ];

  static const List<Achievement> _defaultAchievements = [
    Achievement(
      id: 'ach-1',
      code: 'FIRST_SCAN',
      name: 'First Scan Explorer',
      description: 'Menganalisis objek sampah pertama menggunakan AI Camera.',
      iconKey: 'camera',
      requiredXp: 100,
      isUnlocked: false,
      verificationHash: null,
    ),
    Achievement(
      id: 'ach-2',
      code: 'SORTING_MASTER',
      name: 'Sorting Master',
      description: 'Memilah minimal 5 sampah secara tepat pada pemilahan atau mini-game.',
      iconKey: 'trophy',
      requiredXp: 250,
      isUnlocked: false,
      verificationHash: null,
    ),
    Achievement(
      id: 'ach-3',
      code: 'CLEAN_NAVIGATOR',
      name: 'Clean Navigator',
      description: 'Menggunakan peta navigasi penunjuk arah ke Bank Sampah terdekat.',
      iconKey: 'compass',
      requiredXp: 450,
      isUnlocked: false,
      verificationHash: null,
    ),
    Achievement(
      id: 'ach-4',
      code: 'GREEN_STREAK',
      name: 'Green Streak 3 Days',
      description: 'Menyelesaikan quest ramah lingkungan selama 3 hari berturut-turut.',
      iconKey: 'fire',
      requiredXp: 700,
      isUnlocked: false,
      verificationHash: null,
    ),
  ];
}
