/// Service untuk kalkulasi target nutrisi harian bayi (MPASI)
///
/// Data didasarkan pada:
/// - Standar Kesenjangan Energi MPASI dari WHO
/// - Pedoman IDAI (Ikatan Dokter Anak Indonesia)
/// - Angka Kecukupan Gizi (AKG) Indonesia 2019 sebagai fallback
///
/// Rumus kalori total menggunakan metode Holliday-Segar:
///   - Berat ≤ 10 kg : E = 100 × W
///   - 11–20 kg      : E = 1000 + 50 × (W − 10)
///
/// Porsi MPASI dari total kalori (standar WHO):
///   - 6–8 bulan   : 30%
///   - 9–11 bulan  : 50%
///   - 12–23 bulan : 70%
class BabyNutritionService {
  // ---------------------------------------------------------------------------
  // Data statis WHO / IDAI — digunakan sebagai fallback jika berat badan bayi
  // belum diperbarui oleh pengguna.
  // ---------------------------------------------------------------------------

  /// Target MPASI harian untuk bayi usia 6–8 bulan
  static const Map<String, double> _targets6to8 = {
    'calories': 200.0,   // kkal
    'protein': 7.5,      // gram
    'fat': 7.8,          // gram
    'carbs': 25.0,       // gram
  };

  /// Target MPASI harian untuk bayi usia 9–11 bulan
  static const Map<String, double> _targets9to11 = {
    'calories': 300.0,
    'protein': 11.25,
    'fat': 11.6,
    'carbs': 37.5,
  };

  /// Target MPASI harian untuk bayi usia 12–23 bulan
  static const Map<String, double> _targets12to23 = {
    'calories': 550.0,
    'protein': 20.6,
    'fat': 21.4,
    'carbs': 68.75,
  };

  // ---------------------------------------------------------------------------
  // Konstanta makronutrien
  // ---------------------------------------------------------------------------
  static const double _proteinRatio = 0.15;  // 15% dari E_mpasi
  static const double _fatRatio     = 0.35;  // 35% dari E_mpasi
  static const double _kcalPerProtein = 4.0;
  static const double _kcalPerFat     = 9.0;
  static const double _kcalPerCarbs   = 4.0;

  // Rasio porsi MPASI terhadap kebutuhan total
  static const double _mpasiFraction6to8  = 0.30;
  static const double _mpasiFraction9to11 = 0.50;
  static const double _mpasiFraction12to23 = 0.70;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Hitung usia bayi dalam bulan dari tanggal lahir.
  /// Mengembalikan null jika [birthDate] null.
  static int? getAgeInMonths(DateTime? birthDate) {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int months = (now.year - birthDate.year) * 12 +
        (now.month - birthDate.month);
    if (now.day < birthDate.day) months--;
    return months.clamp(0, 999);
  }

  /// Kembalikan target nutrisi harian MPASI berdasarkan usia dan berat badan.
  ///
  /// Jika [babyWeightKg] tersedia, gunakan rumus Holliday-Segar.
  /// Jika tidak, gunakan data statis WHO sesuai [ageInMonths].
  /// Jika usia di luar rentang 6–23 bulan, kembalikan null.
  static Map<String, double>? getTargets({
    required int? ageInMonths,
    double? babyWeightKg,
  }) {
    if (ageInMonths == null) return null;
    if (ageInMonths < 6 || ageInMonths > 23) return null;

    // Jika berat badan tersedia, hitung dinamis
    if (babyWeightKg != null && babyWeightKg > 0) {
      return _calculateDynamic(ageInMonths: ageInMonths, weightKg: babyWeightKg);
    }

    // Fallback: data statis WHO
    return _staticTargets(ageInMonths);
  }

  /// Kembalikan data statis WHO berdasarkan usia.
  static Map<String, double> _staticTargets(int ageInMonths) {
    if (ageInMonths <= 8)  return Map.from(_targets6to8);
    if (ageInMonths <= 11) return Map.from(_targets9to11);
    return Map.from(_targets12to23);
  }

  /// Hitung target dinamis menggunakan Holliday-Segar + rasio MPASI WHO.
  static Map<String, double> _calculateDynamic({
    required int ageInMonths,
    required double weightKg,
  }) {
    // 1. Total kebutuhan energi harian (Holliday-Segar)
    final double totalEnergy = weightKg <= 10
        ? 100 * weightKg
        : 1000 + 50 * (weightKg - 10);

    // 2. Porsi energi dari MPASI
    double fraction;
    if (ageInMonths <= 8)       fraction = _mpasiFraction6to8;
    else if (ageInMonths <= 11) fraction = _mpasiFraction9to11;
    else                        fraction = _mpasiFraction12to23;

    final double eMpasi = totalEnergy * fraction;

    // 3. Distribusi makronutrien
    final double proteinGram = (_proteinRatio * eMpasi) / _kcalPerProtein;
    final double fatGram     = (_fatRatio * eMpasi)     / _kcalPerFat;
    final double carbsGram   =
        (eMpasi - (proteinGram * _kcalPerProtein) - (fatGram * _kcalPerFat))
        / _kcalPerCarbs;

    return {
      'calories': eMpasi,
      'protein':  proteinGram,
      'fat':      fatGram,
      'carbs':    carbsGram.clamp(0, double.infinity),
    };
  }

  /// Label kategori usia untuk ditampilkan di UI.
  static String getAgeLabel(int? ageInMonths) {
    if (ageInMonths == null)   return '';
    if (ageInMonths < 6)       return 'Di bawah 6 bulan';
    if (ageInMonths <= 8)      return '6–8 bulan';
    if (ageInMonths <= 11)     return '9–11 bulan';
    if (ageInMonths <= 23)     return '12–23 bulan';
    return 'Di atas 23 bulan';
  }

  /// Teks sumber data untuk bottom sheet info.
  static const String infoText =
      'Perhitungan ini didasarkan pada standar Kesenjangan Energi MPASI dari '
      'WHO dan pedoman IDAI. Kebutuhan spesifik bayi dapat bervariasi.';
}