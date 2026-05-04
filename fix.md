# Fix: Menyimpan Data Pedometer (Steps & Kalori) ke Database Per Hari

## Ringkasan Masalah

Setelah menganalisis kode project NutriBunda, ditemukan bahwa:

- `PedometerService` hanya menyimpan data **di memori (RAM)** — data hilang saat app ditutup.
- `DietPlanProvider` meng-update `_steps` dan `_caloriesBurned` secara real-time, tapi **tidak pernah menyimpannya** ke local database (SQLite) maupun backend (PostgreSQL).
- Tidak ada tabel `daily_steps` di `database_helper.dart` maupun di backend schema.
- Tidak ada endpoint API `/pedometer` atau `/steps` di backend.

---

## Arsitektur Solusi

```
PedometerService (sensor)
        ↓
DietPlanProvider (update steps)
        ↓
PedometerRepository (koordinator)
    ↙           ↘
LocalStepsDatasource    BackendStepsDatasource
(SQLite - offline)      (PostgreSQL - online)
```

Data disimpan **lokal dulu** setiap kali ada perubahan signifikan, lalu **disync ke backend** secara periodik atau saat koneksi tersedia.

---

## LANGKAH 1 — Buat Tabel `daily_steps` di SQLite (Local Database)

**File:** `nutribunda/lib/data/datasources/local/database_helper.dart`

Tambahkan tabel baru di dalam method `_createTables` (atau `onCreate`), **setelah** tabel `diary_entries`:

```dart
// Daily steps table — simpan data pedometer per hari
await db.execute('''
  CREATE TABLE daily_steps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    date TEXT NOT NULL,
    steps INTEGER NOT NULL DEFAULT 0,
    calories_burned REAL NOT NULL DEFAULT 0.0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    is_synced INTEGER NOT NULL DEFAULT 0,
    UNIQUE(user_id, date)
  )
''');
```

> **Catatan:** Kolom `UNIQUE(user_id, date)` memastikan hanya ada **satu record per user per hari**. Ini adalah kunci agar data terakumulasi dengan benar, bukan duplikat.

---

## LANGKAH 2 — Buat Local Datasource untuk Steps

**File baru:** `nutribunda/lib/data/datasources/local/local_steps_datasource.dart`

```dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class LocalStepsDatasource {
  final DatabaseHelper _dbHelper;

  LocalStepsDatasource(this._dbHelper);

  /// Simpan atau update data steps hari ini menggunakan UPSERT
  Future<void> saveOrUpdateDailySteps({
    required int userId,
    required String date, // format: 'YYYY-MM-DD'
    required int steps,
    required double caloriesBurned,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // INSERT OR REPLACE: jika (user_id, date) sudah ada → update, jika belum → insert
    await db.rawInsert('''
      INSERT INTO daily_steps (user_id, date, steps, calories_burned, created_at, updated_at, is_synced)
      VALUES (?, ?, ?, ?, ?, ?, 0)
      ON CONFLICT(user_id, date) DO UPDATE SET
        steps = excluded.steps,
        calories_burned = excluded.calories_burned,
        updated_at = excluded.updated_at,
        is_synced = 0
    ''', [userId, date, steps, caloriesBurned, now, now]);
  }

  /// Ambil data steps untuk tanggal tertentu
  Future<Map<String, dynamic>?> getDailySteps({
    required int userId,
    required String date,
  }) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'daily_steps',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Ambil semua data steps yang belum disync ke backend
  Future<List<Map<String, dynamic>>> getUnsyncedSteps(int userId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'daily_steps',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
  }

  /// Tandai record sebagai sudah disync
  Future<void> markAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'daily_steps',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

---

## LANGKAH 3 — Tambah Tabel `daily_steps` di Backend (PostgreSQL)

**File baru:** `backend/internal/database/migrations/004_add_daily_steps.sql`

```sql
CREATE TABLE IF NOT EXISTS daily_steps (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date        DATE NOT NULL,
    steps       INTEGER NOT NULL DEFAULT 0,
    calories_burned DECIMAL(7,2) NOT NULL DEFAULT 0.0,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_steps_user_date ON daily_steps(user_id, date);
```

---

## LANGKAH 4 — Tambah Model `DailySteps` di Backend (Go)

**File:** `backend/internal/database/models.go`

Tambahkan struct baru di bagian bawah, sebelum BeforeCreate hooks:

```go
// DailySteps represents pedometer data per day per user
type DailySteps struct {
    ID             uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
    UserID         uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
    User           User      `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"-"`
    Date           time.Time `gorm:"type:date;not null" json:"date"`
    Steps          int       `gorm:"not null;default:0" json:"steps"`
    CaloriesBurned float64   `gorm:"type:decimal(7,2);not null;default:0" json:"calories_burned"`
    CreatedAt      time.Time `json:"created_at"`
    UpdatedAt      time.Time `json:"updated_at"`
}

// BeforeCreate hook for DailySteps
func (d *DailySteps) BeforeCreate(tx *gorm.DB) error {
    if d.ID == uuid.Nil {
        d.ID = uuid.New()
    }
    return nil
}
```

Tambahkan juga `DailySteps` ke auto-migrate di `main.go`:

```go
// Di dalam fungsi AutoMigrate (backend/cmd/api/main.go)
db.AutoMigrate(
    &database.User{},
    &database.Food{},
    &database.Recipe{},
    &database.DiaryEntry{},
    &database.FavoriteRecipe{},
    &database.QuizQuestion{},
    &database.Notification{},
    &database.DailySteps{}, // ← Tambahkan ini
)
```

---

## LANGKAH 5 — Buat Handler & Service untuk Steps di Backend

**File baru:** `backend/internal/steps/service.go`

```go
package steps

import (
    "errors"
    "nutribunda-backend/internal/database"
    "time"

    "github.com/google/uuid"
    "gorm.io/gorm"
    "gorm.io/gorm/clause"
)

var ErrInvalidDate = errors.New("invalid date format")

type Service struct {
    db *gorm.DB
}

func NewService(db *gorm.DB) *Service {
    return &Service{db: db}
}

type UpsertStepsRequest struct {
    Date           string  `json:"date" binding:"required"` // "YYYY-MM-DD"
    Steps          int     `json:"steps" binding:"min=0"`
    CaloriesBurned float64 `json:"calories_burned" binding:"min=0"`
}

// UpsertDailySteps menyimpan atau mengupdate data steps untuk suatu hari
func (s *Service) UpsertDailySteps(userID uuid.UUID, req *UpsertStepsRequest) (*database.DailySteps, error) {
    date, err := time.Parse("2006-01-02", req.Date)
    if err != nil {
        return nil, ErrInvalidDate
    }

    record := database.DailySteps{
        UserID:         userID,
        Date:           date,
        Steps:          req.Steps,
        CaloriesBurned: req.CaloriesBurned,
    }

    // UPSERT: insert, jika konflik pada (user_id, date) maka update
    result := s.db.Clauses(clause.OnConflict{
        Columns:   []clause.Column{{Name: "user_id"}, {Name: "date"}},
        DoUpdates: clause.AssignmentColumns([]string{"steps", "calories_burned", "updated_at"}),
    }).Create(&record)

    if result.Error != nil {
        return nil, result.Error
    }

    return &record, nil
}

// GetDailySteps mengambil data steps untuk tanggal tertentu
func (s *Service) GetDailySteps(userID uuid.UUID, dateStr string) (*database.DailySteps, error) {
    date, err := time.Parse("2006-01-02", dateStr)
    if err != nil {
        return nil, ErrInvalidDate
    }

    var record database.DailySteps
    err = s.db.Where("user_id = ? AND date = ?", userID, date).First(&record).Error
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return nil, nil // Tidak ada data — kembalikan nil, bukan error
    }
    return &record, err
}
```

**File baru:** `backend/internal/steps/handler.go`

```go
package steps

import (
    "net/http"
    "nutribunda-backend/internal/auth"

    "github.com/gin-gonic/gin"
)

type Handler struct {
    service *Service
}

func NewHandler(service *Service) *Handler {
    return &Handler{service: service}
}

