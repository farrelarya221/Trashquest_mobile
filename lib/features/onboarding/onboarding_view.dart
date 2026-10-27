import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

class OnboardingView extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingView({super.key, required this.onFinish});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingItem> _pages = const [
    _OnboardingItem(
      title: 'Kenali Sampah dengan AI',
      subtitle: 'Foto objek sampah apa pun di sekitarmu. AI multimodal cerdas akan mengidentifikasi jenis dan cara pemilahannya seketika.',
      icon: Icons.camera_enhance_rounded,
      tag: 'Cerdas & Akurat',
    ),
    _OnboardingItem(
      title: 'Temukan Tempat Setor',
      subtitle: 'Temukan Bank Sampah terdekat dengan peta interaktif dan navigasi kompas presisi langsung dari lokasimu.',
      icon: Icons.explore_rounded,
      tag: 'Navigasi Kompas & Peta',
    ),
    _OnboardingItem(
      title: 'Belajar Sambil Bermain',
      subtitle: 'Tantang dirimu di mini-game sensor gerak, selesaikan quest harian, dan raih sertifikat verified blockchain.',
      icon: Icons.emoji_events_rounded,
      tag: 'Gamifikasi Interaktif',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        actions: [
          if (_currentIndex < _pages.length - 1)
            TextButton(
              onPressed: widget.onFinish,
              child: Text(
                'Lewati',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Restrained aesthetic illustration card
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: Center(
                            child: Icon(
                              item.icon,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppSpacing.roundedSm,
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Text(
                            item.tag,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.displayMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            item.subtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Page indicators and CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = _currentIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentIndex == _pages.length - 1 ? 'Mulai Sekarang' : 'Lanjut',
                    style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String tag;

  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tag,
  });
}
