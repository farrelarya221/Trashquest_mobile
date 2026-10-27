import 'package:flutter/material.dart';

enum NotificationType {
  mission,
  scan,
  reward,
  system;

  String get label {
    switch (this) {
      case NotificationType.mission:
        return 'Misi & XP';
      case NotificationType.scan:
        return 'Pilah Sampah';
      case NotificationType.reward:
        return 'Hadiah & Koin';
      case NotificationType.system:
        return 'Sistem Eco';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.mission:
        return Icons.military_tech_rounded;
      case NotificationType.scan:
        return Icons.camera_alt_rounded;
      case NotificationType.reward:
        return Icons.card_giftcard_rounded;
      case NotificationType.system:
        return Icons.eco_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.mission:
        return const Color(0xFF0EA5E9);
      case NotificationType.scan:
        return const Color(0xFF10B981);
      case NotificationType.reward:
        return const Color(0xFFF59E0B);
      case NotificationType.system:
        return const Color(0xFF8B5CF6);
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    NotificationType parsedType = NotificationType.system;
    final typeStr = map['type']?.toString();
    if (typeStr == 'mission') parsedType = NotificationType.mission;
    if (typeStr == 'scan') parsedType = NotificationType.scan;
    if (typeStr == 'reward') parsedType = NotificationType.reward;

    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: parsedType,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      isRead: map['is_read'] == 1 || map['is_read'] == true,
    );
  }
}
