import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

enum WasteCategory {
  organik,
  anorganik,
  b3,
  residu;

  String get displayName {
    switch (this) {
      case WasteCategory.organik:
        return 'Organik';
      case WasteCategory.anorganik:
        return 'Anorganik';
      case WasteCategory.b3:
        return 'Limbah B3';
      case WasteCategory.residu:
        return 'Residu';
    }
  }

  Color get color {
    switch (this) {
      case WasteCategory.organik:
        return AppColors.wasteOrganik;
      case WasteCategory.anorganik:
        return AppColors.wasteAnorganik;
      case WasteCategory.b3:
        return AppColors.wasteB3;
      case WasteCategory.residu:
        return AppColors.wasteResidu;
    }
  }

  Color get softColor {
    switch (this) {
      case WasteCategory.organik:
        return AppColors.wasteOrganikSoft;
      case WasteCategory.anorganik:
        return AppColors.wasteAnorganikSoft;
      case WasteCategory.b3:
        return AppColors.wasteB3Soft;
      case WasteCategory.residu:
        return AppColors.wasteResiduSoft;
    }
  }

  IconData get icon {
    switch (this) {
      case WasteCategory.organik:
        return Icons.eco_rounded;
      case WasteCategory.anorganik:
        return Icons.recycling_rounded;
      case WasteCategory.b3:
        return Icons.warning_amber_rounded;
      case WasteCategory.residu:
        return Icons.delete_outline_rounded;
    }
  }

  static WasteCategory fromString(String? val) {
    if (val == null) return WasteCategory.anorganik;
    final lower = val.toLowerCase().trim();
    if (lower.contains('organik') && !lower.contains('anorganik')) return WasteCategory.organik;
    if (lower.contains('anorganik') || lower.contains('inorganik')) return WasteCategory.anorganik;
    if (lower.contains('b3') || lower.contains('berbahaya')) return WasteCategory.b3;
    if (lower.contains('residu') || lower.contains('residue')) return WasteCategory.residu;
    return WasteCategory.anorganik;
  }
}

class WasteItem {
  final String id;
  final String name;
  final WasteCategory category;
  final String description;
  final bool recyclable;
  final String disposalAdvice;
  final String? decompositionTime;
  final String? materialType;

  const WasteItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.recyclable,
    required this.disposalAdvice,
    this.decompositionTime,
    this.materialType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'description': description,
      'recyclable': recyclable ? 1 : 0,
      'disposal_advice': disposalAdvice,
      'decomposition_time': decompositionTime,
      'material_type': materialType,
    };
  }

  factory WasteItem.fromMap(Map<String, dynamic> map) {
    return WasteItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: WasteCategory.fromString(map['category']?.toString()),
      description: map['description']?.toString() ?? '',
      recyclable: map['recyclable'] == 1 || map['recyclable'] == true,
      disposalAdvice: map['disposal_advice']?.toString() ?? '',
      decompositionTime: map['decomposition_time']?.toString(),
      materialType: map['material_type']?.toString(),
    );
  }
}
