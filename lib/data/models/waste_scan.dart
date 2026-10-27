import 'waste_item.dart';

class WasteScan {
  final String id;
  final String? userId;
  final String? imagePath;
  final String detectedName;
  final WasteCategory category;
  final bool recyclable;
  final String disposalAdvice;
  final String? notes;
  final double confidence;
  final bool isSynced;
  final DateTime createdAt;

  const WasteScan({
    required this.id,
    this.userId,
    this.imagePath,
    required this.detectedName,
    required this.category,
    required this.recyclable,
    required this.disposalAdvice,
    this.notes,
    this.confidence = 0.92,
    this.isSynced = false,
    required this.createdAt,
  });

  WasteScan copyWith({
    String? id,
    String? userId,
    String? imagePath,
    String? detectedName,
    WasteCategory? category,
    bool? recyclable,
    String? disposalAdvice,
    String? notes,
    double? confidence,
    bool? isSynced,
    DateTime? createdAt,
  }) {
    return WasteScan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imagePath: imagePath ?? this.imagePath,
      detectedName: detectedName ?? this.detectedName,
      category: category ?? this.category,
      recyclable: recyclable ?? this.recyclable,
      disposalAdvice: disposalAdvice ?? this.disposalAdvice,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'image_path': imagePath,
      'detected_name': detectedName,
      'category': category.name,
      'recyclable': recyclable ? 1 : 0,
      'disposal_advice': disposalAdvice,
      'notes': notes,
      'confidence': confidence,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WasteScan.fromMap(Map<String, dynamic> map) {
    return WasteScan(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      imagePath: map['image_path']?.toString(),
      detectedName: map['detected_name']?.toString() ?? 'Sampah Terdeteksi',
      category: WasteCategory.fromString(map['category']?.toString()),
      recyclable: map['recyclable'] == 1 || map['recyclable'] == true,
      disposalAdvice: map['disposal_advice']?.toString() ?? '',
      notes: map['notes']?.toString(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.85,
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
