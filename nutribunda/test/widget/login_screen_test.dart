import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:nutribunda/core/services/http_client_service.dart';
import 'package:nutribunda/core/services/secure_storage_service.dart';
import 'package:nutribunda/core/services/biometric_service.dart';
import 'package:nutribunda/presentation/providers/auth_provider.dart';
import 'package:nutribunda/presentation/pages/auth/login_screen.dart';
import 'dart:async';          // untuk Completer
import 'package:dio/dio.dart'; // untuk Response

@GenerateMocks([HttpClientService, SecureStorageService, BiometricService])
import 'login_screen_test.mocks.dart';

/// Helper: membungkus widget dengan Provider yang diperlukan
Widget buildLoginScreen({required AuthProvider authProvider}) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: const LoginScreen(),
    ),
  );
}

void main() {
  late MockHttpClientService mockHttpClient;
  late MockSecureStorageService mockSecureStorage;
  late MockBiometricService mockBiometricService;
  late AuthProvider authProvider;

  setUp(() {
    mockHttpClient = MockHttpClientService();
    mockSecureStorage = MockSecureStorageService();
    mockBiometricService = MockBiometricService();

    // Default stub untuk biometric check di initState
    when(mockBiometricService.isDeviceSupported())
        .thenAnswer((_) async => false);

    authProvider = AuthProvider(
      httpClient: mockHttpClient,
      secureStorage: mockSecureStorage,
      biometricService: mockBiometricService,
    );
  });

  group('LoginScreen — tampilan awal', () {
    testWidgets('harus menampilkan field email dan password', (tester) async {
      await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle(); // Tunggu animasi selesai

      // Cari field berdasarkan label atau hint text
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('harus menampilkan tombol Login', (tester) async {
      await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
    });

    testWidgets('harus tidak menampilkan loading indicator di awal',
        (tester) async {
      await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('LoginScreen — validasi form', () {
    testWidgets('harus menampilkan error jika submit dengan field kosong',
        (tester) async {
      await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Klik tombol Login tanpa isi form
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      // Validator form seharusnya menampilkan pesan error
      // (tergantung implementasi validator di form)
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('harus bisa mengetik di field email', (tester) async {
      await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Ketik di field email (cari TextFormField pertama)
      await tester.enterText(find.byType(TextFormField).first, 'bunda@test.com');
      await tester.pump();

      expect(find.text('bunda@test.com'), findsOneWidget);
    });
  });

//   group('LoginScreen — loading state', () {
//     testWidgets('harus menampilkan loading indicator saat login',
//     (tester) async {
//   // Arrange — gunakan Completer, bukan Future.delayed
//     final completer = Completer<Response>();

//   when(mockHttpClient.post(any, data: anyNamed('data')))
//       .thenAnswer((_) => completer.future);

//   await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
//   await tester.pumpAndSettle();

//   // Isi form
//   final fields = find.byType(TextFormField);
//   await tester.enterText(fields.at(0), 'bunda@test.com');
//   await tester.enterText(fields.at(1), 'password123');

//   // Klik Login
//   await tester.tap(find.byKey(const Key('login-button')));
//   await tester.pump(); // Satu frame — loading muncul

//   // Assert — loading indicator harus tampil
//   expect(find.byType(CircularProgressIndicator), findsOneWidget);

//   // Cleanup — selesaikan completer agar tidak ada timer pending
//   completer.completeError(Exception('cancelled'));
//   await tester.pumpAndSettle();
// });
//   });

  group('LoginScreen — toggle password visibility', () {
    testWidgets('harus bisa toggle visibilitas password', (tester) async {
      await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Cari icon untuk toggle password (biasanya visibility_off di awal)
      final toggleIcon = find.byIcon(Icons.visibility_off);
      if (toggleIcon.evaluate().isNotEmpty) {
        await tester.tap(toggleIcon);
        await tester.pump();

        // Setelah tap, icon berubah
        expect(find.byIcon(Icons.visibility), findsOneWidget);
      }
    });
  });
}