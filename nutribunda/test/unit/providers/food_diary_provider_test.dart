// import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';
// import 'package:dio/dio.dart';
// import 'package:nutribunda/core/services/http_client_service.dart';
// import 'package:nutribunda/core/services/secure_storage_service.dart';
// import 'package:nutribunda/data/datasources/local/local_diary_datasource.dart';
// import 'package:nutribunda/data/datasources/local/local_food_datasource.dart';
// import 'package:nutribunda/presentation/providers/food_diary_provider.dart';

// // Jalankan: dart run build_runner build --delete-conflicting-outputs
// @GenerateMocks([
//   HttpClientService,
//   SecureStorageService,
//   LocalDiaryDataSource,
//   LocalFoodDataSource,
// ])
// import 'food_diary_provider_test.mocks.dart';

// void main() {
//   late MockHttpClientService mockHttpClient;
//   late MockSecureStorageService mockSecureStorage;
//   late MockLocalDiaryDataSource mockLocalDiary;
//   late MockLocalFoodDataSource mockLocalFood;
//   late FoodDiaryProvider provider;

//   // Data dummy diary entries
//   final dummyEntriesJson = [
//     {
//       'id': 'entry-001',
//       'user_id': 'user-abc',
//       'profile_type': 'baby',
//       'food_id': 'food-001',
//       'custom_food_name': null,
//       'serving_size': 150.0,
//       'meal_time': 'breakfast',
//       'calories': 180.0,
//       'protein': 8.25,
//       'carbs': 27.0,
//       'fat': 4.5,
//       'entry_date': '2024-01-15',
//       'created_at': '2024-01-15T07:00:00.000Z',
//       'updated_at': '2024-01-15T07:00:00.000Z',
//       'food': {
//         'id': 'food-001',
//         'name': 'Bubur Ayam',
//         'category': 'mpasi',
//         'calories_per_100g': 120.0,
//         'protein_per_100g': 5.5,
//         'carbs_per_100g': 18.0,
//         'fat_per_100g': 3.0,
//         'estimated_price_per_100g': null,
//         'created_at': '2024-01-01T00:00:00.000Z',
//       }
//     }
//   ];

//   setUp(() {
//     mockHttpClient = MockHttpClientService();
//     mockSecureStorage = MockSecureStorageService();
//     mockLocalDiary = MockLocalDiaryDataSource();
//     mockLocalFood = MockLocalFoodDataSource();

//     // Default stub: getUserId selalu return '1'
//     when(mockSecureStorage.getUserId()).thenAnswer((_) async => '1');

//     // Default stub: local diary kosong (tidak throw)
//     when(mockLocalDiary.getDiaryEntriesByDate(
//       userId: anyNamed('userId'),
//       profileType: anyNamed('profileType'),
//       date: anyNamed('date'),
//     )).thenAnswer((_) async => []);

//     when(mockLocalDiary.insertOrUpdateFromServer(any))
//         .thenAnswer((_) async => 1);

//     provider = FoodDiaryProvider(
//       httpClient: mockHttpClient,
//       localDiary: mockLocalDiary,
//       localFood: mockLocalFood,
//       secureStorage: mockSecureStorage,
//     );
//   });

//   group('FoodDiaryProvider - initial state', () {
//     test('state awal harus benar', () {
//       expect(provider.entries, isEmpty);
//       expect(provider.isLoading, isFalse);
//       expect(provider.errorMessage, isNull);
//       expect(provider.selectedProfile, equals('baby'));
//       expect(provider.isOffline, isFalse);
//     });
//   });

//   group('FoodDiaryProvider.setSelectedProfile', () {
//     test('harus mengubah profile dan memuat ulang entries', () async {
//       // Stub HTTP call agar tidak gagal
//       when(mockHttpClient.get(any,
//               queryParameters: anyNamed('queryParameters')))
//           .thenAnswer((_) async => Response(
//                 data: {'entries': [], 'nutrition_summary': {}},
//                 statusCode: 200,
//                 requestOptions: RequestOptions(path: ''),
//               ));

//       provider.setSelectedProfile('mother');

//       expect(provider.selectedProfile, equals('mother'));
//     });

//     test('harus mengabaikan profile yang tidak valid', () {
//       provider.setSelectedProfile('invalid_profile');

//       // Profile tidak berubah
//       expect(provider.selectedProfile, equals('baby'));
//       expect(provider.errorMessage, isNotNull);
//     });
//   });

