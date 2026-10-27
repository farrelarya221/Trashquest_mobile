import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';

class RewardCatalogView extends StatefulWidget {
  const RewardCatalogView({super.key});

  @override
  State<RewardCatalogView> createState() => _RewardCatalogViewState();
}

enum CatalogSortOption { lowestPoint, highestPoint, nameAsc }

class _RewardCatalogViewState extends State<RewardCatalogView> {
  final TextEditingController _accountController = TextEditingController();
  int _selectedFilterIndex = 0; // 0: Semua, 1: E-Wallet, 2: Pulsa, 3: Sembako
  CatalogSortOption _currentSort = CatalogSortOption.lowestPoint;

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 16),
              const Text('Urutkan Katalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              _buildSortTile('Poin Terendah', CatalogSortOption.lowestPoint),
              _buildSortTile('Poin Tertinggi', CatalogSortOption.highestPoint),
              _buildSortTile('Nama Hadiah (A-Z)', CatalogSortOption.nameAsc),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortTile(String label, CatalogSortOption option) {
    final isSelected = _currentSort == option;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? const Color(0xFF047857) : const Color(0xFF334155),
        ),
      ),
      onTap: () {
        setState(() => _currentSort = option);
        Navigator.pop(context);
      },
    );
  }

  String get _currentSortLabel {
    switch (_currentSort) {
      case CatalogSortOption.lowestPoint:
        return 'Poin Terendah';
      case CatalogSortOption.highestPoint:
        return 'Poin Tertinggi';
      case CatalogSortOption.nameAsc:
        return 'Nama (A-Z)';
    }
  }

  void _showRedeemDialog(_CatalogItem item) {
    final user = SupabaseService.instance.currentUser;
    if (user.xp < item.points) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Poin kamu belum cukup untuk menukar ${item.title}! Butuh ${NumberFormat.decimalPattern('id').format(item.points)} Poin.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _accountController.clear();
    bool showError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    child: item.imagePath != null
                        ? ClipOval(
                            child: Image.asset(item.imagePath!, fit: BoxFit.contain),
                          )
                        : Icon(
                            item.fallbackIcon ?? Icons.phone_android_rounded,
                            color: item.fallbackColor ?? const Color(0xFF10B981),
                            size: 34,
                          ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Konfirmasi Penukaran',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                      children: [
                        const TextSpan(text: 'Tukar '),
                        TextSpan(
                          text: '${NumberFormat.decimalPattern('id').format(item.points)} Koin',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                        const TextSpan(text: ' untuk mendapatkan\n'),
                        TextSpan(
                          text: item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  if (item.type == 'digital') ...[
                    const SizedBox(height: 18),
                    TextField(
                      controller: _accountController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor HP / ID Tagihan',
                        hintText: 'Contoh: 08123456789',
                        errorText: showError ? 'Wajib diisi' : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.dialpad_rounded, color: Color(0xFF10B981)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            if (item.type == 'digital' && _accountController.text.trim().isEmpty) {
                              setModalState(() => showError = true);
                              return;
                            }
                            Navigator.pop(ctx);
                            _processRedeem(item.title, item.points, item.type, _accountController.text);
                          },
                          child: const Text('Tukar', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _processRedeem(String itemName, int cost, String type, String accountInfo) async {
    SupabaseService.instance.addXp(-cost);

    final voucherCode = 'TQ-${Random().nextInt(90000) + 10000}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    await SqliteService.instance.insertTransaction({
      'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
      'item_name': itemName,
      'cost': cost,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
      'account_info': type == 'digital' ? accountInfo : null,
      'voucher_code': type == 'sembako' ? voucherCode : null,
      'status': 'Berhasil',
    });

    SupabaseService.instance.saveRedeemTransaction(
      itemName: itemName,
      costXp: cost,
      type: type,
      accountInfo: type == 'digital' ? accountInfo : null,
      voucherCode: type == 'sembako' ? voucherCode : null,
    );

    NotificationService.instance.showNotification(
      title: '🎁 Penukaran Berhasil!',
      body: 'Reward "$itemName" berhasil ditukarkan. Cek riwayat untuk rinciannya.',
      icon: Icons.confirmation_number_rounded,
      iconColor: const Color(0xFF10B981),
    );

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: _RedeemSuccessContent(
                itemName: itemName,
                type: type,
                accountInfo: accountInfo,
                voucherCode: voucherCode,
                onClose: () {
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<_CatalogItem> _getFilteredAndSortedItems() {
    // Connected to actual assets in assets/images/
    final allItems = [
      _CatalogItem(
        title: 'Saldo GoPay 25rb',
        tag: 'GOPAY',
        points: 25000,
        category: 'E-Wallet',
        imagePath: 'assets/images/gopay.png',
        type: 'digital',
      ),
      _CatalogItem(
        title: 'Saldo DANA 50rb',
        tag: 'DANA',
        points: 50000,
        category: 'E-Wallet',
        imagePath: 'assets/images/dana.jpeg',
        type: 'digital',
      ),
      _CatalogItem(
        title: 'Saldo ShopeePay 25rb',
        tag: 'SHOPEE',
        points: 25000,
        category: 'E-Wallet',
        imagePath: 'assets/images/shoppe.jpg',
        type: 'digital',
      ),
      _CatalogItem(
        title: 'Token PLN 50rb',
        tag: 'PLN',
        points: 50000,
        category: 'Pulsa',
        fallbackIcon: Icons.bolt_rounded,
        fallbackColor: const Color(0xFFF59E0B),
        type: 'digital',
      ),
      _CatalogItem(
        title: 'Pulsa Telkomsel 25rb',
        tag: 'TSEL',
        points: 26000,
        category: 'Pulsa',
        imagePath: 'assets/images/tsel.jpg',
        type: 'digital',
      ),
      _CatalogItem(
        title: 'Pulsa Indosat IM3 25rb',
        tag: 'IM3',
        points: 26000,
        category: 'Pulsa',
        imagePath: 'assets/images/im3.png',
        type: 'digital',
      ),
      _CatalogItem(
        title: 'Beras Organik 5 kg',
        tag: 'BERAS',
        points: 75000,
        category: 'Sembako',
        imagePath: 'assets/images/beras.jpg',
        type: 'sembako',
      ),
      _CatalogItem(
        title: 'Minyak Goreng 2L',
        tag: 'MINYAK',
        points: 36000,
        category: 'Sembako',
        imagePath: 'assets/images/minyak goreng.jpg',
        type: 'sembako',
      ),
      _CatalogItem(
        title: 'Gula Pasir 1 kg',
        tag: 'GULA',
        points: 18000,
        category: 'Sembako',
        imagePath: 'assets/images/gula.jpg',
        type: 'sembako',
      ),
      _CatalogItem(
        title: '1 Dus Mie Instan',
        tag: 'MIE',
        points: 48000,
        category: 'Sembako',
        imagePath: 'assets/images/mie.jpg',
        type: 'sembako',
      ),
      _CatalogItem(
        title: 'Telur Ayam 1 Tray',
        tag: 'TELUR',
        points: 38000,
        category: 'Sembako',
        imagePath: 'assets/images/telur ayam.webp',
        type: 'sembako',
      ),
      _CatalogItem(
        title: 'Susu Segar UHT 1L',
        tag: 'SUSU',
        points: 19000,
        category: 'Sembako',
        imagePath: 'assets/images/susu.jpg',
        type: 'sembako',
      ),
      _CatalogItem(
        title: 'Deterjen Ramah Lingkungan',
        tag: 'DETERGEN',
        points: 22000,
        category: 'Sembako',
        imagePath: 'assets/images/detergen.jpg',
        type: 'sembako',
      ),
    ];

    List<_CatalogItem> filtered;
    if (_selectedFilterIndex == 1) {
      filtered = allItems.where((i) => i.category == 'E-Wallet').toList();
    } else if (_selectedFilterIndex == 2) {
      filtered = allItems.where((i) => i.category == 'Pulsa').toList();
    } else if (_selectedFilterIndex == 3) {
      filtered = allItems.where((i) => i.category == 'Sembako').toList();
    } else {
      filtered = allItems;
    }

    switch (_currentSort) {
      case CatalogSortOption.lowestPoint:
        filtered.sort((a, b) => a.points.compareTo(b.points));
        break;
      case CatalogSortOption.highestPoint:
        filtered.sort((a, b) => b.points.compareTo(a.points));
        break;
      case CatalogSortOption.nameAsc:
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;
    final categories = ['Semua', 'E-Wallet', 'Pulsa', 'Sembako'];
    final items = _getFilteredAndSortedItems();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981), width: 1.5),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF047857)),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Katalog Penukaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                height: 1.15,
              ),
            ),
            Text(
              'Hadiah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                height: 1.15,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 14, bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${NumberFormat.decimalPattern('id').format(user.xp)} KOIN',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter Pills
            Row(
              children: List.generate(categories.length, (idx) {
                final isSelected = _selectedFilterIndex == idx;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: idx < categories.length - 1 ? 8 : 0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedFilterIndex = idx),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF10B981) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            categories[idx],
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // 2-Column Grid of Rewards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildCatalogCard(item);
              },
            ),
            const SizedBox(height: 20),

            // Bottom Sort Button
            InkWell(
              onTap: _showSortBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.6),
                ),
                child: Center(
                  child: Text(
                    '[ URUTKAN: ${_currentSortLabel.toUpperCase()} v ]',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF047857),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogCard(_CatalogItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image / Voucher Asset Box
          Container(
            height: 78,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFECFDF5), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: item.imagePath != null
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        item.imagePath!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            item.tag,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        item.fallbackIcon ?? Icons.bolt_rounded,
                        color: item.fallbackColor ?? const Color(0xFFF59E0B),
                        size: 38,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Points
          Text(
            '${NumberFormat.decimalPattern('id').format(item.points)} Koin',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const Spacer(),

          // [ TUKAR ] Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showRedeemDialog(item),
              child: const Text(
                '[ TUKAR ]',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogItem {
  final String title;
  final String tag;
  final int points;
  final String category;
  final String? imagePath;
  final IconData? fallbackIcon;
  final Color? fallbackColor;
  final String type;

  _CatalogItem({
    required this.title,
    required this.tag,
    required this.points,
    required this.category,
    this.imagePath,
    this.fallbackIcon,
    this.fallbackColor,
    required this.type,
  });
}

class _RedeemSuccessContent extends StatefulWidget {
  final String itemName;
  final String type;
  final String accountInfo;
  final String voucherCode;
  final VoidCallback onClose;

  const _RedeemSuccessContent({
    required this.itemName,
    required this.type,
    required this.accountInfo,
    required this.voucherCode,
    required this.onClose,
  });

  @override
  State<_RedeemSuccessContent> createState() => _RedeemSuccessContentState();
}

class _RedeemSuccessContentState extends State<_RedeemSuccessContent> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
              ),
              const SizedBox(height: 18),
              const Text(
                'Penukaran Berhasil!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Kamu berhasil menukarkan ${widget.itemName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              if (widget.type == 'sembako') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'KODE: ${widget.voucherCode}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.voucherCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kode voucher disalin!')),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: widget.onClose,
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 25,
          colors: const [Color(0xFF10B981), Color(0xFF34D399), Color(0xFFF59E0B), Colors.blue],
        ),
      ],
    );
  }
}
