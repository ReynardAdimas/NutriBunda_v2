import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/currency_service.dart';

/// Key untuk menyimpan preferensi mata uang di SharedPreferences
const String _kSelectedCurrencyKey = 'selected_currency';

/// Provider untuk mengelola pengaturan mata uang
///
/// Menyimpan pilihan mata uang user secara persisten menggunakan SharedPreferences.
/// Menyediakan konversi harga real-time via CurrencyService.
class CurrencyProvider extends ChangeNotifier {
  final CurrencyService _currencyService;
  final SharedPreferences _prefs;

  String _selectedCurrency = 'IDR';
  List<SupportedCurrency> _supportedCurrencies = [];
  bool _isLoadingCurrencies = false;
  bool _isLoadingRate = false;
  double? _currentRate; // Rate dari IDR ke _selectedCurrency
  String? _rateDate;
  String? _errorMessage;

  CurrencyProvider({
    required CurrencyService currencyService,
    required SharedPreferences prefs,
  })  : _currencyService = currencyService,
        _prefs = prefs {
    _loadSavedCurrency();
  }

  // ─── Getters ────────────────────────────────────────────────────────────────

  String get selectedCurrency => _selectedCurrency;
  List<SupportedCurrency> get supportedCurrencies => _supportedCurrencies;
  bool get isLoadingCurrencies => _isLoadingCurrencies;
  bool get isLoadingRate => _isLoadingRate;
  double? get currentRate => _currentRate;
  String? get rateDate => _rateDate;
  String? get errorMessage => _errorMessage;

  /// Apakah mata uang yang dipilih bukan IDR (perlu konversi)
  bool get needsConversion => _selectedCurrency != 'IDR';

  // ─── Init ────────────────────────────────────────────────────────────────────

  void _loadSavedCurrency() {
    final saved = _prefs.getString(_kSelectedCurrencyKey);
    if (saved != null) {
      _selectedCurrency = saved;
      if (_selectedCurrency != 'IDR') {
        _fetchRate(_selectedCurrency);
      }
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  /// Muat daftar mata uang yang didukung dari server
  Future<void> loadSupportedCurrencies() async {
    if (_isLoadingCurrencies) return;
    _isLoadingCurrencies = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _supportedCurrencies =
          await _currencyService.getSupportedCurrencies();
    } catch (e) {
      _errorMessage = 'Gagal memuat daftar mata uang';
    } finally {
      _isLoadingCurrencies = false;
      notifyListeners();
    }
  }

  /// Ubah mata uang yang dipilih dan simpan ke preferences
  Future<void> setSelectedCurrency(String currencyCode) async {
    if (_selectedCurrency == currencyCode) return;

    _selectedCurrency = currencyCode;
    await _prefs.setString(_kSelectedCurrencyKey, currencyCode);

    if (currencyCode == 'IDR') {
      _currentRate = 1.0;
      _rateDate = null;
    } else {
      await _fetchRate(currencyCode);
    }

    notifyListeners();
  }

  /// Fetch rate terbaru untuk currency yang dipilih
  Future<void> _fetchRate(String currency) async {
    _isLoadingRate = true;
    notifyListeners();

    try {
      _currentRate = await _currencyService.getExchangeRate(currency);
      _errorMessage = _currentRate == null
          ? 'Tidak dapat memuat nilai tukar. Menampilkan harga dalam IDR.'
          : null;
    } catch (_) {
      _errorMessage = 'Tidak dapat memuat nilai tukar';
    } finally {
      _isLoadingRate = false;
      notifyListeners();
    }
  }

  /// Refresh rate dari server
  Future<void> refreshRate() async {
    if (_selectedCurrency != 'IDR') {
      await _fetchRate(_selectedCurrency);
    }
  }

  // ─── Format helpers ──────────────────────────────────────────────────────────

  /// Format harga IDR ke mata uang yang dipilih user.
  /// Gunakan ini di widget untuk render harga.
  String formatPrice(double priceIDR) {
    if (!needsConversion || _currentRate == null) {
      return _currencyService.formatPriceSync(priceIDR, 'IDR');
    }
    return _currencyService.formatPriceSync(priceIDR, _selectedCurrency);
  }

  /// Format harga untuk serving size tertentu (bukan per 100g)
  String formatPriceForServing(double priceIDRPer100g, double servingGrams) {
    final priceForServing = priceIDRPer100g * (servingGrams / 100);
    return formatPrice(priceForServing);
  }
}