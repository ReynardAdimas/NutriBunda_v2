import 'package:flutter_test/flutter_test.dart';
import 'package:nutribunda/data/models/user_model.dart';

void main() {
  final sampleJson = {
    'id': 'user-abc123',
    'email': 'bunda@nutribunda.com',
    'full_name': 'Siti Rahayu',
    'weight': 58.5,
    'height': 162.0,
    'age': 28,
    'is_breastfeeding': true,
    'activity_level': 'lightly_active',
    'profile_image_url': null,
    'timezone': 'WIB',
    'created_at': '2024-01-01T00:00:00.000Z',
    'updated_at': '2024-01-10T00:00:00.000Z',
  };

  group('UserModel.fromJson', () {
    test('harus parse JSON dengan benar', () {
      final user = UserModel.fromJson(sampleJson);

      expect(user.id, equals('user-abc123'));
      expect(user.email, equals('bunda@nutribunda.com'));
      expect(user.fullName, equals('Siti Rahayu'));
      expect(user.weight, equals(58.5));
      expect(user.isBreastfeeding, isTrue);
      expect(user.activityLevel, equals('lightly_active'));
    });

    test('harus menggunakan nilai default jika field opsional null', () {
      final jsonMinimal = {
        'id': 'user-xyz',
        'email': 'test@test.com',
        'full_name': 'Test User',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(jsonMinimal);

      // Nilai default
      expect(user.isBreastfeeding, isFalse);
      expect(user.activityLevel, equals('sedentary'));
      expect(user.timezone, equals('WIB'));
      expect(user.weight, isNull);
      expect(user.height, isNull);
    });
  });

  group('UserModel.copyWith', () {
    test('harus update field tertentu tanpa mengubah yang lain', () {
      final user = UserModel.fromJson(sampleJson);
      final updated = user.copyWith(weight: 60.0, isBreastfeeding: false);

      expect(updated.weight, equals(60.0));
      expect(updated.isBreastfeeding, isFalse);
      // Field lain tetap sama
      expect(updated.id, equals(user.id));
      expect(updated.email, equals(user.email));
      expect(updated.fullName, equals(user.fullName));
    });
  });

  group('UserModel.toJson', () {
    test('harus menghasilkan JSON dengan semua field', () {
      final user = UserModel.fromJson(sampleJson);
      final json = user.toJson();

      expect(json['id'], equals('user-abc123'));
      expect(json['email'], equals('bunda@nutribunda.com'));
      expect(json['is_breastfeeding'], isTrue);
      expect(json['activity_level'], equals('lightly_active'));
    });
  });
}