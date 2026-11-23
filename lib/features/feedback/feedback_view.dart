import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';

class FeedbackView extends StatefulWidget {
  const FeedbackView({super.key});

  @override
  State<FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends State<FeedbackView> {
  int _rating = 5;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoadingFeedbacks = true;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadFeedbacks() async {
    final list = await SqliteService.instance.getFeedbacks();
    if (mounted) {
      setState(() {
        _feedbacks = list;
        _isLoadingFeedbacks = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    final msg = _feedbackController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan pesan saran atau kesanmu.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await SupabaseService.instance.sendFeedback(message: msg, rating: _rating);

    _feedbackController.clear();
    setState(() {
      _rating = 5;
    });

    await _loadFeedbacks();

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Terima kasih! Saran & kesanmu berhasil dikirim.')),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Saran & Kesan', style: AppTextStyles.titleMedium),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.roundedLg,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppSpacing.subtleShadow,
                ),
                child: Column(
                  children: [
                    Text(
                      'Bagaimana Pengalamanmu?',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bantu kami membuat TrashQuest lebih bermanfaat untuk lingkungan.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Star Rating Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          iconSize: 36,
                          icon: Icon(
                            star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: star <= _rating ? AppColors.accent : AppColors.border,
                          ),
                          onPressed: () => setState(() => _rating = star),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Feedback Text Input
              TextField(
                controller: _feedbackController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Pesan Saran atau Kesan',
                  hintText: 'Tuliskan kesan pemakaian, masukan fitur, atau keluhan...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kirim Feedback'),
              ),

              const SizedBox(height: 28),
              const Divider(color: AppColors.border),
              const SizedBox(height: 14),

              // Hasil Kesan & Pesan Terkirim (Tampil tepat di bawah tombol Kirim Feedback)
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hasil Kesan & Pesan',
                      style: AppTextStyles.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_feedbacks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_feedbacks.length} Pesan',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoadingFeedbacks)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              else if (_feedbacks.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: AppColors.textTertiary),
                        const SizedBox(height: 8),
                        Text('Belum ada feedback yang kamu kirim', style: AppTextStyles.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Tuliskan masukanmu di atas lalu tekan "Kirim Feedback". Hasilnya akan langsung muncul di sini.',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _feedbacks.length,
                  itemBuilder: (context, index) {
                    final fb = _feedbacks[index];
                    final rating = (fb['rating'] as num?)?.toInt() ?? 5;
                    final message = fb['message']?.toString() ?? '';
                    final rawDate = fb['created_at'] != null ? DateTime.tryParse(fb['created_at'].toString()) : null;
                    final dateStr = rawDate != null
                        ? '${rawDate.day.toString().padLeft(2, '0')}/${rawDate.month.toString().padLeft(2, '0')}/${rawDate.year} • ${rawDate.hour.toString().padLeft(2, '0')}:${rawDate.minute.toString().padLeft(2, '0')}'
                        : 'Baru saja';
                    final userName = fb['user_name']?.toString() ?? SupabaseService.instance.currentUser.fullName;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(AppSpacing.md),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (starIdx) {
                                  return Icon(
                                    starIdx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: starIdx < rating ? AppColors.accent : AppColors.border,
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  dateStr,
                                  style: AppTextStyles.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(message, style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        userName.isNotEmpty ? userName : 'Pengguna TrashQuest',
                                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tersimpan',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
