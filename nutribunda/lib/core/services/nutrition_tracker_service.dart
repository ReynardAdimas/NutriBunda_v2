import '../../data/models/nutrition_summary.dart';
import 'baby_nutrition_service.dart';

/// Service untuk tracking dan kalkulasi nutrisi harian
/// Requirements: 4.3, 4.6, 13.2 - Nutrition calculation dan dashboard summary
class NutritionTrackerService {
  /// Target nutrisi harian untuk bayi (6-24 bulan)
  /// Berdasarkan rekomendasi WHO dan Kemenkes RI
  static const Map<String, double> babyTargets = {
    'calories': 1000.0, // kkal per hari
    'protein': 15.0, // gram per hari
    'carbs': 130.0, // gram per hari
    'fat': 35.0, // gram per hari
  };

  /// Target nutrisi harian untuk ibu menyusui
  /// Berdasarkan rekomendasi Kemenkes RI
  static const Map<String, double> motherTargets = {
    'calories': 2300.0, // kkal per hari (base + breastfeeding)
    'protein': 65.0, // gram per hari
    'carbs': 300.0, // gram per hari
    'fat': 75.0, // gram per hari
  };

  /// Get target nutrisi berdasarkan profile type
  /// Requirements: 4.6 - Display daily nutrition summary
  static Map<String, double> getTargets(String profileType) {
    if (profileType == 'baby') {
      return babyTargets;
    } else if (profileType == 'mother') {
      return motherTargets;
    }
    return babyTargets; // default
  }

  /// Calculate percentage of target achieved
  /// Requirements: 4.3 - Nutrition calculation
  static double calculatePercentage(double current, double target) {
    if (target <= 0) return 0.0;
    return (current / target * 100).clamp(0.0, 200.0); // Cap at 200%
  }

  /// Get color based on percentage
  /// Requirements: 13.2 - Visual indicators for daily targets
  /// Green (0-80%), Yellow (81-100%), Red (>100%)
  static NutritionColor getColorForPercentage(double percentage) {
    if (percentage <= 80.0) {
      return NutritionColor.green;
    } else if (percentage <= 100.0) {
      return NutritionColor.yellow;
    } else {
      return NutritionColor.red;
    }
  }

  /// Calculate nutrition progress for a profile.
  ///
  /// **Untuk profil ibu** (`profileType == 'mother'`):
  ///   - Jika [calorieOverride] diisi (dari `DietPlanProvider.targetCalories`),
  ///     nilai ini menggantikan target kalori statis 2300 kkal agar sinkron
  ///     dengan hasil kalkulasi BMR/TDEE di Diet Plan.
  ///
  /// **Untuk profil bayi** (`profileType == 'baby'`):
  ///   - Jika [babyAgeInMonths] dan/atau [babyWeightKg] tersedia, target
  ///     dihitung dinamis via [BabyNutritionService] (Holliday-Segar + WHO).
  ///   - Jika tidak tersedia atau usia di luar 6–23 bulan, fallback ke
  ///     [babyTargets] statis.
  ///
  /// Requirements: 4.3, 4.6 - Nutrition calculation and summary
  static NutritionProgress calculateProgress({
    required NutritionSummary summary,
    required String profileType,
    // Ibu: override kalori dari DietPlanProvider
    double? calorieOverride,
    // Bayi: data untuk kalkulasi dinamis
    int? babyAgeInMonths,
    double? babyWeightKg,
  }) {
    Map<String, double> targets;

    if (profileType == 'baby') {
      // Coba kalkulasi dinamis WHO/Holliday-Segar
      final dynamic = BabyNutritionService.getTargets(
        ageInMonths: babyAgeInMonths,
        babyWeightKg: babyWeightKg,
      );

      if (dynamic != null) {
        // Kalkulasi dinamis berhasil (usia dalam range 6–23 bln)
        targets = dynamic;
      } else {
        // FIX #4: Jika usia tidak tersedia atau di luar range, gunakan data
        // statis WHO dari BabyNutritionService (bukan babyTargets hardcode
        // 1000 kkal). Default ke kelompok usia 6–8 bulan sebagai fallback
        // paling konservatif.
        final fallbackAge = (babyAgeInMonths != null && babyAgeInMonths >= 6)
            ? babyAgeInMonths
            : 6; // default: kelompok 6–8 bulan
        targets = BabyNutritionService.getTargets(
              ageInMonths: fallbackAge.clamp(6, 23),
              babyWeightKg: null, // paksa static fallback WHO
            ) ??
            Map.from(babyTargets); // last-resort: nilai hardcode lama
      }
    } else {
      // Profil ibu — mulai dari data statis, lalu terapkan override kalori
      targets = Map<String, double>.from(motherTargets);
      if (calorieOverride != null && calorieOverride > 0) {
        targets['calories'] = calorieOverride;
      }
    }

    final caloriesPercentage = calculatePercentage(
      summary.calories,
      targets['calories']!,
    );
    final proteinPercentage = calculatePercentage(
      summary.protein,
      targets['protein']!,
    );
    final carbsPercentage = calculatePercentage(
      summary.carbs,
      targets['carbs']!,
    );
    final fatPercentage = calculatePercentage(
      summary.fat,
      targets['fat']!,
    );

    return NutritionProgress(
      summary: summary,
      targets: targets,
      caloriesPercentage: caloriesPercentage,
      proteinPercentage: proteinPercentage,
      carbsPercentage: carbsPercentage,
      fatPercentage: fatPercentage,
      caloriesColor: getColorForPercentage(caloriesPercentage),
      proteinColor: getColorForPercentage(proteinPercentage),
      carbsColor: getColorForPercentage(carbsPercentage),
      fatColor: getColorForPercentage(fatPercentage),
    );
  }

