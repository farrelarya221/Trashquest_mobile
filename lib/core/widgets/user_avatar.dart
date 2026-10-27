import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AvatarPresetInfo {
  final String id;
  final String name;
  final IconData icon;
  final List<Color> gradient;

  const AvatarPresetInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradient,
  });
}

class UserAvatar extends StatelessWidget {
  final String? profilePicture;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final bool showBadge;
  final VoidCallback? onBadgeTap;
  final bool enablePreview;
  final String? userName;
  final VoidCallback? onTap;
  final VoidCallback? onEditPhoto;

  const UserAvatar({
    super.key,
    required this.profilePicture,
    this.radius = 28,
    this.borderColor,
    this.borderWidth = 2,
    this.showBadge = false,
    this.onBadgeTap,
    this.enablePreview = true,
    this.userName,
    this.onTap,
    this.onEditPhoto,
  });

  static const List<AvatarPresetInfo> presets = [
    AvatarPresetInfo(
      id: 'avatar:ranger',
      name: 'Eco-Ranger',
      icon: Icons.forest_rounded,
      gradient: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
    ),
    AvatarPresetInfo(
      id: 'avatar:ocean',
      name: 'Ocean Guardian',
      icon: Icons.waves_rounded,
      gradient: [Color(0xFF006064), Color(0xFF00BCD4)],
    ),
    AvatarPresetInfo(
      id: 'avatar:bot',
      name: 'WasteBot AI',
      icon: Icons.smart_toy_rounded,
      gradient: [Color(0xFF004D40), Color(0xFF26A69A)],
    ),
    AvatarPresetInfo(
      id: 'avatar:warrior',
      name: 'Earth Guardian',
      icon: Icons.shield_rounded,
      gradient: [Color(0xFFE65100), Color(0xFFFF9800)],
    ),
    AvatarPresetInfo(
      id: 'avatar:hero',
      name: 'Eco-Hero',
      icon: Icons.bolt_rounded,
      gradient: [Color(0xFFB71C1C), Color(0xFFEF5350)],
    ),
    AvatarPresetInfo(
      id: 'avatar:nature',
      name: 'Flora Master',
      icon: Icons.eco_rounded,
      gradient: [Color(0xFF0D5324), Color(0xFF66BB6A)],
    ),
    AvatarPresetInfo(
      id: 'avatar:solar',
      name: 'Solar Knight',
      icon: Icons.wb_sunny_rounded,
      gradient: [Color(0xFFF57F17), Color(0xFFFFEE58)],
    ),
    AvatarPresetInfo(
      id: 'avatar:champion',
      name: 'Eco-Champion',
      icon: Icons.military_tech_rounded,
      gradient: [Color(0xFF4A148C), Color(0xFFAB47BC)],
    ),
  ];

  /// Displays the full enlarged profile photo dialog with zoom and pan support.
  static Future<void> showPreviewDialog(
    BuildContext context, {
    required String? profilePicture,
    String? userName,
    VoidCallback? onEditPhoto,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup Foto Profil',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return _ProfilePhotoPreviewDialog(
          profilePicture: profilePicture,
          userName: userName,
          onEditPhoto: onEditPhoto,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget avatarContent = _buildContent();
    final bool isClickable = onTap != null || enablePreview;

    final Widget avatarWidget = Tooltip(
      message: isClickable ? 'Ketuk untuk memperbesar foto' : '',
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: borderWidth)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isClickable
                ? () {
                    if (onTap != null) {
                      onTap!();
                    } else if (enablePreview) {
                      showPreviewDialog(
                        context,
                        profilePicture: profilePicture,
                        userName: userName,
                        onEditPhoto: onEditPhoto,
                      );
                    }
                  }
                : null,
            child: avatarContent,
          ),
        ),
      ),
    );

    if (!showBadge) return avatarWidget;

    return Stack(
      children: [
        avatarWidget,
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onBadgeTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentMint,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primaryDark,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final pic = profilePicture;

    if (pic == null || pic.trim().isEmpty) {
      return _buildDefaultFallback();
    }

    // 1. Check for Preset Avatars
    if (pic.startsWith('avatar:')) {
      final preset = presets.firstWhere(
        (p) => p.id == pic,
        orElse: () => presets[0],
      );
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: preset.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            preset.icon,
            color: Colors.white,
            size: radius * 1.05,
          ),
        ),
      );
    }

    // 2. Check for Base64 Image
    if (pic.startsWith('data:image') || pic.length > 200) {
      try {
        String base64Data = pic;
        if (base64Data.contains(',')) {
          base64Data = base64Data.split(',').last;
        }
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) => _buildDefaultFallback(),
        );
      } catch (_) {
        // Fallback to file check
      }
    }

    // 3. Check for Local File Path
    try {
      final file = File(pic);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) => _buildDefaultFallback(),
        );
      }
    } catch (_) {}

    // 4. Check for Network URL
    if (pic.startsWith('http://') || pic.startsWith('https://')) {
      return Image.network(
        pic,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder: (context, error, stackTrace) => _buildDefaultFallback(),
      );
    }

    return _buildDefaultFallback();
  }

  Widget _buildDefaultFallback() {
    final name = userName?.trim();
    final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E3D21), Color(0xFF1B6B3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: initial != null
            ? Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.9,
                ),
              )
            : Icon(
                Icons.person_rounded,
                color: AppColors.accentMint,
                size: radius * 1.1,
              ),
      ),
    );
  }
}

