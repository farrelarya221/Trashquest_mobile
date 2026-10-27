/// User profile model for TrashQuest.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int streakDays;
  final int totalScans;
  final int totalSorted;
  final DateTime createdAt;

  final String bio;
  final String phone;
  final String address;
  final String memberCardNumber;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.xp = 840,
    this.level = 4,
    this.streakDays = 3,
    this.totalScans = 12,
    this.totalSorted = 28,
    required this.createdAt,
    this.bio = 'Pilah sampah dari rumah demi masa depan bumi hijau 🌿',
    this.phone = '+62 812-3456-7890',
    this.address = 'Jakarta Barat, DKI Jakarta',
    this.memberCardNumber = 'TQ-ECO-2026-001',
  });

  /// Calculate level progress (0.0 to 1.0) towards next level
  double get levelProgress {
    final xpForCurrentLevel = (level - 1) * 250;
    final xpForNextLevel = level * 250;
    final currentLevelXp = xp - xpForCurrentLevel;
    final levelRange = xpForNextLevel - xpForCurrentLevel;
    if (levelRange <= 0) return 1.0;
    return (currentLevelXp / levelRange).clamp(0.0, 1.0);
  }

  int get xpNeededForNextLevel {
    final nextLevelXp = level * 250;
    return (nextLevelXp - xp).clamp(0, 99999);
  }

  /// Total weight of sorted waste in kg (1 sorted item ~ 0.79 kg)
  double get totalSortedWeightKg {
    return double.parse((totalSorted * 0.79).toStringAsFixed(1));
  }

  /// Formatted weight string e.g. "28.4"
  String get formattedSortedKg => totalSortedWeightKg.toStringAsFixed(1);

  /// Carbon emission prevented in kg (~0.5 kg CO2 per kg waste sorted)
  double get totalCo2PreventedKg {
    return double.parse((totalSortedWeightKg * 0.5).toStringAsFixed(1));
  }

  String get formattedCo2Kg => totalCo2PreventedKg.toStringAsFixed(1);

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? avatarUrl,
    int? xp,
    int? level,
    int? streakDays,
    int? totalScans,
    int? totalSorted,
    DateTime? createdAt,
    String? bio,
    String? phone,
    String? address,
    String? memberCardNumber,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streakDays: streakDays ?? this.streakDays,
      totalScans: totalScans ?? this.totalScans,
      totalSorted: totalSorted ?? this.totalSorted,
      createdAt: createdAt ?? this.createdAt,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      memberCardNumber: memberCardNumber ?? this.memberCardNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'xp': xp,
      'level': level,
      'streak_days': streakDays,
      'total_scans': totalScans,
      'total_sorted': totalSorted,
      'created_at': createdAt.toIso8601String(),
      'bio': bio,
      'phone': phone,
      'address': address,
      'member_card_number': memberCardNumber,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Eco Warrior',
      email: map['email']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      streakDays: (map['streak_days'] as num?)?.toInt() ?? 0,
      totalScans: (map['total_scans'] as num?)?.toInt() ?? 0,
      totalSorted: (map['total_sorted'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      bio: map['bio']?.toString() ?? 'Pilah sampah dari rumah demi masa depan bumi hijau 🌿',
      phone: map['phone']?.toString() ?? '+62 812-3456-7890',
      address: map['address']?.toString() ?? 'Jakarta Barat, DKI Jakarta',
      memberCardNumber: map['member_card_number']?.toString() ?? 'TQ-ECO-2026-001',
    );
  }
}
