import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core Services
import 'core/services/secure_storage_service.dart';
import 'core/services/http_client_service.dart';
import 'core/services/biometric_service.dart';
import 'core/services/location_service.dart';
import 'core/services/maps_launcher_service.dart';
import 'core/services/chat_service.dart';
import 'core/services/quiz_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pedometer_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/currency_service.dart';

// Local Data Sources  ← TAMBAHAN
import 'data/datasources/local/local_diary_datasource.dart';
import 'data/datasources/local/local_food_datasource.dart';

// Providers
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/profile_provider.dart';
import 'presentation/providers/food_diary_provider.dart';
import 'presentation/providers/recipe_provider.dart';
import 'presentation/providers/lbs_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/quiz_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/diet_plan_provider.dart';
import 'presentation/providers/currency_provider.dart';

/// Service Locator instance
/// Digunakan untuk dependency injection di seluruh aplikasi
final sl = GetIt.instance;

/// Initialize semua dependencies
/// Harus dipanggil di main() sebelum runApp()
Future<void> init() async {
  // ============================================================================
  // CORE - External Dependencies
  // ============================================================================

  // Secure Storage untuk JWT dan sensitive data
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    ),
  );

  // Shared Preferences untuk non-sensitive data
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // ============================================================================
  // CORE SERVICES
  // ============================================================================

  // Secure Storage Service - untuk mengelola JWT dan data terenkripsi
  // Requirements: 1.4, 1.6, 1.7
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(secureStorage: sl()),
  );

  // HTTP Client Service - untuk komunikasi dengan backend API
  // Requirements: 1.4, 1.6
  sl.registerLazySingleton<HttpClientService>(
    () => HttpClientService(secureStorage: sl()),
  );

  // Biometric Service - untuk autentikasi biometrik
  // Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
  sl.registerLazySingleton<BiometricService>(
    () => BiometricService(secureStorage: sl()),
  );

  // Location Service - untuk mendapatkan GPS coordinates
  // Requirements: 8.1, 8.2, 8.7
  sl.registerLazySingleton<LocationService>(
    () => LocationService(),
  );

  // Maps Launcher Service - untuk membuka Google Maps dengan deep link
  // Requirements: 8.3, 8.4, 8.5, 8.6
  sl.registerLazySingleton<MapsLauncherService>(
    () => MapsLauncherService(),
  );

  // Chat Service - untuk integrasi dengan Gemini API
  // Requirements: 9.1, 9.2, 9.3, 9.4
  sl.registerLazySingleton<ChatService>(
    () => ChatService(),
  );

  // Quiz Service - untuk quiz game functionality
  // Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7
  sl.registerLazySingleton<QuizService>(
    () => QuizService(
      httpClient: sl(),
      prefs: sl(),
    ),
  );

  // Notification Service - untuk local notifications dengan timezone support
  // Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(),
  );

  // Pedometer Service - untuk menghitung langkah kaki
  // Requirements: 5.6, 5.7
  sl.registerLazySingleton<PedometerService>(
    () => PedometerService(),
  );

  sl.registerLazySingleton<CurrencyService>(
    () => CurrencyService(),
  );

  // Analytics Service - untuk performance monitoring dan analytics
  // Task 19.1 - Performance monitoring and analytics setup
  sl.registerLazySingleton<AnalyticsService>(
    () => AnalyticsService(),
  );

  // Initialize analytics service
  await sl<AnalyticsService>().initialize();

  // HTTP Client (Dio) - raw instance untuk custom usage
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors untuk logging dan error handling
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    return dio;
  });

  // ============================================================================
  // LOCAL DATA SOURCES  ← TAMBAHAN
  // ============================================================================

  // Local Diary Data Source - SQLite CRUD untuk diary entries
  sl.registerLazySingleton<LocalDiaryDataSource>(
    () => LocalDiaryDataSource(),
  );

  // Local Food Data Source - SQLite CRUD untuk food database
  sl.registerLazySingleton<LocalFoodDataSource>(
    () => LocalFoodDataSource(),
  );

  // ============================================================================
  // PROVIDERS - State Management
  // ============================================================================

  // Auth Provider - Requirements: 1.1, 1.5, 1.7, 2.1, 2.2, 2.3, 2.4, 2.5
  sl.registerFactory(() => AuthProvider(
        httpClient: sl(),
        secureStorage: sl(),
        biometricService: sl(),
      ));

  // Profile Provider - Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
  sl.registerFactory(() => ProfileProvider(
        httpClient: sl(),
      ));

  // Food Diary Provider - Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
  // Offline-first: baca SQLite lokal, sync ke server saat online
  sl.registerFactory(() => FoodDiaryProvider(
        httpClient: sl(),
        localDiary: sl(),    // ← LocalDiaryDataSource
        localFood: sl(),     // ← LocalFoodDataSource
        secureStorage: sl(), // ← untuk ambil userId
      ));

  // Recipe Provider - Requirements: 6.3, 6.4, 6.5, 7.1, 7.2, 7.3
  sl.registerFactory(() => RecipeProvider(
        httpClient: sl(),
      ));

  // LBS Provider - Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7
  sl.registerFactory(() => LBSProvider(
        locationService: sl(),
        mapsLauncher: sl(),
      ));

  // Chat Provider - Requirements: 9.1, 9.2, 9.5, 9.6
  sl.registerLazySingleton(() => ChatProvider(
        chatService: sl(),
      ));

  // Currency Provider - mengelola pilihan mata uang user secara persisten
  sl.registerLazySingleton<CurrencyProvider>(
    () => CurrencyProvider(
      currencyService: sl(),
      prefs: sl(),
    ),
  );

  // Quiz Provider - Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7
  sl.registerFactory(() => QuizProvider(
        quizService: sl(),
      ));

  // Notification Provider - Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
  sl.registerFactory(() => NotificationProvider(
        notificationService: sl(),
        prefs: sl(),
      ));

  // Diet Plan Provider - Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8
  sl.registerFactory(() => DietPlanProvider());

  // ============================================================================
  // USE CASES - Business Logic
  // ============================================================================

  // ============================================================================
  // REPOSITORIES - Data Layer
  // ============================================================================

  // ============================================================================
  // DATA SOURCES - Remote & Local
  // ============================================================================
}

/// Reset semua dependencies (untuk testing)
Future<void> reset() async {
  await sl.reset();
}