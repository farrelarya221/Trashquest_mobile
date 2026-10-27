import 'package:flutter/material.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/models/waste_item.dart';

class CategoryBadge extends StatelessWidget {
  final WasteCategory category;
  final bool isCompact;

  const CategoryBadge({
    super.key,
    required this.category,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: category.softColor,
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(color: category.color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category.icon,
            size: isCompact ? 13 : 16,
            color: category.color,
          ),
          const SizedBox(width: 5),
          Text(
            category.displayName,
            style: (isCompact ? AppTextStyles.labelSmall : AppTextStyles.labelMedium).copyWith(
              color: category.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