  /// Check if any nutrient exceeds target
  /// Requirements: 13.2 - Visual indicators
  static bool hasExceededTarget(NutritionProgress progress) {
    return progress.caloriesPercentage > 100.0 ||
        progress.proteinPercentage > 100.0 ||
        progress.carbsPercentage > 100.0 ||
        progress.fatPercentage > 100.0;
  }

  /// Get warning message if target exceeded
  /// Requirements: 13.2 - Visual indicators
  static String? getWarningMessage(NutritionProgress progress) {
    if (!hasExceededTarget(progress)) return null;

    final exceeded = <String>[];
    if (progress.caloriesPercentage > 100.0) exceeded.add('Kalori');
    if (progress.proteinPercentage > 100.0) exceeded.add('Protein');
    if (progress.carbsPercentage > 100.0) exceeded.add('Karbohidrat');
    if (progress.fatPercentage > 100.0) exceeded.add('Lemak');

    return 'Target ${exceeded.join(", ")} telah terlampaui';
  }
}

/// Enum untuk warna indikator nutrisi
enum NutritionColor {
  green,
  yellow,
  red,
}

/// Model untuk progress nutrisi
class NutritionProgress {
  final NutritionSummary summary;
  final Map<String, double> targets;
  final double caloriesPercentage;
  final double proteinPercentage;
  final double carbsPercentage;
  final double fatPercentage;
  final NutritionColor caloriesColor;
  final NutritionColor proteinColor;
  final NutritionColor carbsColor;
  final NutritionColor fatColor;

  const NutritionProgress({
    required this.summary,
    required this.targets,
    required this.caloriesPercentage,
    required this.proteinPercentage,
    required this.carbsPercentage,
    required this.fatPercentage,
    required this.caloriesColor,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
  });

  /// Get target for specific nutrient
  double getTarget(String nutrient) {
    return targets[nutrient] ?? 0.0;
  }

  /// Get current value for specific nutrient
  double getCurrent(String nutrient) {
    switch (nutrient) {
      case 'calories':
        return summary.calories;
      case 'protein':
        return summary.protein;
      case 'carbs':
        return summary.carbs;
      case 'fat':
        return summary.fat;
      default:
        return 0.0;
    }
  }

  /// Get percentage for specific nutrient
  double getPercentage(String nutrient) {
    switch (nutrient) {
      case 'calories':
        return caloriesPercentage;
      case 'protein':
        return proteinPercentage;
      case 'carbs':
        return carbsPercentage;
      case 'fat':
        return fatPercentage;
      default:
        return 0.0;
    }
  }

  /// Get color for specific nutrient
  NutritionColor getColor(String nutrient) {
    switch (nutrient) {
      case 'calories':
        return caloriesColor;
      case 'protein':
        return proteinColor;
      case 'carbs':
        return carbsColor;
      case 'fat':
        return fatColor;
      default:
        return NutritionColor.green;
    }
  }
}