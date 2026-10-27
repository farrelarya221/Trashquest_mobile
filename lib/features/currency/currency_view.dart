import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../services/currency_service.dart';

class CurrencyView extends StatefulWidget {
  const CurrencyView({super.key});

  @override
  State<CurrencyView> createState() => _CurrencyViewState();
}

class _CurrencyViewState extends State<CurrencyView> {
  final TextEditingController _amountController = TextEditingController(text: '100000');
  String _fromCurrency = 'IDR';
  String _toCurrency = 'USD';
  double _convertedResult = 0.0;
  bool _isRefreshing = false;

  final List<String> _currencies = ['IDR', 'USD', 'SGD', 'EUR'];

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0.0;
    setState(() {
      _convertedResult = CurrencyService.instance.convert(amount, _fromCurrency, _toCurrency);
    });
  }

  Future<void> _refreshRates() async {
    setState(() => _isRefreshing = true);
    await CurrencyService.instance.refreshRates();
    _calculate();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kurs mata uang berhasil diperbarui.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rates = CurrencyService.instance.rates;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Konversi Mata Uang', style: AppTextStyles.titleMedium),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui Kurs',
            onPressed: _isRefreshing ? null : _refreshRates,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Converter Card
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
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculate(),
                      style: AppTextStyles.titleLarge,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Nominal',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _fromCurrency,
                            decoration: const InputDecoration(labelText: 'Dari'),
                            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _fromCurrency = val);
                                _calculate();
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: IconButton(
                            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                            onPressed: () {
                              setState(() {
                                final temp = _fromCurrency;
                                _fromCurrency = _toCurrency;
                                _toCurrency = temp;
                              });
                              _calculate();
                            },
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _toCurrency,
                            decoration: const InputDecoration(labelText: 'Ke'),
                            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _toCurrency = val);
                                _calculate();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Result Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: Column(
                        children: [
                          Text('Hasil Konversi', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryDark)),
                          const SizedBox(height: 4),
                          Text(
                            '${rates[_toCurrency]?.symbol ?? ''} ${_convertedResult.toStringAsFixed(2)}',
                            style: AppTextStyles.displayMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1 $_fromCurrency = ${(rates[_fromCurrency]!.rateToIdr / rates[_toCurrency]!.rateToIdr).toStringAsFixed(4)} $_toCurrency',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Rates Reference Table
              Text('Daftar Kurs Acuan (terhadap IDR)', style: AppTextStyles.titleSmall),
              const SizedBox(height: 12),
              ..._currencies.where((c) => c != 'IDR').map((code) {
                final rate = rates[code]!;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(rate.symbol, style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
                          const SizedBox(width: 8),
                          Text('${rate.code} (${rate.name})', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                      Text('Rp ${rate.rateToIdr.toStringAsFixed(0)}', style: AppTextStyles.labelMedium),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