/// Modal dialog showing the enlarged profile picture with InteractiveViewer and controls
class _ProfilePhotoPreviewDialog extends StatelessWidget {
  final String? profilePicture;
  final String? userName;
  final VoidCallback? onEditPhoto;

  const _ProfilePhotoPreviewDialog({
    required this.profilePicture,
    this.userName,
    this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPreset = profilePicture != null && profilePicture!.startsWith('avatar:');
    final bool hasCustomPhoto = profilePicture != null &&
        profilePicture!.trim().isNotEmpty &&
        !isPreset;

    AvatarPresetInfo? presetInfo;
    if (isPreset) {
      presetInfo = UserAvatar.presets.firstWhere(
        (p) => p.id == profilePicture,
        orElse: () => UserAvatar.presets[0],
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF132218),
                    Color(0xFF0D1811),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.accentMint.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header with title & close button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentMint.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_circle_rounded,
                          color: AppColors.accentMint,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName != null && userName!.trim().isNotEmpty
                                  ? userName!
                                  : 'Eco-Warrior',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPreset
                                  ? 'Avatar Resmi Eco-Warrior'
                                  : (hasCustomPhoto ? 'Foto Profil Pengguna' : 'Avatar Standar'),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: const CircleBorder(),
                        ),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Photo Area (Enlarged with Interactive Zoom & Pan)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 330, minHeight: 240),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _InteractivePhotoView(
                          child: Center(
                            child: _buildEnlargedContent(context, profilePicture, presetInfo),
                          ),
                        ),
                        if (isPreset && presetInfo != null)
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                presetInfo.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Pinch-to-zoom guidance hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.zoom_in_rounded,
                        size: 14,
                        color: AppColors.accentMint.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Cubit layar (pinch) atau ketuk 2x untuk zoom foto',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Action buttons
                  Row(
                    children: [
                      if (onEditPhoto != null) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onEditPhoto!();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text(
                              'Ubah Foto',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnlargedContent(
    BuildContext context,
    String? pic,
    AvatarPresetInfo? preset,
  ) {
    if (preset != null) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: preset.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: preset.gradient.first.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            preset.icon,
            color: Colors.white,
            size: 100,
          ),
        ),
      );
    }

    if (pic == null || pic.trim().isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF0E3D21), Color(0xFF1B6B3D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: AppColors.accentMint,
                size: 80,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Avatar Standar Eco-Warrior',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // Base64
    if (pic.startsWith('data:image') || pic.length > 200) {
      try {
        String base64Data = pic;
        if (base64Data.contains(',')) {
          base64Data = base64Data.split(',').last;
        }
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildFallbackWidget(),
        );
      } catch (_) {}
    }

    // Local file
    try {
      final file = File(pic);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildFallbackWidget(),
        );
      }
    } catch (_) {}

    // Network URL
    if (pic.startsWith('http://') || pic.startsWith('https://')) {
      return Image.network(
        pic,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentMint),
          );
        },
        errorBuilder: (_, _, _) => _buildFallbackWidget(),
      );
    }

    return _buildFallbackWidget();
  }

  Widget _buildFallbackWidget() {
    return Container(
      width: 150,
      height: 150,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0E3D21), Color(0xFF1B6B3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: AppColors.accentMint,
          size: 80,
        ),
      ),
    );
  }
}

/// Interactive viewer with pinch-to-zoom and double-tap zoom animation
class _InteractivePhotoView extends StatefulWidget {
  final Widget child;
  const _InteractivePhotoView({required this.child});

  @override
  State<_InteractivePhotoView> createState() => _InteractivePhotoViewState();
}

class _InteractivePhotoViewState extends State<_InteractivePhotoView>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late AnimationController _animController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_animation != null) {
          _controller.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix;
    if (currentScale > 1.2) {
      endMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      // ignore: deprecated_member_use
      endMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        // ignore: deprecated_member_use
        ..scale(2.5);
    }
    _animation = Matrix4Tween(
      begin: _controller.value,
      end: endMatrix,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 0.8,
        maxScale: 4.0,
        clipBehavior: Clip.none,
        child: widget.child,
      ),
    );
  }
}
