import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../services/timezone_service.dart';

class TimezoneView extends StatefulWidget {
  const TimezoneView({super.key});

  @override
  State<TimezoneView> createState() => _TimezoneViewState();
}

class _TimezoneViewState extends State<TimezoneView> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timezones = TimezoneService.instance.getAllTimezones(customUtc: _now);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Konversi Zona Waktu', style: AppTextStyles.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppSpacing.roundedMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.primaryDark, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sinkronisasi otomatis WIB (UTC+7), WITA (UTC+8), WIT (UTC+9), dan London (BST/GMT) dengan deteksi musim panas (DST).',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ...timezones.map((tz) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(AppSpacing.lg),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: AppSpacing.roundedSm,
                          ),
                          child: Text(
                            tz.code,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          tz.formattedTime.split('•').first.trim(),
                          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(tz.name, style: AppTextStyles.titleSmall),
                    const SizedBox(height: 2),
                    Text(tz.region, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      tz.formattedTime.split('•').last.trim(),
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
