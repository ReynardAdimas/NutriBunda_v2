import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import 'package:nutribunda/core/services/http_client_service.dart';
import 'package:nutribunda/presentation/providers/food_diary_provider.dart';

// Jalankan: dart run build_runner build --delete-conflicting-outputs
@GenerateMocks([HttpClientService])
import 'food_diary_provider_test.mocks.dart';

void main() {
  late MockHttpClientService mockHttpClient;
  late FoodDiaryProvider provider;

  // Data dummy diary entries
  final dummyEntriesJson = [
    {
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
      'food': {
        'id': 'food-001',
        'name': 'Bubur Ayam',
        'category': 'mpasi',
        'calories_per_100g': 120.0,
        'protein_per_100g': 5.5,
        'carbs_per_100g': 18.0,
        'fat_per_100g': 3.0,
        'estimated_price_per_100g': null,
        'created_at': '2024-01-01T00:00:00.000Z',
      }
    }
  ];

  setUp(() {
    mockHttpClient = MockHttpClientService();
    provider = FoodDiaryProvider(httpClient: mockHttpClient);
  });

  group('FoodDiaryProvider - initial state', () {
    test('state awal harus benar', () {
      expect(provider.entries, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.selectedProfile, equals('baby'));
    });
  });

  group('FoodDiaryProvider.setSelectedProfile', () {
    test('harus mengubah profile dan memuat ulang entries', () async {
      // Stub HTTP call agar tidak gagal
      when(mockHttpClient.get(any, queryParameters: anyNamed('queryParameters')))
          .thenAnswer((_) async => Response(
                data: {'entries': [], 'nutrition_summary': {}},
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      provider.setSelectedProfile('mother');

      expect(provider.selectedProfile, equals('mother'));
    });

    test('harus mengabaikan profile yang tidak valid', () {
      provider.setSelectedProfile('invalid_profile');

      // Profile tidak berubah
      expect(provider.selectedProfile, equals('baby'));
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('FoodDiaryProvider.entriesByMealTime', () {
    test('harus mengelompokkan entries berdasarkan meal time', () async {
      // Arrange — stub HTTP agar mengembalikan data dummy
      when(mockHttpClient.get(any, queryParameters: anyNamed('queryParameters')))
          .thenAnswer((_) async => Response(
                data: {
                  'entries': dummyEntriesJson,
                  'nutrition_summary': {
                    'calories': 180.0,
                    'protein': 8.25,
                    'carbs': 27.0,
                    'fat': 4.5,
                  }
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      // Act
      await provider.loadEntries();

      // Assert
      final grouped = provider.entriesByMealTime;
      expect(grouped['breakfast'], hasLength(1));
      expect(grouped['lunch'], hasLength(0));
      expect(grouped['dinner'], hasLength(0));
      expect(grouped['snack'], hasLength(0));
    });
  });

  group('FoodDiaryProvider.loadEntries — error handling', () {
    test('harus menyimpan errorMessage saat request gagal', () async {
      // Arrange — stub agar throw error
      when(mockHttpClient.get(any, queryParameters: anyNamed('queryParameters')))
          .thenThrow(Exception('Network error'));

      // Act
      await provider.loadEntries();

      // Assert
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });
}