//   group('FoodDiaryProvider.loadEntries', () {
//     test('harus mengelompokkan entries berdasarkan meal time saat online',
//         () async {
//       // Arrange — stub HTTP mengembalikan data dummy
//       when(mockHttpClient.get(any,
//               queryParameters: anyNamed('queryParameters')))
//           .thenAnswer((_) async => Response(
//                 data: {
//                   'entries': dummyEntriesJson,
//                   'nutrition_summary': {
//                     'calories': 180.0,
//                     'protein': 8.25,
//                     'carbs': 27.0,
//                     'fat': 4.5,
//                   }
//                 },
//                 statusCode: 200,
//                 requestOptions: RequestOptions(path: ''),
//               ));

//       // Act
//       await provider.loadEntries();

//       // Assert
//       final grouped = provider.entriesByMealTime;
//       expect(grouped['breakfast'], hasLength(1));
//       expect(grouped['lunch'], hasLength(0));
//       expect(grouped['dinner'], hasLength(0));
//       expect(grouped['snack'], hasLength(0));
//       expect(provider.isOffline, isFalse);
//     });

//     test('harus fallback ke SQLite saat offline (NetworkException)', () async {
//       // Arrange — HTTP throw NetworkException
//       when(mockHttpClient.get(any,
//               queryParameters: anyNamed('queryParameters')))
//           .thenThrow(const NetworkException('No internet'));

//       // Act
//       await provider.loadEntries();

//       // Assert — tidak error, ambil dari lokal (kosong karena mock return [])
//       expect(provider.isLoading, isFalse);
//       expect(provider.errorMessage, isNull);
//       expect(provider.isOffline, isTrue);
//       expect(provider.entries, isEmpty);

//       // Verifikasi bahwa local datasource dipanggil
//       verify(mockLocalDiary.getDiaryEntriesByDate(
//         userId: anyNamed('userId'),
//         profileType: anyNamed('profileType'),
//         date: anyNamed('date'),
//       )).called(1);
//     });

//     test('harus fallback ke SQLite saat DioException connection error',
//         () async {
//       // Arrange
//       when(mockHttpClient.get(any,
//               queryParameters: anyNamed('queryParameters')))
//           .thenThrow(DioException(
//         type: DioExceptionType.connectionError,
//         requestOptions: RequestOptions(path: ''),
//       ));

//       // Act
//       await provider.loadEntries();

//       // Assert
//       expect(provider.isLoading, isFalse);
//       expect(provider.isOffline, isTrue);
//     });

//     test('harus set errorMessage saat 401 Unauthorized', () async {
//       // Arrange
//       when(mockHttpClient.get(any,
//               queryParameters: anyNamed('queryParameters')))
//           .thenThrow(DioException(
//         type: DioExceptionType.badResponse,
//         response: Response(
//           statusCode: 401,
//           requestOptions: RequestOptions(path: ''),
//         ),
//         requestOptions: RequestOptions(path: ''),
//       ));

//       // Act
//       await provider.loadEntries();

//       // Assert
//       expect(provider.isLoading, isFalse);
//       expect(provider.errorMessage, contains('login'));
//     });
//   });

//   group('FoodDiaryProvider.addEntry — offline', () {
//     test('harus menyimpan ke SQLite lokal saat offline', () async {
//       // Arrange — HTTP throw connection error
//       when(mockHttpClient.post(any, data: anyNamed('data')))
//           .thenThrow(DioException(
//         type: DioExceptionType.connectionError,
//         requestOptions: RequestOptions(path: ''),
//       ));

//       when(mockLocalDiary.insertDiaryEntry(any)).thenAnswer((_) async => 42);

//       // Act
//       final result = await provider.addEntry(
//         profileType: 'baby',
//         customFoodName: 'Nasi Tim',
//         servingSize: 100,
//         mealTime: 'breakfast',
//         entryDate: DateTime.now(),
//         calories: 120,
//         protein: 4,
//         carbs: 20,
//         fat: 2,
//       );

//       // Assert
//       expect(result, isTrue);
//       expect(provider.isOffline, isTrue);
//       expect(provider.entries, hasLength(1));
//       expect(provider.entries.first.id, startsWith('local_'));

//       verify(mockLocalDiary.insertDiaryEntry(any)).called(1);
//     });

//     test('harus gagal jika profileType tidak valid', () async {
//       final result = await provider.addEntry(
//         profileType: 'invalid',
//         customFoodName: 'Test',
//         servingSize: 100,
//         mealTime: 'breakfast',
//         entryDate: DateTime.now(),
//         calories: 100,
//         protein: 5,
//         carbs: 15,
//         fat: 2,
//       );

//       expect(result, isFalse);
//       expect(provider.errorMessage, isNotNull);
//     });
//   });
// }