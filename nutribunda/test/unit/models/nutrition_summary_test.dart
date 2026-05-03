import 'package:flutter_test/flutter_test.dart';
import 'package:nutribunda/data/models/nutrition_summary.dart';

void main() {
  group('NutritionSummary constructor', () {
    test('default constructor harus memberi nilai nol untuk semua field', () {
      const summary = NutritionSummary();

      expect(summary.calories, equals(0.0));
      expect(summary.protein, equals(0.0));
      expect(summary.carbs, equals(0.0));
      expect(summary.fat, equals(0.0));
    });
  });

  group('NutritionSummary.fromJson', () {
    test('harus parse JSON dengan benar', () {
      final json = {
        'calories': 350.5,
        'protein': 12.0,
        'carbs': 55.0,
        'fat': 8.0,
      };
      final summary = NutritionSummary.fromJson(json);

      expect(summary.calories, equals(350.5));
      expect(summary.protein, equals(12.0));
    });

    test('harus default ke 0 jika field null', () {
      final summary = NutritionSummary.fromJson({});

      expect(summary.calories, equals(0.0));
    });
  });

  group('NutritionSummary.add', () {
    test('harus menambahkan nilai dengan benar', () {
      const summary = NutritionSummary(
        calories: 100.0,
        protein: 10.0,
        carbs: 15.0,
        fat: 5.0,
      );

      final result = summary.add(50.0, 5.0, 8.0, 2.0);

      expect(result.calories, closeTo(150.0, 0.001));
      expect(result.protein, closeTo(15.0, 0.001));
      expect(result.carbs, closeTo(23.0, 0.001));
      expect(result.fat, closeTo(7.0, 0.001));
    });

    test('objek original tidak boleh berubah (immutability)', () {
      const summary = NutritionSummary(calories: 100.0);
      summary.add(50.0, 0, 0, 0);

      // Memastikan NutritionSummary bersifat immutable
      expect(summary.calories, equals(100.0));
    });
  });

  group('NutritionSummary.remove', () {
    test('harus mengurangi nilai dengan benar', () {
      const summary = NutritionSummary(
        calories: 200.0,
        protein: 20.0,
        carbs: 30.0,
        fat: 10.0,
      );

      final result = summary.remove(50.0, 5.0, 8.0, 2.0);

      expect(result.calories, closeTo(150.0, 0.001));
      expect(result.protein, closeTo(15.0, 0.001));
    });

    test('hasil tidak boleh negatif (clamp ke 0)', () {
      const summary = NutritionSummary(calories: 50.0, protein: 5.0);

      // Mengurangi lebih besar dari nilai yang ada
      final result = summary.remove(100.0, 10.0, 0, 0);

      expect(result.calories, equals(0.0));
      expect(result.protein, equals(0.0));
    });
  });

  group('NutritionSummary.toString', () {
    test('harus menampilkan format yang benar', () {
      const summary = NutritionSummary(
        calories: 350.5,
        protein: 12.3,
        carbs: 45.6,
        fat: 8.9,
      );

      final str = summary.toString();

      expect(str, contains('calories: 350.5'));
      expect(str, contains('protein: 12.3g'));
    });
  });

  group('NutritionSummary equality', () {
    test('dua summary dengan nilai sama harus equal', () {
      const s1 = NutritionSummary(calories: 100.0, protein: 10.0);
      const s2 = NutritionSummary(calories: 100.0, protein: 10.0);

      expect(s1, equals(s2));
    });

    test('summary dengan nilai berbeda tidak boleh equal', () {
      const s1 = NutritionSummary(calories: 100.0);
      const s2 = NutritionSummary(calories: 200.0);

      expect(s1, isNot(equals(s2)));
    });
  });
}