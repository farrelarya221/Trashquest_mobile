import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/user_profile.dart';
import '../../services/sqlite_service.dart';
import '../../services/supabase_service.dart';
import '../../services/blockchain_service.dart';
import '../blockchain/blockchain_view.dart';
import 'reward_catalog_view.dart';

class RedeemView extends StatefulWidget {
  final VoidCallback? onOpenProfile;

  const RedeemView({super.key, this.onOpenProfile});

  @override
  State<RedeemView> createState() => _RedeemViewState();
}

class _RedeemViewState extends State<RedeemView> {
  List<Map<String, dynamic>> _transactionHistory = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final txs = await SqliteService.instance.getTransactions();
    if (mounted) {
      setState(() {
        _transactionHistory = txs;
      });
    }
  }

  void _showTransactionHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Text('Riwayat Transaksi & Dompet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Expanded(
                child: _transactionHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 14),
                            const Text('Belum ada transaksi tersimpan', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        itemCount: _transactionHistory.length,
                        itemBuilder: (context, index) {
                          final tx = _transactionHistory[index];
                          final rawDate = tx['created_at'] != null ? DateTime.tryParse(tx['created_at'].toString()) : null;
                          final dateStr = rawDate != null ? DateFormat('dd MMM yyyy, HH:mm').format(rawDate) : 'Baru saja';
                          final itemName = tx['item_name'] ?? 'Penukaran XP';
                          final cost = tx['cost'] ?? 0;
                          final voucherCode = tx['voucher_code'];
                          final type = tx['type'] ?? 'digital';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: type == 'digital' ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    type == 'digital' ? Icons.phone_android_rounded : Icons.storefront_rounded,
                                    color: type == 'digital' ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName.toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (voucherCode != null && voucherCode.toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Voucher: $voucherCode',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () {
                                                Clipboard.setData(ClipboardData(text: voucherCode.toString()));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Kode voucher disalin!'), duration: Duration(seconds: 1)),
                                                );
                                              },
                                              child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF10B981)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('-$cost Poin', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFEF4444))),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Berhasil', style: TextStyle(fontSize: 9.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCatalog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RewardCatalogView()),
    ).then((_) {
      if (mounted) setState(() {});
      _loadTransactions();
    });
  }

  void _showPointsInfoDialog(UserProfile user) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
                    child: const Icon(Icons.eco_rounded, color: Color(0xFF047857), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Informasi Saldo Poin & Koin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text('${formatCurrency.format(user.xp)} Koin Ekologis', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFA7F3D0))),
                child: Column(
                  children: [
                    _buildInfoRow('Kurs Konversi', '1 Koin = Rp 1 IDR (Nilai Stabil 1:1)'),
                    const Divider(height: 16),
                    _buildInfoRow('Nilai Nominal', '≈ Rp ${formatCurrency.format(user.xp)} IDR'),
                    const Divider(height: 16),
                    _buildInfoRow('Perolehan', 'Scan Sampah (+25-50 XP) & Setor Bank Sampah'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openCatalog();
                  },
                  child: const Text('Buka Katalog Penukaran Hadiah', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Flexible(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)), textAlign: TextAlign.end),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getActiveVouchers() {
    final List<Map<String, dynamic>> list = [];

    // Custom vouchers from SQLite transactions
    for (final tx in _transactionHistory) {
      if (tx['voucher_code'] != null && tx['voucher_code'].toString().isNotEmpty) {
        list.add({
          'tag': tx['type'] == 'sembako' ? 'KUPON' : 'GOPAY',
          'title': tx['item_name'] ?? 'Voucher Belanja',
          'subtitle': 'Kode: ${tx['voucher_code']}',
          'expiry': 'Exp: 31 Des 2026',
          'action': 'GUNAKAN',
          'code': tx['voucher_code'],
        });
      }
    }

    // Default active vouchers matching mockup
    if (list.isEmpty) {
      list.addAll([
        {
          'tag': 'KUPON',
          'title': 'Diskon Sembako Rp 20.000',
          'subtitle': 'Min. belanja 50rb di Mitra',
          'expiry': 'Exp: 31 Des 2026',
          'action': 'GUNAKAN',
          'code': 'TQ-SEMBAKO-20K',
        },
        {
          'tag': 'GOPAY',
          'title': 'Saldo GoPay Rp 25.000',
          'subtitle': 'Klaim langsung ke akun',
          'expiry': 'Exp: 15 Nov 2026',
          'action': 'KLAIM',
          'code': 'TQ-GOPAY-25K',
        },
      ]);
    }

    return list;
  }

  void _handleUseVoucher(Map<String, dynamic> voucher) {
    final code = voucher['code'] ?? 'TQ-ECO-VOUCHER';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF047857), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                voucher['title'] ?? 'Klaim Voucher',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Tunjukkan kode voucher berikut kepada kasir Mitra Bank Sampah atau masukkan pada aplikasi e-wallet:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0), style: BorderStyle.solid),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(voucher['expiry'] ?? 'Exp: 31 Des 2026', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kode voucher $code berhasil disalin!'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin Kode', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;
    final activeVouchers = _getActiveVouchers();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: InkWell(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
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
        title: const Text(
          'Dompet Koin',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card 1: Saldo Koin Ekologis (Green borders and buttons)
            _buildBalanceCard(user),
            const SizedBox(height: 16),

            // Card 2: Tukar Koin dengan Hadiah Menarik! (Green borders)
            _buildExchangeBanner(),
            const SizedBox(height: 20),

            // Section 3: VOUCHER SAYA YANG AKTIF (2):
            Text(
              'VOUCHER SAYA YANG AKTIF (${activeVouchers.length}):',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Voucher Ticket Cards (Green styling)
            ...activeVouchers.map((v) => _buildVoucherTicketCard(v)),
            const SizedBox(height: 18),

            // Bukti Kontribusi Nyata Card (Green styling & 0 Pixel Overflow)
            _buildContributionCertificateCard(),
            const SizedBox(height: 18),

            // Bottom Card: SMART CONTRACT ADDRESS (Green borders)
            _buildSmartContractCard(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // Card 1: Saldo Koin Ekologis
  Widget _buildBalanceCard(UserProfile user) {
    final formatCurrency = NumberFormat.decimalPattern('id');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SALDO KOIN EKOLOGIS:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF047857),
                  letterSpacing: 0.6,
                ),
              ),
              InkWell(
                onTap: () => _showPointsInfoDialog(user),
                child: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            '${formatCurrency.format(user.xp)} KOIN',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            '≈ Rp ${formatCurrency.format(user.xp)} IDR (Kurs 1 Koin = Rp 1 IDR)',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _openCatalog,
                  child: const Text(
                    '+ Tarik Saldo',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.6),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _showTransactionHistory,
                  child: const Text(
                    'Riwayat Mutasi',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2: Tukar Koin dengan Hadiah Menarik!
  Widget _buildExchangeBanner() {
    return InkWell(
      onTap: _openCatalog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tukar Koin dengan Hadiah Menarik!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Voucher belanja sembako, pulsa, token listrik, & e-wallet.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Buka Katalog Penukaran >',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF047857),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Voucher Ticket Card matching mockup (Green borders)
  Widget _buildVoucherTicketCard(Map<String, dynamic> v) {
    final tag = v['tag'] ?? 'KUPON';
    final title = v['title'] ?? 'Voucher Belanja';
    final subtitle = v['subtitle'] ?? 'Min. belanja 50rb di Mitra';
    final expiry = v['expiry'] ?? 'Exp: 31 Des 2026';
    final action = v['action'] ?? 'GUNAKAN';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
      ),
      child: Row(
        children: [
          // Left Ticket Box Graphic (Green lines)
          CustomPaint(
            size: const Size(54, 54),
            painter: EnvelopeCouponPainter(borderColor: const Color(0xFF10B981)),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Middle Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  expiry,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),

          // Dashed Vertical Line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (index) => Container(
                  width: 1.5,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: const Color(0xFFA7F3D0),
                ),
              ),
            ),
          ),

          // Right Action Button (Green button)
          InkWell(
            onTap: () => _handleUseVoucher(v),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '[ $action ]',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 3: Bukti Kontribusi Nyata Card (Zero Pixel Overflow & Green styling)
  Widget _buildContributionCertificateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.park_rounded, color: Color(0xFF047857), size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Bukti Kontribusi Nyata',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF064E3B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1),
                ),
                child: const Text(
                  'ID: #9942',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Inner Certificate Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD1FAE5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sertifikat Pejuang Bumi #9942',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: const [
                          Icon(Icons.cloud_outlined, size: 15, color: Color(0xFF047857)),
                          Text(
                            '148.5 kg',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                          ),
                          Text(
                            'CO2 Offset',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'On-Chain di Ethereum Sepolia Etherscan',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.military_tech_rounded, color: Color(0xFF059669), size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Button Buka Eco-Ledger & Etherscan
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockchainView()));
              },
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: const Text(
                'Buka Eco-Ledger & Etherscan ↗',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Card: SMART CONTRACT ADDRESS (Green borders)
  Widget _buildSmartContractCard() {
    final contractShort = BlockchainService.contractAddress.length > 12
        ? '${BlockchainService.contractAddress.substring(0, 6)}...${BlockchainService.contractAddress.substring(BlockchainService.contractAddress.length - 4)}'
        : '0x71C...89B';

    return InkWell(
      onTap: () async {
        final url = Uri.parse('https://sepolia.etherscan.io/address/${BlockchainService.contractAddress}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockchainView()));
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMART CONTRACT ADDRESS:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF047857),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$contractShort • Konsorsium Bank Sampah',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF10B981)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Envelope / Coupon Icon Painter (Green Border)
class EnvelopeCouponPainter extends CustomPainter {
  final Color borderColor;
  EnvelopeCouponPainter({this.borderColor = const Color(0xFF10B981)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, paint);

    final innerW = size.width * 0.60;
    final innerH = size.height * 0.40;
    final innerLeft = (size.width - innerW) / 2;
    final innerTop = (size.height - innerH) / 2;
    final innerRight = innerLeft + innerW;
    final innerBottom = innerTop + innerH;

    canvas.drawLine(const Offset(0, 0), Offset(innerLeft, innerTop), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(innerRight, innerTop), paint);
    canvas.drawLine(Offset(0, size.height), Offset(innerLeft, innerBottom), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(innerRight, innerBottom), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
