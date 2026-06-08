# 🧪 Panduan Testing NutriBunda
**Panduan Lengkap untuk Pemula** | Versi 2.0

---

## 📋 Daftar Isi

1. [Pengantar Testing](#1-pengantar-testing)
2. [Gambaran Umum Project NutriBunda](#2-gambaran-umum-project-nutribunda)
3. [Persiapan Lingkungan Testing](#3-persiapan-lingkungan-testing)
4. [Backend Testing (Go)](#4-backend-testing-go)
   - [Unit Testing](#41-unit-testing-backend)
   - [API Testing](#42-api-testing)
5. [Frontend Testing (Flutter)](#5-frontend-testing-flutter)
   - [Unit Testing](#51-unit-testing-flutter)
   - [Widget Testing](#52-widget-testing)
6. [Menjalankan Semua Test](#6-menjalankan-semua-test)
7. [Memahami Hasil Test](#7-memahami-hasil-test)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Pengantar Testing

### Apa itu Testing?

Testing adalah proses memeriksa apakah kode program bekerja sesuai dengan yang diharapkan. Bayangkan seperti mencicipi masakan sebelum dihidangkan — kita ingin memastikan hasilnya sudah benar sebelum disajikan ke pengguna.

### Mengapa Testing Penting?

- **Mencegah bug** masuk ke production
- **Memudahkan perubahan** kode di masa depan
- **Dokumentasi hidup** — test menjelaskan bagaimana kode seharusnya bekerja
- **Meningkatkan kepercayaan diri** saat melakukan deploy

### Jenis-Jenis Testing yang Digunakan

| Jenis | Target | Contoh |
|-------|--------|--------|
| **Unit Testing** | Fungsi/Method tunggal | Apakah fungsi kalkulasi kalori benar? |
| **API Testing** | Endpoint HTTP | Apakah endpoint login mengembalikan token? |
| **Widget Testing** | Komponen UI Flutter | Apakah tombol Login tampil dengan benar? |

---

## 2. Gambaran Umum Project NutriBunda

NutriBunda adalah aplikasi pemantau gizi MPASI dan diet pemulihan ibu pasca-melahirkan. Project ini terdiri dari:

```
NutriBunda_v2-main/
├── backend/          ← Server API (Go + Gin Framework)
│   ├── internal/
│   │   ├── auth/     ← Autentikasi (Register, Login, JWT)
│   │   ├── diary/    ← Catatan makan harian
│   │   ├── food/     ← Database makanan
│   │   ├── recipe/   ← Resep
│   │   ├── user/     ← Profil pengguna
│   │   ├── quiz/     ← Kuis gizi
│   │   └── steps/    ← Perhitungan langkah
│   └── cmd/api/      ← Entry point server
└── nutribunda/       ← Aplikasi Flutter (Mobile)
    ├── lib/
    │   ├── data/     ← Models & Data Sources
    │   └── presentation/ ← UI & Providers
    └── test/
        ├── unit/     ← Unit tests
        └── widget/   ← Widget tests
```

---

## 3. Persiapan Lingkungan Testing

### 3.1 Kebutuhan Backend (Go)

**Instalasi Go:**
```bash
# Verifikasi instalasi
go version
# Output yang diharapkan: go version go1.21.x ...
```

**Masuk ke folder backend:**
```bash
cd NutriBunda_v2-main/backend
```

**Install dependensi:**
```bash
go mod download
```

**Verifikasi dependensi tersedia:**
```bash
go mod tidy
```

### 3.2 Kebutuhan Frontend (Flutter)

**Verifikasi instalasi Flutter:**
```bash
flutter --version
# Output yang diharapkan: Flutter 3.x.x
```

**Masuk ke folder frontend:**
```bash
cd NutriBunda_v2-main/nutribunda
```

**Install dependensi Flutter:**
```bash
flutter pub get
```

**Generate mock files (wajib untuk unit test):**
```bash
dart run build_runner build --delete-conflicting-outputs
```

> 💡 **Apa itu Mock?** Mock adalah objek "pura-pura" yang menggantikan dependensi nyata (seperti koneksi internet atau database) agar test bisa berjalan tanpa infrastruktur nyata.

---

## 4. Backend Testing (Go)

### 4.1 Unit Testing Backend

Unit testing di backend menguji logika bisnis secara terisolasi, tanpa membutuhkan database nyata. Project ini menggunakan **SQLite in-memory** untuk mensimulasikan database.

#### 📁 Lokasi File Test

```
backend/internal/
├── auth/
│   ├── service_test.go           ← Test utama autentikasi
│   └── service_property_test.go  ← Property-based tests
├── diary/
│   ├── service_test.go           ← Test logika diary
│   └── sync_test.go              ← Test sinkronisasi data
├── food/
│   └── service_test.go           ← Test pencarian makanan
├── recipe/
│   └── service_test.go           ← Test resep
└── user/
    └── service_test.go           ← Test profil pengguna
```

---

#### 🔐 Test Auth Service

File: `backend/internal/auth/service_test.go`

**Test Case yang Tersedia:**

##### Test 1: Registrasi Pengguna Baru

```go
// Menguji bahwa registrasi berhasil untuk data yang valid
func TestRegister(t *testing.T) {
    // ...

    t.Run("successful registration", func(t *testing.T) {
        req := &RegisterRequest{
            Email:    "test@example.com",
            Password: "password123",
            FullName: "Test User",
        }

        response, err := service.Register(req)
        
        // Tidak boleh ada error
        require.NoError(t, err)
        // Response tidak boleh nil
        assert.NotNil(t, response)
        // Token JWT harus ada
        assert.NotEmpty(t, response.Token)
        // Password harus di-hash (tidak sama dengan input)
        assert.NotEqual(t, req.Password, response.User.PasswordHash)
    })

    t.Run("duplicate email", func(t *testing.T) {
        // Email yang sama tidak boleh bisa daftar dua kali
        _, err = service.Register(req)
        assert.ErrorIs(t, err, ErrEmailAlreadyExists)
    })
}
```

**Cara menjalankan:**
```bash
cd backend
go test ./internal/auth/ -v -run TestRegister
```

**Output yang diharapkan:**
```
=== RUN   TestRegister
=== RUN   TestRegister/successful_registration
--- PASS: TestRegister/successful_registration (0.12s)
=== RUN   TestRegister/duplicate_email
--- PASS: TestRegister/duplicate_email (0.11s)
--- PASS: TestRegister (0.23s)
```

---

##### Test 2: Login Pengguna

```go
func TestLogin(t *testing.T) {
    // ...
    
    t.Run("successful login", func(t *testing.T) {
        // Login dengan kredensial benar harus berhasil
        loginReq := &LoginRequest{
            Email:    "login@example.com",
            Password: "password123",
        }
        response, err := service.Login(loginReq)
        
        require.NoError(t, err)
        assert.NotEmpty(t, response.Token)
    })

    t.Run("invalid email", func(t *testing.T) {
        // Email yang tidak terdaftar harus ditolak
        _, err := service.Login(&LoginRequest{
            Email: "nonexistent@example.com",
            Password: "password123",
        })
        assert.ErrorIs(t, err, ErrInvalidCredentials)
    })

    t.Run("invalid password", func(t *testing.T) {
        // Password yang salah harus ditolak
        _, err := service.Login(&LoginRequest{
            Email: "login@example.com",
            Password: "wrongpassword",
        })
        assert.ErrorIs(t, err, ErrInvalidCredentials)
    })
}
```

**Cara menjalankan:**
```bash
go test ./internal/auth/ -v -run TestLogin
```

---

##### Test 3: Validasi & Expire Token JWT

```go
func TestValidateToken(t *testing.T) {
    
    t.Run("valid token", func(t *testing.T) {
        // Token yang baru dibuat harus valid
        token, _ := service.generateToken(user)
        claims, err := service.ValidateToken(token)
        
        require.NoError(t, err)
        assert.Equal(t, user.ID, claims.UserID)
    })

    t.Run("expired token", func(t *testing.T) {
        // Token yang sudah expired harus ditolak
        shortService, _ := NewService(db, "secret", "1ns")
        token, _ := shortService.generateToken(user)
        time.Sleep(10 * time.Millisecond)
        
        _, err := shortService.ValidateToken(token)
        assert.Error(t, err) // Harus error
    })
}
```

**Cara menjalankan:**
```bash
go test ./internal/auth/ -v -run TestValidateToken
```

---

#### 🍽️ Test Food Service

File: `backend/internal/food/service_test.go`

> ⚠️ **Catatan:** Test food service membutuhkan koneksi PostgreSQL. Sesuaikan DSN di file test jika perlu.

**Test Case yang Tersedia:**

```go
func TestSearchFoods(t *testing.T) {
    
    t.Run("search all foods", func(t *testing.T) {
        // Tanpa filter: kembalikan semua makanan
        result, err := service.SearchFoods(&SearchRequest{Limit: 10})
        assert.NoError(t, err)
        assert.Equal(t, int64(5), result.Total)
    })

    t.Run("search by name", func(t *testing.T) {
        // Cari berdasarkan nama
        result, err := service.SearchFoods(&SearchRequest{Query: "bubur"})
        assert.NoError(t, err)
        assert.GreaterOrEqual(t, result.Total, int64(1))
    })

    t.Run("filter by category mpasi", func(t *testing.T) {
        // Filter berdasarkan kategori
        result, err := service.SearchFoods(&SearchRequest{Category: "mpasi"})
        assert.NoError(t, err)
        // Semua hasil harus kategori mpasi
        for _, food := range result.Foods {
            assert.Equal(t, "mpasi", food.Category)
        }
    })
}
```

**Cara menjalankan (dengan database):**
```bash
go test ./internal/food/ -v
```

---

#### 📖 Test Recipe Service

File: `backend/internal/recipe/service_test.go`

```go
func TestGetRecipes(t *testing.T) {
    
    t.Run("get all recipes", func(t *testing.T) {
        // Harus mengembalikan semua resep
        recipes, err := service.GetRecipes(nil)
        assert.NoError(t, err)
        assert.NotEmpty(t, recipes)
    })

    t.Run("filter by category mpasi", func(t *testing.T) {
        // Filter resep MPASI
        category := "mpasi"
        recipes, err := service.GetRecipes(&category)
        assert.NoError(t, err)
        for _, recipe := range recipes {
            assert.Equal(t, "mpasi", recipe.Category)
        }
    })
}

func TestToggleFavorite(t *testing.T) {
    
    t.Run("add to favorites", func(t *testing.T) {
        // Tambah ke favorit
        isFavorite, err := service.ToggleFavorite(userID, recipeID)
        assert.NoError(t, err)
        assert.True(t, isFavorite) // Sekarang jadi favorit
    })

    t.Run("remove from favorites", func(t *testing.T) {
        // Toggle lagi → hapus dari favorit
        isFavorite, err := service.ToggleFavorite(userID, recipeID)
        assert.NoError(t, err)
        assert.False(t, isFavorite) // Tidak lagi jadi favorit
    })
}
```

**Cara menjalankan:**
```bash
go test ./internal/recipe/ -v
```

---

#### 👤 Test User Service

File: `backend/internal/user/service_test.go`

```go
func TestUpdateProfile(t *testing.T) {
    
    t.Run("update valid weight", func(t *testing.T) {
        weight := 65.0
        req := &UpdateProfileRequest{Weight: &weight}
        
        updated, err := service.UpdateProfile(userID, req)
        assert.NoError(t, err)
        assert.Equal(t, weight, *updated.Weight)
    })

    t.Run("reject invalid weight (too low)", func(t *testing.T) {
        weight := 20.0 // Di bawah minimum 30 kg
        req := &UpdateProfileRequest{Weight: &weight}
        
        _, err := service.UpdateProfile(userID, req)
        assert.ErrorIs(t, err, ErrInvalidWeight)
    })

    t.Run("reject invalid height", func(t *testing.T) {
        height := 50.0 // Di bawah minimum 100 cm
        req := &UpdateProfileRequest{Height: &height}
        
        _, err := service.UpdateProfile(userID, req)
        assert.ErrorIs(t, err, ErrInvalidHeight)
    })
}
```

**Cara menjalankan:**
```bash
go test ./internal/user/ -v
```

---

#### 🏃 Menjalankan Semua Unit Test Backend Sekaligus

```bash
cd backend

# Jalankan semua test
go test ./...

# Dengan output verbose (detail setiap test)
go test ./... -v

# Dengan laporan coverage
go test ./... -cover

# Simpan laporan coverage ke file
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
# Buka coverage.html di browser untuk melihat visual coverage
```

---

### 4.2 API Testing

API Testing menguji endpoint HTTP secara langsung, memastikan server merespons dengan benar.

#### Cara 1: Menggunakan File `integration_test.go` (Otomatis)

File: `backend/internal/auth/integration_test.go`

Integration test ini menjalankan server nyata dan melakukan HTTP request. Membutuhkan database yang berjalan.

```bash
# Pastikan database PostgreSQL berjalan
# Sesuaikan .env dengan kredensial database Anda
cp .env.example .env

# Jalankan integration tests
go test ./internal/auth/ -v -run TestIntegration
```

#### Cara 2: Menggunakan curl (Manual)

Pastikan server berjalan terlebih dahulu:
```bash
go run cmd/api/main.go
# Server berjalan di http://localhost:8080
```

**Test Health Check:**
```bash
curl -X GET http://localhost:8080/api/health

# Respons yang diharapkan:
# {"status":"ok","message":"NutriBunda API is running"}
```

**Test Register:**
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bunda@test.com",
    "password": "password123",
    "full_name": "Bunda Sehat"
  }'

# Respons yang diharapkan (201 Created):
# {
#   "token": "eyJhbGciOiJIUzI1NiIs...",
#   "user": {
#     "id": "uuid-...",
#     "email": "bunda@test.com",
#     "full_name": "Bunda Sehat"
#   }
# }
```

**Test Login:**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bunda@test.com",
    "password": "password123"
  }'

# Simpan token dari response untuk digunakan di endpoint berikutnya
TOKEN="<token dari response di atas>"
```

**Test Get Profile (membutuhkan token):**
```bash
curl -X GET http://localhost:8080/api/user/profile \
  -H "Authorization: Bearer $TOKEN"

# Respons yang diharapkan (200 OK):
# {
#   "id": "...",
#   "email": "bunda@test.com",
#   "full_name": "Bunda Sehat",
#   ...
# }
```

**Test Update Profile:**
```bash
curl -X PUT http://localhost:8080/api/user/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "weight": 58.5,
    "height": 162.0,
    "age": 28,
    "is_breastfeeding": true,
    "activity_level": "moderate"
  }'
```

**Test Search Food:**
```bash
curl -X GET "http://localhost:8080/api/food?search=bubur&category=mpasi&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

**Test Get Diary Entries:**
```bash
curl -X GET "http://localhost:8080/api/diary?profile=baby&date=2024-01-15" \
  -H "Authorization: Bearer $TOKEN"
```

**Test Create Diary Entry:**
```bash
curl -X POST http://localhost:8080/api/diary \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "profile_type": "baby",
    "food_id": null,
    "custom_food_name": "Bubur Tim Wortel",
    "serving_size": 150,
    "meal_time": "breakfast",
    "entry_date": "2024-01-15",
    "calories": 120,
    "protein": 3.5,
    "carbs": 22,
    "fat": 2
  }'
```

**Test Register dengan Email Duplikat (harus gagal):**
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bunda@test.com",
    "password": "password456",
    "full_name": "Bunda Lain"
  }'

# Respons yang diharapkan (409 Conflict):
# {"error":"Email already exists"}
```

**Test Login dengan Password Salah:**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bunda@test.com",
    "password": "salah123"
  }'

# Respons yang diharapkan (401 Unauthorized):
# {"error":"Invalid email or password"}
```

**Test Akses Tanpa Token:**
```bash
curl -X GET http://localhost:8080/api/user/profile
# Respons yang diharapkan (401 Unauthorized):
# {"error":"Authorization header required"}
```

#### Cara 3: Menggunakan Postman

1. Download dan install [Postman](https://www.postman.com/downloads/)
2. Import collection dengan membuat requests berikut:

**Setup Environment di Postman:**
- Buat Environment baru bernama "NutriBunda Local"
- Tambahkan variable: `base_url` = `http://localhost:8080`
- Tambahkan variable: `token` = (akan diisi otomatis setelah login)

**Collection Tests:**
```
NutriBunda API
├── 🔐 Auth
│   ├── POST Register
│   ├── POST Login
│   └── POST Logout
├── 👤 User
│   ├── GET Get Profile
│   └── PUT Update Profile
├── 🍽️ Food
│   ├── GET Search Foods
│   └── POST Create Custom Food
├── 📖 Diary
│   ├── GET Get Entries
│   ├── POST Create Entry
│   └── DELETE Delete Entry
└── 📋 Recipe
    ├── GET Get Recipes
    └── POST Toggle Favorite
```

**Test Script di Postman (untuk endpoint Login):**
```javascript
// Tambahkan di tab "Tests" pada request Login
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has token", function () {
    const responseJson = pm.response.json();
    pm.expect(responseJson).to.have.property('token');
    pm.expect(responseJson.token).to.not.be.empty;
    
    // Simpan token untuk request berikutnya
    pm.environment.set("token", responseJson.token);
});
```

---

## 5. Frontend Testing (Flutter)

### 5.1 Unit Testing Flutter

Unit testing Flutter menguji model data dan provider secara terisolasi menggunakan mock objects.

#### 📁 Lokasi File Test

```
nutribunda/test/
├── unit/
│   ├── models/
│   │   ├── diary_entry_test.dart       ← Test model DiaryEntry
│   │   ├── food_model_test.dart        ← Test model FoodModel
│   │   ├── nutrition_summary_test.dart ← Test model NutritionSummary
│   │   └── user_model_test.dart        ← Test model UserModel
│   └── providers/
│       ├── auth_provider_test.dart     ← Test AuthProvider
│       └── food_diary_provider_test.dart ← Test FoodDiaryProvider
└── widget/
    ├── login_screen_test.dart          ← Test LoginScreen widget
    └── nutrition_summary_test.dart     ← Test NutritionSummary widget
```

---

#### 📦 Test Model DiaryEntry

File: `test/unit/models/diary_entry_test.dart`

```dart
// Test parsing JSON dari API
group('DiaryEntry.fromJson', () {
  
  test('harus parse JSON dengan food yang terembed', () {
    final entry = DiaryEntry.fromJson(sampleEntryJson);
    
    expect(entry.id, equals('entry-001'));
    expect(entry.profileType, equals('baby'));
    expect(entry.servingSize, equals(150.0));
    expect(entry.food, isNotNull);
    expect(entry.food!.name, equals('Bubur Ayam'));
  });

  test('harus handle entry tanpa food (custom food)', () {
    // Saat pengguna input nama makanan manual
    final entry = DiaryEntry.fromJson(customFoodJson);
    
    expect(entry.food, isNull);
    expect(entry.customFoodName, equals('Nasi Tim Homemade'));
  });
});

// Test helper methods
group('DiaryEntry.mealTimeDisplay', () {
  
  test('"breakfast" harus tampil sebagai "Makan Pagi"', () {
    final entry = DiaryEntry.fromJson({'meal_time': 'breakfast', ...});
    expect(entry.mealTimeDisplay, equals('Makan Pagi'));
  });
  
  // ... dan seterusnya untuk lunch, dinner, snack
});
```

**Cara menjalankan:**
```bash
cd nutribunda
flutter test test/unit/models/diary_entry_test.dart -v
```

---

#### 📦 Test Model FoodModel

File: `test/unit/models/food_model_test.dart`

```dart
group('FoodModel.fromJson', () {
  
  test('harus parse semua field nutrisi dengan benar', () {
    final food = FoodModel.fromJson(sampleFoodJson);
    
    expect(food.id, equals('food-001'));
    expect(food.name, equals('Bubur Ayam'));
    expect(food.category, equals('mpasi'));
    expect(food.caloriesPer100g, equals(120.0));
    expect(food.proteinPer100g, equals(5.5));
  });
});

group('FoodModel.calculateNutrition', () {
  
  test('harus hitung kalori berdasarkan porsi', () {
    // 150g × 120 kalori/100g = 180 kalori
    final food = FoodModel.fromJson(sampleFoodJson);
    final calories = food.calculateCalories(150.0);
    
    expect(calories, closeTo(180.0, 0.01));
  });
});
```

**Cara menjalankan:**
```bash
flutter test test/unit/models/food_model_test.dart -v
```

---

#### 📦 Test Model NutritionSummary

File: `test/unit/models/nutrition_summary_test.dart`

```dart
group('NutritionSummary', () {
  
  test('harus menjumlah kalori dari beberapa entri', () {
    final summary = NutritionSummary.fromJson({
      'calories': 450.0,
      'protein': 22.5,
      'carbs': 65.0,
      'fat': 12.0,
    });
    
    expect(summary.calories, equals(450.0));
    expect(summary.protein, equals(22.5));
  });
  
  test('harus handle nilai zero dengan benar', () {
    final summary = NutritionSummary.fromJson({
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
    });
    
    expect(summary.calories, equals(0.0));
  });
});
```

**Cara menjalankan:**
```bash
flutter test test/unit/models/nutrition_summary_test.dart -v
```

---

#### 🔐 Test AuthProvider

File: `test/unit/providers/auth_provider_test.dart`

> ℹ️ Provider test menggunakan mock objects agar tidak perlu koneksi internet nyata.

```dart
group('AuthProvider - initial state', () {
  
  test('state awal harus tidak terautentikasi', () {
    // Saat pertama kali buka app, belum login
    expect(authProvider.isAuthenticated, isFalse);
    expect(authProvider.isLoading, isFalse);
    expect(authProvider.user, isNull);
    expect(authProvider.token, isNull);
  });
});

group('AuthProvider.login — validasi input', () {
  
  test('harus gagal jika email kosong', () async {
    final result = await authProvider.login('', 'password123');
    
    expect(result, isFalse);
    expect(authProvider.errorMessage, contains('tidak boleh kosong'));
  });

  test('harus gagal jika format email tidak valid', () async {
    final result = await authProvider.login('bukan-email', 'password123');
    
    expect(result, isFalse);
    expect(authProvider.errorMessage, contains('Format email tidak valid'));
  });
});

group('AuthProvider.login — sukses', () {
  
  test('harus berhasil login dengan kredensial valid', () async {
    // Setup mock: simulasikan response sukses dari server
    when(mockHttpClient.post(any, data: anyNamed('data')))
        .thenAnswer((_) async => Response(
              data: {'token': 'jwt-token-xyz', 'user': userJson},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));
    
    final result = await authProvider.login('bunda@test.com', 'password123');
    
    expect(result, isTrue);
    expect(authProvider.isAuthenticated, isTrue);
    expect(authProvider.token, equals('jwt-token-xyz'));
  });
});
```

**Cara menjalankan:**
```bash
flutter test test/unit/providers/auth_provider_test.dart -v
```

---

### 5.2 Widget Testing

Widget testing menguji tampilan dan interaksi UI Flutter secara otomatis, tanpa perlu menjalankan emulator fisik.

#### 🖥️ Test LoginScreen

File: `test/widget/login_screen_test.dart`

```dart
// Helper: membungkus widget dengan Provider yang diperlukan
Widget buildLoginScreen({required AuthProvider authProvider}) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: const LoginScreen(),
    ),
  );
}

group('LoginScreen — tampilan awal', () {
  
  testWidgets('harus menampilkan field email dan password', (tester) async {
    await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
    await tester.pumpAndSettle(); // Tunggu animasi selesai
    
    // Cek komponen wajib ada
    expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('harus menampilkan tombol Login', (tester) async {
    await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
    await tester.pumpAndSettle();
    
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('tidak boleh menampilkan loading indicator di awal', (tester) async {
    await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
    await tester.pumpAndSettle();
    
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
});

group('LoginScreen — validasi form', () {
  
  testWidgets('harus bisa mengetik di field email', (tester) async {
    await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
    await tester.pumpAndSettle();
    
    // Ketik di field email
    await tester.enterText(find.byType(TextFormField).first, 'bunda@test.com');
    await tester.pump();
    
    expect(find.text('bunda@test.com'), findsOneWidget);
  });

  testWidgets('harus menampilkan error jika submit dengan field kosong', (tester) async {
    await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
    await tester.pumpAndSettle();
    
    // Klik tombol Login tanpa isi form
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    
    // Form harus ada (dan menampilkan error validator)
    expect(find.byType(Form), findsOneWidget);
  });
});

group('LoginScreen — toggle password visibility', () {
  
  testWidgets('harus bisa toggle visibilitas password', (tester) async {
    await tester.pumpWidget(buildLoginScreen(authProvider: authProvider));
    await tester.pumpAndSettle();
    
    // Cari tombol toggle password
    final toggleIcon = find.byIcon(Icons.visibility_off);
    if (toggleIcon.evaluate().isNotEmpty) {
      await tester.tap(toggleIcon);
      await tester.pump();
      
      // Icon berubah setelah di-tap
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    }
  });
});
```

**Cara menjalankan:**
```bash
flutter test test/widget/login_screen_test.dart -v
```

---

#### 📊 Test NutritionSummary Widget

File: `test/widget/nutrition_summary_test.dart`

```dart
group('NutritionSummaryWidget', () {
  
  testWidgets('harus menampilkan nilai kalori', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NutritionSummaryWidget(
          summary: NutritionSummary(
            calories: 450.0,
            protein: 22.5,
            carbs: 65.0,
            fat: 12.0,
          ),
        ),
      ),
    );
    
    expect(find.text('450'), findsOneWidget);     // atau format yang dipakai
    expect(find.text('22.5'), findsOneWidget);    // protein
  });
});
```

**Cara menjalankan:**
```bash
flutter test test/widget/nutrition_summary_test.dart -v
```

---

#### ✏️ Menulis Widget Test Baru

Berikut template untuk menulis widget test baru:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:nutribunda/presentation/pages/YOUR_PAGE.dart';
import 'package:nutribunda/presentation/providers/YOUR_PROVIDER.dart';

// Generate mock: dart run build_runner build
@GenerateMocks([YourService])
import 'your_test.mocks.dart';

void main() {
  late YourProvider provider;

  setUp(() {
    // Inisialisasi mock dan provider sebelum setiap test
    final mockService = MockYourService();
    provider = YourProvider(service: mockService);
  });

  testWidgets('deskripsi test Anda di sini', (WidgetTester tester) async {
    // 1. ARRANGE: Setup widget
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const YourWidget(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2. ACT: Lakukan interaksi (opsional)
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // 3. ASSERT: Verifikasi hasil
    expect(find.text('Expected Text'), findsOneWidget);
    expect(find.byType(SomeWidget), findsNothing);
  });
}
```

---

## 6. Menjalankan Semua Test

### Backend — Semua Test Sekaligus

```bash
cd NutriBunda_v2-main/backend

# Jalankan semua unit test
go test ./...

# Jalankan dengan verbose
go test ./... -v

# Jalankan dengan timeout
go test ./... -timeout 60s

# Jalankan dengan laporan coverage
go test ./... -cover -coverprofile=coverage.out
go tool cover -func=coverage.out
```

### Frontend — Semua Test Sekaligus

```bash
cd NutriBunda_v2-main/nutribunda

# Jalankan semua test
flutter test

# Jalankan dengan verbose
flutter test --verbose

# Jalankan dengan coverage
flutter test --coverage
# Laporan tersimpan di coverage/lcov.info

# Jalankan test spesifik berdasarkan nama
flutter test --name "harus menampilkan tombol Login"

# Jalankan test dari folder tertentu
flutter test test/unit/
flutter test test/widget/
```

### Script Otomatis (jalankan semua sekaligus)

Buat file `run_tests.sh` di root project:

```bash
#!/bin/bash
echo "=============================="
echo "  NutriBunda Test Suite"
echo "=============================="

echo ""
echo "▶ Menjalankan Backend Tests..."
cd backend
go test ./... -v
BACKEND_STATUS=$?
cd ..

echo ""
echo "▶ Menjalankan Flutter Tests..."
cd nutribunda
flutter test --verbose
FLUTTER_STATUS=$?
cd ..

echo ""
echo "=============================="
echo "  Ringkasan Hasil"
echo "=============================="
if [ $BACKEND_STATUS -eq 0 ]; then
  echo "✅ Backend Tests: LULUS"
else
  echo "❌ Backend Tests: GAGAL"
fi

if [ $FLUTTER_STATUS -eq 0 ]; then
  echo "✅ Flutter Tests: LULUS"
else
  echo "❌ Flutter Tests: GAGAL"
fi
```

Jalankan dengan:
```bash
chmod +x run_tests.sh
./run_tests.sh
```

---

## 7. Memahami Hasil Test

### Hasil Test Go

```
=== RUN   TestRegister
=== RUN   TestRegister/successful_registration
--- PASS: TestRegister/successful_registration (0.12s)   ← ✅ LULUS
=== RUN   TestRegister/duplicate_email
--- PASS: TestRegister/duplicate_email (0.11s)           ← ✅ LULUS
--- PASS: TestRegister (0.23s)

FAIL: TestLogin/invalid_email                             ← ❌ GAGAL
    service_test.go:89: Error: expected error, got nil
```

**Arti simbol:**
- `PASS` → Test berhasil, kode berfungsi seperti yang diharapkan
- `FAIL` → Test gagal, ada masalah pada kode
- `SKIP` → Test dilewati (biasanya karena kondisi tertentu tidak terpenuhi)

### Hasil Test Flutter

```
00:01 +0: loading...
00:05 +3: test/unit/models/diary_entry_test.dart: DiaryEntry.fromJson harus parse JSON
00:05 +4: test/unit/models/diary_entry_test.dart: DiaryEntry.displayName harus kembalikan nama food
00:05 +5 -1: test/widget/login_screen_test.dart: LoginScreen tampilan awal harus menampilkan tombol Login
          Terjadi error: ...
```

**Arti notasi:**
- `+3` → 3 test sudah lulus
- `-1` → 1 test gagal
- Angka di belakang titik dua → nomor urut test

### Coverage Report

```
coverage/
  - auth/service.go: 87.5%    ← 87.5% baris kode telah ditest
  - diary/service.go: 72.3%   ← 72.3% baris kode telah ditest
```

> 💡 **Target coverage:** Usahakan minimum 70% untuk produksi. Lebih tinggi lebih baik, namun 100% tidak selalu praktis.

---

## 8. Troubleshooting

### Masalah Umum Backend

**Error: `cannot find package`**
```bash
cd backend
go mod tidy
go mod download
```

**Error: `database connection refused`**
```bash
# Pastikan PostgreSQL berjalan
# Sesuaikan .env dengan setting database Anda
cp .env.example .env
# Edit .env sesuai konfigurasi lokal
```

**Error: `go: go.sum file is out of date`**
```bash
go mod tidy
```

### Masalah Umum Flutter

**Error: `Mock class not generated`**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Error: `No tests were found`**
```bash
# Pastikan file test ada di folder test/
ls test/

# Pastikan nama file diakhiri _test.dart
```

**Error: `pumpAndSettle timed out`**
```bash
# Tambahkan timeout lebih lama
await tester.pumpAndSettle(const Duration(seconds: 10));
```

**Error: `A RenderFlex overflowed` di widget test**
```bash
# Bungkus widget dalam SingleChildScrollView atau tambahkan constraints
await tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: Scaffold(body: YourWidget()),
    ),
  ),
);
```

---

## 📚 Referensi Tambahan

| Topik | Link |
|-------|------|
| Go Testing Package | https://pkg.go.dev/testing |
| Testify (Go assertions) | https://github.com/stretchr/testify |
| Flutter Testing Docs | https://docs.flutter.dev/testing |
| Mockito untuk Dart | https://pub.dev/packages/mockito |
| flutter_test API | https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html |

---

*Panduan ini dibuat untuk Project NutriBunda v2.0 — Aplikasi Gizi Ibu & Bayi*
*Dibuat: Mei 2026*