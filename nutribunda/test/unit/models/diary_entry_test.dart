import 'package:flutter_test/flutter_test.dart';
import 'package:nutribunda/data/models/diary_entry.dart';
import 'package:nutribunda/data/models/food_model.dart';

void main() {
  final sampleFoodJson = {
    'id': 'food-001',
    'name': 'Bubur Ayam',
    'category': 'mpasi',
    'calories_per_100g': 120.0,
    'protein_per_100g': 5.5,
    'carbs_per_100g': 18.0,
    'fat_per_100g': 3.0,
    'estimated_price_per_100g': null,
    'created_at': '2024-01-15T08:00:00.000Z',
  };

  final sampleEntryJson = {
    'id': 'entry-001',
    'user_id': 'user-abc',
    'profile_type': 'baby',
    'food_id': 'food-001',
    'custom_food_name': null,
    'serving_size': 150.0,
    'meal_time': 'breakfast',
    'calories': 180.0,
    'protein': 8.25,
    'carbs': 27.0,
    'fat': 4.5,
    'entry_date': '2024-01-15',
    'created_at': '2024-01-15T07:00:00.000Z',
    'updated_at': '2024-01-15T07:00:00.000Z',
    'food': sampleFoodJson,
  };

  group('DiaryEntry.fromJson', () {
    test('harus parse JSON dengan food yang terembed', () {
      final entry = DiaryEntry.fromJson(sampleEntryJson);

      expect(entry.id, equals('entry-001'));
      expect(entry.userId, equals('user-abc'));
      expect(entry.profileType, equals('baby'));
      expect(entry.servingSize, equals(150.0));
      expect(entry.mealTime, equals('breakfast'));
      expect(entry.food, isNotNull);
      expect(entry.food!.name, equals('Bubur Ayam'));
    });

    test('harus handle entry tanpa food (custom food)', () {
      final jsonCustom = Map<String, dynamic>.from(sampleEntryJson);
      jsonCustom['food_id'] = null;
      jsonCustom['food'] = null;
      jsonCustom['custom_food_name'] = 'Nasi Tim Homemade';

      final entry = DiaryEntry.fromJson(jsonCustom);

      expect(entry.food, isNull);
      expect(entry.customFoodName, equals('Nasi Tim Homemade'));
    });
  });

  group('DiaryEntry.displayName', () {
    test('harus mengembalikan nama food jika food tersedia', () {
      final entry = DiaryEntry.fromJson(sampleEntryJson);
      expect(entry.displayName, equals('Bubur Ayam'));
    });

    test('harus mengembalikan customFoodName jika tidak ada food', () {
      final jsonCustom = Map<String, dynamic>.from(sampleEntryJson);
      jsonCustom['food'] = null;
      jsonCustom['custom_food_name'] = 'Nasi Tim Homemade';

      final entry = DiaryEntry.fromJson(jsonCustom);
      expect(entry.displayName, equals('Nasi Tim Homemade'));
    });

    test('harus mengembalikan "Unknown Food" jika keduanya null', () {
      final jsonKosong = Map<String, dynamic>.from(sampleEntryJson);
      jsonKosong['food'] = null;
      jsonKosong['custom_food_name'] = null;

      final entry = DiaryEntry.fromJson(jsonKosong);
      expect(entry.displayName, equals('Unknown Food'));
    });
  });

  group('DiaryEntry.mealTimeDisplay (Bahasa Indonesia)', () {
    final mealTimes = {
      'breakfast': 'Makan Pagi',
      'lunch': 'Makan Siang',
      'dinner': 'Makan Malam',
      'snack': 'Makanan Selingan',
    };

    mealTimes.forEach((key, value) {
      test('mealTime "$key" harus tampil sebagai "$value"', () {
        final json = Map<String, dynamic>.from(sampleEntryJson);
        json['meal_time'] = key;

        final entry = DiaryEntry.fromJson(json);
        expect(entry.mealTimeDisplay, equals(value));
      });
    });

    test('mealTime tidak dikenal harus mengembalikan nilai aslinya', () {
      final json = Map<String, dynamic>.from(sampleEntryJson);
      json['meal_time'] = 'brunch';

      final entry = DiaryEntry.fromJson(json);
      expect(entry.mealTimeDisplay, equals('brunch'));
    });
  });

  group('DiaryEntry.profileTypeDisplay (Bahasa Indonesia)', () {
    test('"baby" harus tampil sebagai "Bayi"', () {
      final entry = DiaryEntry.fromJson(sampleEntryJson);
      expect(entry.profileTypeDisplay, equals('Bayi'));
    });

    test('"mother" harus tampil sebagai "Ibu"', () {
      final json = Map<String, dynamic>.from(sampleEntryJson);
      json['profile_type'] = 'mother';

      final entry = DiaryEntry.fromJson(json);
      expect(entry.profileTypeDisplay, equals('Ibu'));
    });
  });

  group('DiaryEntry.copyWith', () {
    test('harus membuat salinan dengan field yang diupdate', () {
      final entry = DiaryEntry.fromJson(sampleEntryJson);
      final updated = entry.copyWith(servingSize: 200.0, mealTime: 'lunch');

      expect(updated.servingSize, equals(200.0));
      expect(updated.mealTime, equals('lunch'));
      // Field lain tidak berubah
      expect(updated.id, equals(entry.id));
      expect(updated.userId, equals(entry.userId));
    });
  });
}