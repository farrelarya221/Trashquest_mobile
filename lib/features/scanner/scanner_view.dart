import 'dart:io';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/waste_item.dart';
import '../../data/models/waste_scan.dart';
import '../../services/gemini_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import '../encyclopedia/waste_detail_view.dart';

class ScannerView extends StatefulWidget {
  final VoidCallback onNavigateToExplore;
  final VoidCallback? onOpenProfile;

  const ScannerView({
    super.key,
    required this.onNavigateToExplore,
    this.onOpenProfile,
  });

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  GeminiClassificationResult? _result;
  bool _isSaved = false;
  late ConfettiController _confettiController;
  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _result = null;
          _isSaved = false;
        });
        _analyzeImage(image);
      }
    } catch (e) {
      final msg = 'Gagal mengakses kamera/galeri: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _analyzeImage(XFile image) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      GeminiClassificationResult res;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        res = await GeminiService.instance.classifyWasteImage(bytes);
      } else {
        res = await GeminiService.instance.classifyWasteImage(File(image.path));
      }

      setState(() {
        _result = res;
      });
    } catch (e) {
      final msg = 'Tidak ada koneksi internet atau analisis gagal: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveResult() async {
    if (_isSaved || _result == null) return;

    final detectedName = _result!.name;
    final category = _result!.category;
    final recyclable = _result!.recyclable;
    final disposalAdvice = _result!.disposalAdvice;
    final notes = _result!.notes;
    final confidence = _result!.confidence;

    final scan = WasteScan(
      id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
      userId: SupabaseService.instance.currentUser.id,
      imagePath: _selectedImage?.path,
      detectedName: detectedName,
      category: category,
      recyclable: recyclable,
      disposalAdvice: disposalAdvice,
      notes: notes,
      confidence: confidence,
      createdAt: DateTime.now(),
    );

    await SqliteService.instance.insertScan(scan);
    SupabaseService.instance.addXp(45);
    SupabaseService.instance.incrementScanCount();
    await SupabaseService.instance.syncScan(scan);

    if (mounted) {
      setState(() => _isSaved = true);
      _confettiController.play();

      NotificationService.instance.showNotification(
        title: '📸 Sampah Berhasil Dipilah!',
        body: '$detectedName (${category.displayName}) tersimpan. +45 Poin ditambahkan!',
        icon: Icons.camera_alt_rounded,
        iconColor: const Color(0xFF10B981),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Catatan tersimpan! +45 Poin berhasil diklaim ke dompet.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openDetailView(GeminiClassificationResult? result) async {
    final category = result?.category ?? WasteCategory.anorganik;
    final name = result?.name ?? 'Botol Plastik PET (#1)';
    final desc = (result != null && result.notes.isNotEmpty)
        ? result.notes
        : 'Polyethylene Terephthalate • Plastik minuman kemasan';
    final decomp = (result != null && result.decompositionTime.isNotEmpty)
        ? result.decompositionTime
        : '450 Tahun';
    final price = (result != null && result.economicValue.isNotEmpty)
        ? result.economicValue
        : 'Rp 3.500 - Rp 5.000 / kg (Bening Bersih)';

    final item = WasteItem(
      id: 'scan-detail-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: category,
      description: desc,
      recyclable: result?.recyclable ?? true,
      disposalAdvice: result?.disposalAdvice ?? 'Kosongkan sisa air & remas sebelum disetor.',
      decompositionTime: decomp,
      materialType: 'Polyethylene Terephthalate • Plastik minuman kemasan',
    );

    final shouldFindBankSampah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WasteDetailView(
          item: item,
          imageUrl: _selectedImage != null ? _selectedImage!.path : 'assets/images/anorganik.jpg',
          recyclingCode: category == WasteCategory.anorganik ? '#1 (PETE)' : 'CAT-${category.name.toUpperCase()}',
          marketPrice: price,
          onFindBankSampah: () {},
        ),
      ),
    );

    if (shouldFindBankSampah == true && mounted) {
      // Pop the scanner view so user is not stuck on scanner
      Navigator.pop(context);
      // Switch tab to explore (Bank Sampah & TPS Map)
      widget.onNavigateToExplore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFB),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Header: [ < ]  Pindai Sampah AI  [ FLASH ]
                  _buildHeader(),
                  const SizedBox(height: 12),

                  // 2. Model Status Bar: ● Model: Groq Vision AI • Respons 0.9s ... ONLINE
                  _buildTopBadges(),
                  const SizedBox(height: 14),

                  // 3. Camera Viewfinder Section (Viewfinder, corner HUD, target box, sweeping laser with badge)
                  _buildViewfinderSection(),
                  const SizedBox(height: 16),

                  // 4. Camera Controls Row: Galeri & Shutter Capture
                  _buildControlsRow(),
                  const SizedBox(height: 16),

                  // 5. Bottom Detection Summary Card (Thumbnail, Title, Category/Accuracy, Value, 3R Advice, Lihat Detail Lengkap 3R)
                  if (_isAnalyzing)
                    _buildAnalyzingCard()
                  else if (_result != null)
                    _buildResultCard()
                  else
                    _buildEmptyStateCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Confetti Overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: math.pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 25,
                gravity: 0.1,
                colors: const [
                  Color(0xFF10B981),
                  Color(0xFF34D399),
                  Color(0xFFF59E0B),
                  Colors.blue,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Header: Back button + Pindai Sampah AI
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back Button in rounded border
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          ),
        ),

        // Title: Pindai Sampah AI
        const Expanded(
          child: Center(
            child: Text(
              'Pindai Sampah AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // Symmetrical spacer to keep title centered
        const SizedBox(width: 42),
      ],
    );
  }

  // 2. Status Bar matching Wireframe: ● Model: Groq Vision AI • Respons 0.9s ... ONLINE
  Widget _buildTopBadges() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Model: Groq Vision AI • Respons 0.9s',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Text(
              'ONLINE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16A34A),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Camera Viewfinder Section matching Wireframe
  Widget _buildViewfinderSection() {
    final String targetName;
    if (_result != null) {
      targetName = _result!.name.toUpperCase();
    } else if (_isAnalyzing) {
      targetName = 'MEMINDAI DENGAN AI...';
    } else {
      targetName = 'BIDIK OBJEK SAMPAH';
    }

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Background Image (Real capture or camera viewfinder ready state)
          if (_selectedImage != null)
            kIsWeb
                ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                : Image.file(File(_selectedImage!.path), fit: BoxFit.cover)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Color(0xFF22C55E),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Kamera Siap Memindai',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Posisikan sampah di dalam kotak bidik',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4 Corner HUD Reticles & diagonal guidelines
          _buildReticleCorners(),

          // Center Bounding Box (Target Detection Box matching Wireframe)
          Center(
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Floating Top Pill: "OBYEK: BOTOL PLASTIK PET"
                  Positioned(
                    top: -14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.center_focus_strong_rounded, size: 12, color: Color(0xFF22C55E)),
                          const SizedBox(width: 5),
                          Text(
                            'OBYEK: $targetName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sweeping Laser Scan Line with floating badge "GARIS LASER SCAN"
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, _) {
                      final laserOffset = 15.0 + (_laserController.value * 170.0);
                      return Positioned(
                        top: laserOffset,
                        left: 0,
                        right: 0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Horizontal glowing laser line
                            Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Color(0xFF22C55E),
                                    Colors.white,
                                    Color(0xFF22C55E),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),

                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Camera Controls Row: Galeri & Shutter Capture
  Widget _buildControlsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Galeri Button
          InkWell(
            onTap: () => _pickImage(ImageSource.gallery),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF0F172A)),
                  SizedBox(width: 6),
                  Text(
                    'Galeri',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Large Shutter Capture Button (Center concentric rings)
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFF0F172A), width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // Symmetrical spacer so Shutter stays centered
          const SizedBox(width: 92),
        ],
      ),
    );
  }

  // 4 Corner HUD Reticles & diagonal guidelines
  Widget _buildReticleCorners() {
    const reticleColor = Color(0xFF22C55E);
    const lineLen = 28.0;
    const lineThick = 3.5;

    return Stack(
      children: [
        // Diagonal corner guidelines
        CustomPaint(
          size: Size.infinite,
          painter: _ReticleGuidelinesPainter(color: reticleColor),
        ),

        // Top-Left
        Positioned(
          top: 18,
          left: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: lineLen, height: lineThick, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
              Container(width: lineThick, height: lineLen, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
            ],
          ),
        ),

        // Top-Right
        Positioned(
          top: 18,
          right: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(width: lineLen, height: lineThick, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
              Container(width: lineThick, height: lineLen, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
            ],
          ),
        ),

        // Bottom-Left
        Positioned(
          bottom: 18,
          left: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: lineThick, height: lineLen, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
              Container(width: lineLen, height: lineThick, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
            ],
          ),
        ),

        // Bottom-Right
        Positioned(
          bottom: 18,
          right: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(width: lineThick, height: lineLen, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
              Container(width: lineLen, height: lineThick, decoration: BoxDecoration(color: reticleColor, borderRadius: BorderRadius.circular(2))),
            ],
          ),
        ),
      ],
    );
  }

  // 5. Detection Result Card matching Wireframe
  Widget _buildResultCard() {
    if (_result == null) return const SizedBox.shrink();
    final res = _result!;
    final title = res.name;
    final accuracy = (res.confidence * 100).toInt();
    final categoryText = res.category.displayName;
    final valueText = res.economicValue.isNotEmpty ? res.economicValue : 'Est. Rp 450';
    final advice = res.disposalAdvice.isNotEmpty ? res.disposalAdvice : 'Kosongkan sisa air & remas sebelum disetor.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: [ THUMB ] + Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail Box with HUD corner borders
              _buildThumbnailBox(
                image: _selectedImage != null
                    ? (kIsWeb
                        ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                        : Image.file(File(_selectedImage!.path), fit: BoxFit.cover))
                    : Image.asset('assets/images/anorganik.jpg', fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),

              // Title, Category & Accuracy, Value
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kategori: $categoryText • Akurasi $accuracy%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Nilai: +45 Poin ',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          TextSpan(
                            text: '• $valueText',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subtle Divider
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.2, height: 1),
          const SizedBox(height: 12),

          // Saran 3R text
          Text(
            'Saran 3R: $advice',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Primary Button: Lihat Detail Lengkap 3R
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openDetailView(res),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF22C55E)),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Lihat Detail Lengkap 3R',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Claim / Save Button: [ SIMPAN CATATAN & KLAIM +45 POIN ]
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? const Color(0xFFDCFCE7) : const Color(0xFF16A34A),
                foregroundColor: _isSaved ? const Color(0xFF16A34A) : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: _isSaved ? const BorderSide(color: Color(0xFF86EFAC)) : BorderSide.none,
                ),
              ),
              onPressed: _saveResult,
              icon: Icon(
                _isSaved ? Icons.check_circle_rounded : Icons.bookmark_added_rounded,
                size: 18,
                color: _isSaved ? const Color(0xFF16A34A) : Colors.white,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isSaved ? 'Catatan Tersimpan (+45 Poin)' : 'Simpan Catatan & Klaim +45 Poin',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Reset scan button
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _result = null;
                  _selectedImage = null;
                  _isSaved = false;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
              label: const Text(
                'Pindai Sampah Lain',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5b. Empty State Card (Panduan sebelum memotret / memilih foto)
  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Color(0xFF16A34A),
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Siap Memindai Sampah',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tekan tombol kamera di atas untuk memotret sampah, atau tombol Galeri untuk memilih foto dari galeri perangkat Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFeatureBadge(Icons.auto_awesome_rounded, 'Vision AI'),
                _buildFeatureBadge(Icons.timer_outlined, 'Respons 0.9s'),
                _buildFeatureBadge(Icons.recycling_rounded, 'Panduan 3R'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF16A34A)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  // Thumbnail Widget with rounded border
  Widget _buildThumbnailBox({required Widget image}) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  // Indicating Vision AI is actively processing
  Widget _buildAnalyzingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Menganalisis Sampah dengan Vision AI...',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Mengidentifikasi kategori polimer, potensi daur ulang, dan estimasi nilai ekonomi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for HUD diagonal corner guidelines
class _ReticleGuidelinesPainter extends CustomPainter {
  final Color color;
  const _ReticleGuidelinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const len = 30.0;
    // Top-left guideline
    canvas.drawLine(const Offset(22, 22), const Offset(22 + len, 22 + len), paint);
    // Top-right guideline
    canvas.drawLine(Offset(size.width - 22, 22), Offset(size.width - 22 - len, 22 + len), paint);
    // Bottom-left guideline
    canvas.drawLine(Offset(22, size.height - 22), Offset(22 + len, size.height - 22 - len), paint);
    // Bottom-right guideline
    canvas.drawLine(Offset(size.width - 22, size.height - 22), Offset(size.width - 22 - len, size.height - 22 - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
