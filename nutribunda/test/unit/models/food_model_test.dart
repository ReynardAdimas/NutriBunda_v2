import 'package:flutter_test/flutter_test.dart';
import 'package:nutribunda/data/models/food_model.dart';

void main() {
  // Data sampel yang dipakai ulang di semua test
  final sampleJson = {
    'id': 'food-001',
    'name': 'Bubur Ayam',
    'category': 'mpasi',
    'calories_per_100g': 120.0,
    'protein_per_100g': 5.5,
    'carbs_per_100g': 18.0,
    'fat_per_100g': 3.0,
    'estimated_price_per_100g': 2500.0,
    'created_at': '2024-01-15T08:00:00.000Z',
  };

  group('FoodModel.fromJson', () {
    test('harus berhasil parse JSON yang valid', () {
      final food = FoodModel.fromJson(sampleJson);

      expect(food.id, equals('food-001'));
      expect(food.name, equals('Bubur Ayam'));
      expect(food.category, equals('mpasi'));
      expect(food.caloriesPer100g, equals(120.0));
      expect(food.proteinPer100g, equals(5.5));
      expect(food.carbsPer100g, equals(18.0));
      expect(food.fatPer100g, equals(3.0));
      expect(food.estimatedPricePer100g, equals(2500.0));
    });

    test('harus handle estimatedPricePer100g yang null', () {
      final jsonTanpaHarga = Map<String, dynamic>.from(sampleJson);
      jsonTanpaHarga['estimated_price_per_100g'] = null;

      final food = FoodModel.fromJson(jsonTanpaHarga);

      expect(food.estimatedPricePer100g, isNull);
    });

    test('harus parse createdAt sebagai DateTime yang benar', () {
      final food = FoodModel.fromJson(sampleJson);

      expect(food.createdAt, isA<DateTime>());
      expect(food.createdAt.year, equals(2024));
      expect(food.createdAt.month, equals(1));
    });

    test('harus throw jika field wajib tidak ada', () {
      final jsonRusak = {'id': 'food-001'};
      expect(() => FoodModel.fromJson(jsonRusak), throwsA(anything));
  });
  });

  group('FoodModel.toJson', () {
    test('harus menghasilkan JSON dengan semua field yang benar', () {
      final food = FoodModel.fromJson(sampleJson);
      final json = food.toJson();

      expect(json['id'], equals('food-001'));
      expect(json['name'], equals('Bubur Ayam'));
      expect(json['category'], equals('mpasi'));
      expect(json['calories_per_100g'], equals(120.0));
    });
  });

  group('FoodModel.calculateNutrition', () {
    late FoodModel food;

    setUp(() {
      food = FoodModel.fromJson(sampleJson);
    });

    test('harus menghitung nutrisi dengan benar untuk 100g', () {
      final nutrition = food.calculateNutrition(100.0);

      // Untuk 100g, nilai sama dengan per100g
      expect(nutrition.calories, closeTo(120.0, 0.001));
      expect(nutrition.protein, closeTo(5.5, 0.001));
      expect(nutrition.carbs, closeTo(18.0, 0.001));
      expect(nutrition.fat, closeTo(3.0, 0.001));
    });

    test('harus menghitung nutrisi dengan benar untuk 50g (setengah porsi)', () {
      final nutrition = food.calculateNutrition(50.0);

      expect(nutrition.calories, closeTo(60.0, 0.001));
      expect(nutrition.protein, closeTo(2.75, 0.001));
      expect(nutrition.carbs, closeTo(9.0, 0.001));
      expect(nutrition.fat, closeTo(1.5, 0.001));
    });

    test('harus menghitung nutrisi dengan benar untuk 200g (dua kali porsi)', () {
      final nutrition = food.calculateNutrition(200.0);

      expect(nutrition.calories, closeTo(240.0, 0.001));
    });

    test('harus mengembalikan nol untuk porsi 0g', () {
      final nutrition = food.calculateNutrition(0.0);

      expect(nutrition.calories, equals(0.0));
      expect(nutrition.protein, equals(0.0));
    });
  });

  group('FoodModel equality (Equatable)', () {
    test('dua FoodModel dengan data sama harus equal', () {
      final food1 = FoodModel.fromJson(sampleJson);
      final food2 = FoodModel.fromJson(sampleJson);

      expect(food1, equals(food2));
    });

    test('dua FoodModel dengan id berbeda tidak boleh equal', () {
      final json2 = Map<String, dynamic>.from(sampleJson);
      json2['id'] = 'food-999';

      final food1 = FoodModel.fromJson(sampleJson);
      final food2 = FoodModel.fromJson(json2);

      expect(food1, isNot(equals(food2)));
    });
  });
}