// UpsertSteps godoc
// @Summary Save or update daily steps
// @Router /api/steps [post]
func (h *Handler) UpsertSteps(c *gin.Context) {
    userID, err := auth.GetUserID(c)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
        return
    }

    var req UpsertStepsRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request", "details": err.Error()})
        return
    }

    record, err := h.service.UpsertDailySteps(userID, &req)
    if err != nil {
        if err == ErrInvalidDate {
            c.JSON(http.StatusBadRequest, gin.H{"error": "Format tanggal tidak valid, gunakan YYYY-MM-DD"})
            return
        }
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan data langkah"})
        return
    }

    c.JSON(http.StatusOK, record)
}

// GetSteps godoc
// @Summary Get daily steps for a date
// @Router /api/steps [get]
func (h *Handler) GetSteps(c *gin.Context) {
    userID, err := auth.GetUserID(c)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
        return
    }

    date := c.Query("date")
    if date == "" {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Parameter 'date' diperlukan"})
        return
    }

    record, err := h.service.GetDailySteps(userID, date)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal mengambil data langkah"})
        return
    }

    if record == nil {
        c.JSON(http.StatusOK, gin.H{"steps": 0, "calories_burned": 0.0, "date": date})
        return
    }

    c.JSON(http.StatusOK, record)
}
```

---

## LANGKAH 6 — Daftarkan Route `/api/steps` di `main.go`

**File:** `backend/cmd/api/main.go`

```go
// Tambahkan import
import "nutribunda-backend/internal/steps"

// Di dalam fungsi main, setelah inisialisasi service lain:
stepsService := steps.NewService(db)
stepsHandler := steps.NewHandler(stepsService)

// Di dalam route group yang sudah pakai JWT middleware:
stepsRoutes := api.Group("/steps")
stepsRoutes.Use(auth.JWTMiddleware(authService))
{
    stepsRoutes.POST("", stepsHandler.UpsertSteps)
    stepsRoutes.GET("", stepsHandler.GetSteps)
}
```

---

## LANGKAH 7 — Update `DietPlanProvider` agar Auto-Save ke SQLite

**File:** `nutribunda/lib/presentation/providers/diet_plan_provider.dart`

Tambahkan dependency dan logika auto-save:

```dart
import '../../data/datasources/local/local_steps_datasource.dart';

class DietPlanProvider extends BaseProvider {
  // ... kode yang sudah ada ...

  // Tambahkan dependency
  final LocalStepsDatasource _localStepsDatasource;
  int? _currentUserId; // ID user lokal dari SQLite

  DietPlanProvider(this._localStepsDatasource);

  /// Set user ID lokal (panggil ini saat user login)
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  /// Update steps dan simpan ke database lokal
  /// Requirements: 5.6, 5.7
  @override
  void updateSteps(int steps) {
    _steps = steps;

    if (_user == null || _user!.weight == null) {
      _caloriesBurned = 0;
      safeNotifyListeners();
      return;
    }

    final weight = _user!.weight!;
    _caloriesBurned = steps * 0.04 * weight / 1000;

    safeNotifyListeners();

    // Auto-save ke local database (debounce: simpan setiap 10 langkah)
    if (steps % 10 == 0 || steps == 0) {
      _saveTodayStepsLocally();
    }
  }

  /// Simpan data steps hari ini ke SQLite
  Future<void> _saveTodayStepsLocally() async {
    if (_currentUserId == null) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      await _localStepsDatasource.saveOrUpdateDailySteps(
        userId: _currentUserId!,
        date: dateStr,
        steps: _steps,
        caloriesBurned: _caloriesBurned,
      );
      debugPrint('DietPlanProvider: Steps saved locally — $_steps steps');
    } catch (e) {
      debugPrint('DietPlanProvider: Failed to save steps locally — $e');
    }
  }

  /// Load data steps hari ini dari SQLite (panggil saat app dibuka)
  Future<void> loadTodaySteps() async {
    if (_currentUserId == null) return;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      final data = await _localStepsDatasource.getDailySteps(
        userId: _currentUserId!,
        date: dateStr,
      );

      if (data != null) {
        _steps = data['steps'] as int;
        _caloriesBurned = (data['calories_burned'] as num).toDouble();
        safeNotifyListeners();
        debugPrint('DietPlanProvider: Loaded today steps — $_steps');
      }
    } catch (e) {
      debugPrint('DietPlanProvider: Failed to load steps — $e');
    }
  }

  /// Paksa simpan data steps saat ini (panggil saat stop tracking / app background)
  Future<void> forceSaveSteps() async {
    await _saveTodayStepsLocally();
  }
}
```

---

## LANGKAH 8 — Sync Data ke Backend (Opsional tapi Direkomendasikan)

**File baru:** `nutribunda/lib/core/services/steps_sync_service.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import '../../data/datasources/local/local_steps_datasource.dart';

