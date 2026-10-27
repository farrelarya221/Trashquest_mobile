import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CurrencyRate {
  final String code;
  final String name;
  final double rateToIdr; // How many IDR is 1 unit of this currency
  final String symbol;

  const CurrencyRate({
    required this.code,
    required this.name,
    required this.rateToIdr,
    required this.symbol,
  });
}

class CurrencyService {
  static final CurrencyService instance = CurrencyService._internal();
  CurrencyService._internal();

  DateTime lastUpdated = DateTime.now();

  // Cached base exchange rates against IDR
  final Map<String, CurrencyRate> _rates = {
    'IDR': const CurrencyRate(code: 'IDR', name: 'Indonesian Rupiah', rateToIdr: 1.0, symbol: 'Rp'),
    'USD': const CurrencyRate(code: 'USD', name: 'US Dollar', rateToIdr: 18000.0, symbol: '\$'),
    'SGD': const CurrencyRate(code: 'SGD', name: 'Singapore Dollar', rateToIdr: 11920.0, symbol: 'S\$'),
    'EUR': const CurrencyRate(code: 'EUR', name: 'Euro', rateToIdr: 17200.0, symbol: '€'),
  };

  Map<String, CurrencyRate> get rates => Map.unmodifiable(_rates);

  /// Convert amount from source currency to target currency
  double convert(double amount, String fromCode, String toCode) {
    final fromRate = _rates[fromCode]?.rateToIdr ?? 1.0;
    final toRate = _rates[toCode]?.rateToIdr ?? 1.0;

    // Convert to base IDR then to target
    final amountInIdr = amount * fromRate;
    return amountInIdr / toRate;
  }

  /// Fetch live exchange rates from open-access rate API with cached fallback
  Future<void> refreshRates() async {
    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ratesMap = data['rates'];
        if (ratesMap != null && ratesMap['IDR'] != null) {
          final idrPerUsd = (ratesMap['IDR'] as num).toDouble();
          final sgdPerUsd = (ratesMap['SGD'] as num).toDouble();
          final eurPerUsd = (ratesMap['EUR'] as num).toDouble();

          _rates['USD'] = CurrencyRate(code: 'USD', name: 'US Dollar', rateToIdr: idrPerUsd, symbol: '\$');
          _rates['SGD'] = CurrencyRate(code: 'SGD', name: 'Singapore Dollar', rateToIdr: idrPerUsd / sgdPerUsd, symbol: 'S\$');
          _rates['EUR'] = CurrencyRate(code: 'EUR', name: 'Euro', rateToIdr: idrPerUsd / eurPerUsd, symbol: '€');
          lastUpdated = DateTime.now();
        }
      }
    } catch (e) {
      debugPrint('Using cached currency exchange rates: $e');
    }
  }
}
