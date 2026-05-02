import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Model untuk informasi currency yang didukung
class SupportedCurrency {
  final String code;
  final String name;

  const SupportedCurrency({required this.code, required this.name});
}

/// Model hasil konversi harga
class PriceConversionResult {
  final double amountIDR;
  final String targetCurrency;
  final double convertedAmount;
  final double rate;
  final String date;

  const PriceConversionResult({
    required this.amountIDR,
    required this.targetCurrency,
    required this.convertedAmount,
    required this.rate,
    required this.date,
  });

  factory PriceConversionResult.fromJson(Map<String, dynamic> json) {
    return PriceConversionResult(
      amountIDR: (json['amount_idr'] as num).toDouble(),
      targetCurrency: json['target_currency'] as String,
      convertedAmount: (json['converted_amount'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      date: json['date'] as String,
    );
  }
}

/// Service untuk konversi mata uang
///
/// Menggunakan Frankfurter API (https://www.frankfurter.app) — GRATIS, tanpa API key.
/// Backend bertindak sebagai proxy untuk menghindari masalah CORS dari Flutter.
///
/// Cara kerja konversi IDR → target:
///   1. Ambil rate USD→IDR dan USD→target dari Frankfurter
///   2. Hitung: rate_IDR_to_target = rate_USD_to_target / rate_USD_to_IDR
///   3. Hasil = harga_IDR × rate_IDR_to_target
class CurrencyService {
  final String _baseUrl;

  CurrencyService({String? baseUrl})
      : _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  // ─── Supported currencies (cached in memory) ───────────────────────────────

  List<SupportedCurrency>? _cachedCurrencies;

  /// Ambil daftar mata uang yang didukung.
  /// Hasil di-cache agar tidak berulang kali hit network.
  Future<List<SupportedCurrency>> getSupportedCurrencies() async {
    if (_cachedCurrencies != null) return _cachedCurrencies!;

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl${ApiConstants.currencySupported}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final currencies = (data['currencies'] as Map<String, dynamic>)
            .entries
            .map((e) => SupportedCurrency(code: e.key, name: e.value as String))
            .toList();
        currencies.sort((a, b) => a.code.compareTo(b.code));
        _cachedCurrencies = currencies;
        return currencies;
      }
    } catch (_) {
      // Fallback ke daftar populer jika request gagal
    }
    return _popularCurrencies();
  }

  // ─── Exchange rate ──────────────────────────────────────────────────────────

  final Map<String, _CachedRate> _rateCache = {};

  /// Ambil nilai tukar dari IDR ke [targetCurrency].
  /// Rate di-cache selama 1 jam untuk mengurangi request ke server.
  Future<double?> getExchangeRate(String targetCurrency) async {
    if (targetCurrency == 'IDR') return 1.0;

    final cached = _rateCache[targetCurrency];
    if (cached != null && !cached.isExpired) return cached.rate;

    try {
      final uri = Uri.parse(
        '$_baseUrl${ApiConstants.currencyRate}?target=$targetCurrency',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rate = (data['rate'] as num).toDouble();
        _rateCache[targetCurrency] = _CachedRate(rate);
        return rate;
      }
    } catch (_) {}
    return null;
  }

  // ─── Format harga ───────────────────────────────────────────────────────────

  /// Format harga IDR ke mata uang yang dipilih user.
  /// Jika konversi gagal, tampilkan IDR sebagai fallback.
  Future<String> formatPrice(
    double priceIDR,
    String targetCurrency, {
    bool showCurrencyCode = true,
  }) async {
    if (targetCurrency == 'IDR') {
      return _formatIDR(priceIDR);
    }

    final rate = await getExchangeRate(targetCurrency);
    if (rate == null) return _formatIDR(priceIDR); // fallback

    final converted = priceIDR * rate;
    final symbol = _currencySymbol(targetCurrency);
    final formatted = _formatNumber(converted, targetCurrency);
    return showCurrencyCode
        ? '$symbol$formatted $targetCurrency'
        : '$symbol$formatted';
  }

  /// Format synchronous (gunakan rate yang sudah di-cache).
  /// Gunakan ini untuk rendering UI agar tidak async.
  String formatPriceSync(double priceIDR, String targetCurrency) {
    if (targetCurrency == 'IDR') return _formatIDR(priceIDR);

    final cached = _rateCache[targetCurrency];
    if (cached == null || cached.isExpired) return _formatIDR(priceIDR);

    final converted = priceIDR * cached.rate;
    final symbol = _currencySymbol(targetCurrency);
    final formatted = _formatNumber(converted, targetCurrency);
    return '$symbol$formatted $targetCurrency';
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatIDR(double amount) {
    final rounded = amount.round();
    final str = rounded.toString();
    final buffer = StringBuffer('Rp ');
    int counter = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      counter++;
    }
    return buffer.toString().split('').reversed.join();
  }

  String _formatNumber(double amount, String currency) {
    // Currencies that typically show 0 decimal places
    const noDecimal = {'JPY', 'KRW', 'IDR', 'VND', 'CLP', 'HUF'};
    if (noDecimal.contains(currency)) {
      return amount.round().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  String _currencySymbol(String code) {
    const symbols = {
      'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
      'CNY': '¥', 'SGD': 'S\$', 'MYR': 'RM', 'AUD': 'A\$',
      'CAD': 'CA\$', 'CHF': 'Fr', 'HKD': 'HK\$', 'KRW': '₩',
      'INR': '₹', 'THB': '฿', 'SAR': '﷼', 'AED': 'د.إ',
    };
    return symbols[code] ?? '$code ';
  }

  List<SupportedCurrency> _popularCurrencies() => [
        const SupportedCurrency(code: 'IDR', name: 'Indonesian Rupiah'),
        const SupportedCurrency(code: 'USD', name: 'US Dollar'),
        const SupportedCurrency(code: 'EUR', name: 'Euro'),
        const SupportedCurrency(code: 'GBP', name: 'British Pound'),
        const SupportedCurrency(code: 'SGD', name: 'Singapore Dollar'),
        const SupportedCurrency(code: 'MYR', name: 'Malaysian Ringgit'),
        const SupportedCurrency(code: 'AUD', name: 'Australian Dollar'),
        const SupportedCurrency(code: 'JPY', name: 'Japanese Yen'),
        const SupportedCurrency(code: 'CNY', name: 'Chinese Yuan'),
        const SupportedCurrency(code: 'SAR', name: 'Saudi Riyal'),
        const SupportedCurrency(code: 'AED', name: 'UAE Dirham'),
        const SupportedCurrency(code: 'KRW', name: 'South Korean Won'),
        const SupportedCurrency(code: 'THB', name: 'Thai Baht'),
        const SupportedCurrency(code: 'INR', name: 'Indian Rupee'),
      ];
}

/// Internal cache entry untuk exchange rate (expire 1 jam)
class _CachedRate {
  final double rate;
  final DateTime _cachedAt;

  _CachedRate(this.rate) : _cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(_cachedAt) > const Duration(hours: 1);
}