class StepsSyncService {
  final LocalStepsDatasource _localDatasource;
  final String _authToken;

  StepsSyncService(this._localDatasource, this._authToken);

  /// Upload semua steps yang belum disync ke backend
  Future<void> syncPendingSteps(int userId) async {
    final unsyncedRecords = await _localDatasource.getUnsyncedSteps(userId);

    for (final record in unsyncedRecords) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/steps'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          },
          body: jsonEncode({
            'date': record['date'],
            'steps': record['steps'],
            'calories_burned': record['calories_burned'],
          }),
        );

        if (response.statusCode == 200) {
          await _localDatasource.markAsSynced(record['id'] as int);
        }
      } catch (e) {
        // Gagal sync — coba lagi nanti
        continue;
      }
    }
  }
}
```

---

## LANGKAH 9 — Auto-Reset di Tengah Malam

Tambahkan logika reset harian di `DietPlanProvider`. Reset diperlukan agar hitungan steps kembali ke 0 setiap hari baru.

**File:** `nutribunda/lib/presentation/providers/diet_plan_provider.dart`

```dart
DateTime? _lastTrackedDate;

/// Cek apakah tanggal sudah berganti — panggil di updateSteps
void _checkAndResetForNewDay() {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  if (_lastTrackedDate != null && _lastTrackedDate!.isBefore(todayDate)) {
    // Hari sudah berganti — reset otomatis
    debugPrint('DietPlanProvider: New day detected, resetting steps');
    resetDailySteps();
  }

  _lastTrackedDate = todayDate;
}

/// Panggil ini di awal updateSteps
@override
void updateSteps(int steps) {
  _checkAndResetForNewDay(); // ← Tambahkan ini di baris pertama
  // ... sisa kode updateSteps yang sudah ada ...
}
```

---

## LANGKAH 10 — Panggil `loadTodaySteps()` saat App Dibuka

Di screen atau widget yang menginisialisasi `DietPlanProvider`, tambahkan:

```dart
// Contoh di initState() screen utama atau di DietPlanPage
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final provider = context.read<DietPlanProvider>();
    provider.loadTodaySteps(); // ← Load data tersimpan saat app dibuka
  });
}
```

Dan pastikan untuk menyimpan saat app masuk background/ditutup dengan `AppLifecycleState`:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    context.read<DietPlanProvider>().forceSaveSteps();
  }
}
```

---

## Rangkuman Alur Data Setelah Fix

```
User berjalan
    ↓
PedometerService.onStepUpdate()
    ↓
DietPlanProvider.updateSteps(steps)
    ↓
Hitung caloriesBurned
    ↓
Setiap 10 langkah → _saveTodayStepsLocally()
    ↓
SQLite: INSERT OR UPDATE daily_steps WHERE (user_id, date)
    ↓ (saat online / saat stop tracking)
StepsSyncService.syncPendingSteps()
    ↓
Backend POST /api/steps → PostgreSQL daily_steps
```

---

## Checklist Implementasi

- [ ] Tambah tabel `daily_steps` di `database_helper.dart`
- [ ] Buat `local_steps_datasource.dart`
- [ ] Tambah migration `004_add_daily_steps.sql` di backend
- [ ] Tambah struct `DailySteps` di `models.go` + AutoMigrate
- [ ] Buat `steps/service.go` dan `steps/handler.go` di backend
- [ ] Daftarkan route `/api/steps` di `main.go`
- [ ] Update `DietPlanProvider` — tambah auto-save & loadTodaySteps
- [ ] Buat `StepsSyncService` untuk sync ke backend
- [ ] Tambah auto-reset tengah malam
- [ ] Panggil `loadTodaySteps()` di initState screen utama
- [ ] Panggil `forceSaveSteps()` saat app background/ditutup