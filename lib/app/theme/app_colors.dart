import 'package:flutter/material.dart';

/// Design tokens for TrashQuest as specified in the Master Specification.
/// Modern, clean, minimal eco-tech aesthetic.
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF2E7D5B);
  static const Color primaryDark = Color(0xFF205A42);
  static const Color primaryLight = Color(0xFF439A73);
  static const Color primarySoft = Color(0xFFE8F3ED);
  static const Color primarySubtle = Color(0xFFF1F8F4);

  // Accent Colors
  static const Color accent = Color(0xFFE7A93B);
  static const Color accentDark = Color(0xFFC88D27);
  static const Color accentSoft = Color(0xFFFFF4DC);
  static const Color accentMint = Color(0xFF4CAF50);
  static const Color accentGold = Color(0xFFE7A93B);

  // Neutral Background & Surfaces
  static const Color background = Color(0xFFF7F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF0F2EF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Typography Colors
  static const Color textPrimary = Color(0xFF17211B);
  static const Color textSecondary = Color(0xFF66716A);
  static const Color textTertiary = Color(0xFF9AA49E);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE1E6E2);
  static const Color borderLight = Color(0xFFECEFE8);
  static const Color borderFocus = Color(0xFF2E7D5B);

  // Semantic Status Colors
  static const Color success = Color(0xFF2E8B57);
  static const Color successSoft = Color(0xFFE7F6ED);
  static const Color warning = Color(0xFFE09B2D);
  static const Color warningSoft = Color(0xFFFEF5E7);
  static const Color error = Color(0xFFD9534F);
  static const Color errorSoft = Color(0xFFFDE8E8);
  static const Color info = Color(0xFF2B82C9);
  static const Color infoSoft = Color(0xFFE8F3FC);

  // Waste Categories
  static const Color wasteOrganik = Color(0xFF2E7D5B);       // Green
  static const Color wasteOrganikSoft = Color(0xFFE8F3ED);
  static const Color wasteAnorganik = Color(0xFF2575FC);     // Blue
  static const Color wasteAnorganikSoft = Color(0xFFEBF2FF);
  static const Color wasteB3 = Color(0xFFE04A3A);            // Red
  static const Color wasteB3Soft = Color(0xFFFFECEB);
  static const Color wasteResidu = Color(0xFF757575);        // Slate
  static const Color wasteResiduSoft = Color(0xFFF0F0F0);
}
