import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_profile.dart';
import '../data/models/waste_scan.dart';
import 'sqlite_service.dart';


class SupabaseService extends ChangeNotifier {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  // Supabase Configuration constants
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://imiikcbpppajsbizbbtb.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltaWlrY2JwcHBhanNiaXpiYnRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDQxMDMsImV4cCI6MjEwNzIyMDEwM30.gJXAB83O4GltmheSwh9xoEF4xIS_QqyyHPqS2jb5Iw4',
  );

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Active user state
  UserProfile _currentUser = UserProfile(
    id: 'demo-user-101',
    fullName: 'Raditya Pratama',
    email: 'raditya@ecohunter.id',
    xp: 1250,
    level: 4,
    streakDays: 5,
    totalScans: 42,
    totalSorted: 36,
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
    bio: 'Pilah sampah dari rumah demi masa depan bumi hijau 🌿',
    phone: '+62 812-3456-7890',
    address: 'Jakarta Barat, DKI Jakarta',
    memberCardNumber: 'TQ-ECO-2026-001',
  );

  UserProfile get currentUser => _currentUser;

  Future<void> initialize() async {
    await _loadLocalProfileData();

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: supabaseAnonKey,
        );
        _isInitialized = true;
        debugPrint('Supabase initialized successfully');

        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await _fetchUserProfile(user.id);
          await restoreAchievementsFromCloud();
        }
      } catch (e) {
        debugPrint('Supabase initialization fallback: $e');
        _isInitialized = false;
      }
    } else {
      debugPrint('Supabase credentials not set, running in local offline demo mode');
      _isInitialized = false;
    }
  }

  Future<void> _loadLocalProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_profile_fullName');
      final savedAvatar = prefs.getString('user_profile_avatarUrl');
      final isAvatarCleared = prefs.getBool('user_profile_avatarCleared') ?? false;
      final savedBio = prefs.getString('user_profile_bio');
      final savedPhone = prefs.getString('user_profile_phone');
      final savedAddress = prefs.getString('user_profile_address');
      final savedCard = prefs.getString('user_profile_memberCardNumber');

      if (savedName != null || savedAvatar != null || savedBio != null || isAvatarCleared) {
        _currentUser = _currentUser.copyWith(
          fullName: savedName ?? _currentUser.fullName,
          avatarUrl: isAvatarCleared ? null : (savedAvatar ?? _currentUser.avatarUrl),
          clearAvatar: isAvatarCleared,
          bio: savedBio ?? _currentUser.bio,
          phone: savedPhone ?? _currentUser.phone,
          address: savedAddress ?? _currentUser.address,
          memberCardNumber: savedCard ?? _currentUser.memberCardNumber,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading local profile preferences: $e');
    }
  }

  Future<void> _fetchUserProfile(String userId) async {
    if (!_isInitialized) return;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res != null) {
        _currentUser = UserProfile.fromMap(res);
        notifyListeners();
      } else {
        // Fallback: If user is authenticated in Supabase Auth but profile row is missing
        final authUser = Supabase.instance.client.auth.currentUser;
        if (authUser != null && authUser.id == userId) {
          final rawName = authUser.userMetadata?['full_name']?.toString() ??
              authUser.userMetadata?['name']?.toString() ??
              authUser.email?.split('@').first ??
              'Eco Warrior';
          final newProfile = UserProfile(
            id: authUser.id,
            fullName: rawName,
            email: authUser.email ?? '',
            xp: 840,
            level: 4,
            streakDays: 3,
            totalScans: 14,
            totalSorted: 32,
            createdAt: DateTime.now(),
          );
          try {
            await Supabase.instance.client.from('profiles').upsert(newProfile.toMap());
          } catch (e) {
            debugPrint('Failed to auto-upsert profile row: $e');
          }
          _currentUser = newProfile;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile from Supabase: $e');
    }
  }

  bool get isAuthenticated => _isInitialized && Supabase.instance.client.auth.currentUser != null;

  String? lastAuthError;

  Future<bool> register({required String email, required String password, required String fullName}) async {
    lastAuthError = null;
    if (_isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': fullName},
        );
        if (res.user != null) {
          try {
            await Supabase.instance.client.from('profiles').upsert({
              'id': res.user!.id,
              'full_name': fullName,
              'email': email,
              'xp': 100,
              'level': 1,
              'streak_days': 1,
              'total_scans': 0,
              'total_sorted': 0,
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('Supabase register profile upsert error: $e');
          }
          // Sign out immediately so user is required to log in manually from the login screen
          await Supabase.instance.client.auth.signOut();
          return true;
        } else {
          lastAuthError = 'Gagal mendaftarkan akun. Silakan periksa data kamu.';
          return false;
        }
      } on AuthException catch (e) {
        debugPrint('Supabase sign up AuthException: ${e.message}');
        final msg = e.message.toLowerCase();
        if (msg.contains('already registered') || msg.contains('already exists')) {
          lastAuthError = 'Email sudah terdaftar. Silakan langsung login di tab Masuk.';
        } else if (msg.contains('password')) {
          lastAuthError = 'Password terlalu lemah (minimal 6 karakter).';
        } else if (msg.contains('rate limit')) {
          lastAuthError = 'Batas pengiriman email Supabase tercapai (Rate Limit). Matikan "Confirm Email" di Supabase Dashboard untuk mendaftar bebas.';
        } else {
          lastAuthError = e.message;
        }
        return false;
      } catch (e) {
        debugPrint('Supabase sign up error: $e');
        lastAuthError = 'Terjadi kesalahan: $e';
        return false;
      }
    }

    lastAuthError = 'Koneksi Supabase belum aktif.';
    return false;
  }

  Future<bool> login({required String email, required String password}) async {
    lastAuthError = null;
    if (_isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (res.user != null) {
          await SqliteService.instance.resetLocalAchievementsForNewUser(targetUserId: res.user!.id);
          await _fetchUserProfile(res.user!.id);
          await restoreAchievementsFromCloud();
          return true;
        } else {
          lastAuthError = 'Akun tidak ditemukan atau password salah.';
          return false;
        }
      } on AuthException catch (e) {
        debugPrint('Supabase sign in AuthException: ${e.message}');
        final msg = e.message.toLowerCase();
        if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
          lastAuthError = 'Email tidak terdaftar atau password salah.';
        } else if (msg.contains('email not confirmed')) {
          lastAuthError = 'Email belum dikonfirmasi. Periksa kotak masuk email kamu.';
        } else {
          lastAuthError = e.message;
        }
        return false;
      } catch (e) {
        debugPrint('Supabase sign in error: $e');
        lastAuthError = 'Gagal menghubungi server: $e';
        return false;
      }
    }

    lastAuthError = 'Koneksi Supabase belum aktif.';
    return false;
  }

  Future<bool> resetPassword({required String email}) async {
    lastAuthError = null;
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      lastAuthError = 'Masukkan alamat email Anda terlebih dahulu.';
      return false;
    }

    if (_isInitialized) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(cleanEmail);
        return true;
      } on AuthException catch (e) {
        debugPrint('Supabase resetPassword AuthException: ${e.message}');
        final msg = e.message.toLowerCase();
        if (msg.contains('rate limit')) {
          lastAuthError = 'Batas pengiriman email Supabase tercapai (Rate Limit). Coba beberapa saat lagi.';
        } else {
          lastAuthError = e.message;
        }
        return false;
      } catch (e) {
        debugPrint('Supabase resetPassword error: $e');
        lastAuthError = 'Gagal mengirim instruksi reset kata sandi: $e';
        return false;
      }
    }

    // Offline / Demo fallback: pretend email sent
    return true;
  }

  Future<bool> loginDemo() async {
    lastAuthError = null;
    _currentUser = UserProfile(
      id: 'demo-user-101',
      fullName: 'Aulia Rahma',
      email: 'aulia.rahma@trashquest.id',
      xp: 840,
      level: 4,
      streakDays: 3,
      totalScans: 14,
      totalSorted: 32,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    );
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    if (_isInitialized) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('Supabase logout error: $e');
      }
    }
    _currentUser = UserProfile(
      id: '',
      fullName: '',
      email: '',
      createdAt: DateTime.now(),
    );
    await SqliteService.instance.resetLocalAchievementsForNewUser();
    notifyListeners();
  }

  void addXp(int points) async {
    final newXp = _currentUser.xp + points;
    final newLevel = (newXp ~/ 250) + 1;
    _currentUser = _currentUser.copyWith(
      xp: newXp,
      level: newLevel,
    );
    notifyListeners();

    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'xp': newXp,
          'level': newLevel,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentUser.id);
      } catch (e) {
        debugPrint('Supabase addXp error: $e');
      }
    }
  }

  void incrementScanCount() async {
    final count = _currentUser.totalScans + 1;
    _currentUser = _currentUser.copyWith(
      totalScans: count,
    );
    notifyListeners();

    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'total_scans': count,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentUser.id);
      } catch (e) {
        debugPrint('Supabase scan count error: $e');
      }
    }
  }

  void incrementSortedCount(int count) async {
    final total = _currentUser.totalSorted + count;
    _currentUser = _currentUser.copyWith(
      totalSorted: total,
    );
    notifyListeners();

    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'total_sorted': total,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentUser.id);
      } catch (e) {
        debugPrint('Supabase sorted count error: $e');
      }
    }
  }

  Future<bool> sendFeedback({required String message, required int rating}) async {
    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        await Supabase.instance.client.from('feedback').insert({
          'user_id': _currentUser.id,
          'message': message,
          'rating': rating,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      } catch (e) {
        debugPrint('Supabase feedback error: $e');
      }
    }
    return true;
  }

  Future<bool> syncScan(WasteScan scan) async {
    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        await Supabase.instance.client.from('waste_scans').insert(scan.toMap());
        return true;
      } catch (e) {
        debugPrint('Supabase sync scan error: $e');
      }
    }
    return false;
  }

  Future<bool> saveRedeemTransaction({
    required String itemName,
    required int costXp,
    required String type,
    String? accountInfo,
    String? voucherCode,
  }) async {
    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        await Supabase.instance.client.from('redeem_transactions').insert({
          'user_id': _currentUser.id,
          'item_name': itemName,
          'cost_xp': costXp,
          'type': type,
          'account_info': accountInfo,
          'voucher_code': voucherCode,
          'status': 'success',
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      } catch (e) {
        debugPrint('Supabase save redeem error: $e');
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchRedeemHistory() async {
    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        final res = await Supabase.instance.client
            .from('redeem_transactions')
            .select()
            .eq('user_id', _currentUser.id)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Supabase fetch redeem history error: $e');
      }
    }
    return [];
  }

  Future<bool> updateFullName(String newName) async {
    return updateProfile(name: newName);
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? phone,
    String? address,
    String? memberCardNumber,
    String? profilePicture,
    bool removeProfilePicture = false,
  }) async {
    final cleanName = name?.trim();
    final bool shouldClearPhoto = removeProfilePicture || (profilePicture != null && profilePicture.trim().isEmpty);

    final updated = _currentUser.copyWith(
      fullName: (cleanName != null && cleanName.isNotEmpty) ? cleanName : _currentUser.fullName,
      bio: bio ?? _currentUser.bio,
      phone: phone ?? _currentUser.phone,
      address: address ?? _currentUser.address,
      memberCardNumber: memberCardNumber ?? _currentUser.memberCardNumber,
      avatarUrl: shouldClearPhoto ? null : (profilePicture ?? _currentUser.avatarUrl),
      clearAvatar: shouldClearPhoto,
    );
    _currentUser = updated;
    notifyListeners();

    // Persist locally to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      if (cleanName != null && cleanName.isNotEmpty) {
        await prefs.setString('user_profile_fullName', cleanName);
      }
      if (shouldClearPhoto) {
        await prefs.remove('user_profile_avatarUrl');
        await prefs.setBool('user_profile_avatarCleared', true);
      } else if (profilePicture != null) {
        await prefs.setString('user_profile_avatarUrl', profilePicture);
        await prefs.remove('user_profile_avatarCleared');
      }
      if (bio != null) await prefs.setString('user_profile_bio', bio);
      if (phone != null) await prefs.setString('user_profile_phone', phone);
      if (address != null) await prefs.setString('user_profile_address', address);
      if (memberCardNumber != null) {
        await prefs.setString('user_profile_memberCardNumber', memberCardNumber);
      }
    } catch (e) {
      debugPrint('Local prefs save error: $e');
    }

    // Persist to Supabase if connected
    if (_isInitialized && Supabase.instance.client.auth.currentUser != null) {
      try {
        final updateData = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (cleanName != null && cleanName.isNotEmpty) {
          updateData['full_name'] = cleanName;
        }
        if (shouldClearPhoto) {
          updateData['avatar_url'] = null;
        } else if (profilePicture != null) {
          updateData['avatar_url'] = profilePicture;
        }
        await Supabase.instance.client.from('profiles').update(updateData).eq('id', _currentUser.id);

        if (cleanName != null && cleanName.isNotEmpty) {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'full_name': cleanName}),
          );
        }
      } catch (e) {
        debugPrint('Supabase updateProfile error: $e');
      }
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboardUsers() async {
    if (_isInitialized) {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, xp, level, avatar_url')
            .order('xp', ascending: false)
            .limit(20);
        return List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Supabase fetchLeaderboardUsers error: $e');
      }
    }
    return [];
  }

  Stream<List<Map<String, dynamic>>>? getLeaderboardStream() {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .order('xp', ascending: false)
          .limit(20);
    } catch (e) {
      debugPrint('Supabase getLeaderboardStream error: $e');
      return null;
    }
  }

  /// Sync an unlocked achievement & its blockchain verification hash to Supabase cloud.
  /// This ensures that if the user switches to a different phone or emulator,
  /// their genuine minted certificates are restored across devices in realtime.
  Future<void> syncAchievementToCloud(String code, String txHash) async {
    if (!_isInitialized) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final currentMeta = Map<String, dynamic>.from(user.userMetadata ?? {});
      final achievements = Map<String, dynamic>.from(currentMeta['unlocked_achievements'] as Map? ?? {});
      achievements[code] = {
        'tx_hash': txHash,
        'unlocked_at': DateTime.now().toIso8601String(),
        'minted_by_user': true,
        'mint_version': 'v10',
      };
      currentMeta['unlocked_achievements'] = achievements;
      currentMeta['clean_slate_v10_done'] = true;
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: currentMeta),
      );
      notifyListeners();
      debugPrint('☁️ [ACHIEVEMENT CLOUD SYNC] Piagam $code ($txHash) tersimpan di Cloud Supabase!');
    } catch (e) {
      debugPrint('⚠️ Error syncing achievement to Supabase: $e');
    }
  }

  /// Restores unlocked achievements and blockchain hashes from the cloud account into local SQLite.
  /// Automatically invoked upon login or initial profile loading.
  Future<void> restoreAchievementsFromCloud() async {
    if (!_isInitialized) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final meta = user.userMetadata ?? {};
      // Reset satu kali saat awal pembaruan v10 agar semua user bersih dari piagam lama (semua user new)
      if (meta['clean_slate_v10_done'] != true) {
        final currentMeta = Map<String, dynamic>.from(meta);
        currentMeta.remove('unlocked_achievements');
        currentMeta['clean_slate_v10_done'] = true;
        try {
          await Supabase.instance.client.auth.updateUser(UserAttributes(data: currentMeta));
        } catch (_) {}
        await SqliteService.instance.resetLocalAchievementsForNewUser(targetUserId: user.id);
        debugPrint('🧹 [SUPABASE CLEAN SLATE V10] Piagam lama akun ${user.email} telah di-reset ke BELUM TERBIT!');
        return;
      }

      // Hanya pulihkan piagam yang BENAR-BENAR telah diterbitkan oleh user (minted_by_user == true / v10)
      if (meta['unlocked_achievements'] is Map) {
        final achievements = meta['unlocked_achievements'] as Map<String, dynamic>;
        for (final entry in achievements.entries) {
          final code = entry.key;
          final data = entry.value;
          String? txHash;
          String? unlockedAt;
          bool isGenuineMint = false;
          if (data is Map) {
            txHash = data['tx_hash']?.toString();
            unlockedAt = data['unlocked_at']?.toString();
            isGenuineMint = data['minted_by_user'] == true || data['mint_version'] == 'v10';
          }
          if (isGenuineMint && txHash != null && txHash.startsWith('0x') && txHash.length == 66) {
            await SqliteService.instance.restoreAchievementFromCloud(
              code,
              txHash,
              targetUserId: user.id,
              unlockedAt: unlockedAt,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error in restoreAchievementsFromCloud: $e');
    }
  }

  /// Clears stored achievements from Supabase cloud metadata for the current user
  Future<void> clearAllUserAchievementsCloud() async {
    if (!_isInitialized) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final currentMeta = Map<String, dynamic>.from(user.userMetadata ?? {});
      currentMeta.remove('unlocked_achievements');
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: currentMeta));
      await SqliteService.instance.resetAllAchievementsGlobally();
      debugPrint('🧹 [ACHIEVEMENTS RESET] Piagam cloud akun ini di-reset ke belum terbit!');
    } catch (e) {
      debugPrint('Error clearing achievements in Supabase: $e');
    }
  }
}
