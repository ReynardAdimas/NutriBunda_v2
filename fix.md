# 🏃 Panduan: Ubah Pedometer Menjadi Mode Smartwatch
### Disesuaikan untuk Flutter 3.41.2 + `flutter_local_notifications` v20.0.0

> **Tujuan:** Menghapus tombol Mulai/Berhenti dan Reset, membuat pedometer aktif otomatis seperti smartwatch, menambahkan notifikasi setiap kelipatan 100 langkah, dan reset otomatis setiap tengah malam.

---

## ⚠️ Perubahan Penting di v20.0.0 vs Versi Lama

| Hal | Versi Lama | v20.0.0 |
|-----|-----------|---------|
| Method `show()` | Positional: `show(0, 'title', 'body', details)` | Named: `show(id: 0, title: '...', body: '...', notificationDetails: details)` |
| iOS class | `IOSInitializationSettings` | `DarwinInitializationSettings` |
| Android permission | Pakai `permission_handler` | Pakai `requestNotificationsPermission()` bawaan plugin |
| Minimum Android | API 21 (Android 5) | **API 24 (Android 7)** |
| Minimum Flutter | 3.22.0 | **3.38.1** ✅ (kompatibel dengan 3.41.2) |

---

## Gambaran File yang Diubah

| File | Perubahan |
|------|-----------|
| `pubspec.yaml` | Tambah `flutter_local_notifications: ^20.0.0` |
| `notification_service.dart` | File baru — wrapper notifikasi |
| `main.dart` | Inisialisasi `NotificationService` |
| `pedometer_service.dart` | Tambah timer midnight reset |
| `diet_plan_provider.dart` | Trigger notifikasi, callback midnight, auto-start |
| `pedometer_controls.dart` | Hapus semua tombol, UI smartwatch-style |
| `AndroidManifest.xml` | Tambah permission `POST_NOTIFICATIONS` |

---

## Step 1 — Tambah Dependency di `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... dependency lain yang sudah ada ...
  flutter_local_notifications: ^20.0.0   # ← TAMBAHKAN INI
```

Lalu jalankan:

```bash
flutter pub get
```

---

## Step 2 — Buat `notification_service.dart`

Buat file baru: `nutribunda/lib/core/services/notification_service.dart`

> **Perhatian v20.0.0:** Method `show()` sekarang menggunakan **named parameters**, dan permission Android diminta lewat `AndroidFlutterLocalNotificationsPlugin`, bukan `permission_handler`.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service untuk notifikasi pedometer — kompatibel dengan v20.0.0
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inisialisasi plugin — panggil sekali di main.dart
  Future<void> initialize() async {
    if (_initialized) return;

    // Android: gunakan ic_launcher sebagai ikon notifikasi
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS: gunakan DarwinInitializationSettings (bukan IOSInitializationSettings)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // diminta manual setelah init
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;

    // Request permission setelah init
    await _requestPermissions();

    debugPrint('NotificationService: Initialized');
  }

  /// Request permission — cara baru di v20.0.0
  Future<void> _requestPermissions() async {
    // Android 13+ (API 33+): request via plugin implementation
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    // iOS: request alert, badge, sound
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Tampilkan notifikasi pencapaian langkah
  /// PERUBAHAN v20.0.0: show() sekarang pakai named parameters
  Future<void> showStepMilestoneNotification(int steps) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'pedometer_channel',   // channel ID
      'Pedometer',           // channel name
      channelDescription: 'Notifikasi pencapaian langkah kaki',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ✅ v20.0.0: gunakan named parameters
    await _plugin.show(
      id: steps,                          // ID unik per milestone
      title: '🎉 Pencapaian Langkah!',
      body: 'Selamat! Kamu sudah berjalan $steps langkah hari ini.',
      notificationDetails: details,
    );

    debugPrint('NotificationService: Milestone shown — $steps steps');
  }
}
```

---

## Step 3 — Inisialisasi di `main.dart`

Buka `nutribunda/lib/main.dart`, tambahkan inisialisasi **sebelum** `runApp`:

```dart
import 'core/services/notification_service.dart';  // ← TAMBAHKAN IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... inisialisasi lain yang sudah ada ...

  await NotificationService().initialize();         // ← TAMBAHKAN INI

  runApp(const MyApp());
}
```

---

## Step 4 — Modifikasi `pedometer_service.dart`

Tambahkan **timer midnight reset** otomatis. Buka `nutribunda/lib/core/services/pedometer_service.dart`:

### 4a. Tambah field `_midnightTimer`

```dart
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/foundation.dart';

class PedometerService {
  StreamSubscription<StepCount>? _subscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  Timer? _midnightTimer;          // ← TAMBAHKAN INI

  // ... semua field lain tidak berubah ...
```

### 4b. Tambah method `_scheduleMidnightReset()`

Tambahkan method baru di dalam class:

```dart
/// Jadwalkan reset otomatis di tengah malam, ulangi setiap hari
void _scheduleMidnightReset(VoidCallback onReset) {
  _midnightTimer?.cancel();

  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1); // besok 00:00:00
  final duration = nextMidnight.difference(now);

  _midnightTimer = Timer(duration, () {
    debugPrint('PedometerService: Midnight reset triggered');
    resetDailySteps();
    onReset();

    // Jadwalkan ulang untuk besoknya
    _scheduleMidnightReset(onReset);
  });

  debugPrint(
    'PedometerService: Next reset in '
    '${duration.inHours}h ${duration.inMinutes % 60}m',
  );
}
```

### 4c. Update signature `startListening()` — tambah parameter `onMidnightReset`

```dart
// SEBELUM:
void startListening(Function(int steps) onStepUpdate, {int savedDailySteps = 0}) {

// SESUDAH:
void startListening(
  Function(int steps) onStepUpdate, {
  int savedDailySteps = 0,
  VoidCallback? onMidnightReset,    // ← TAMBAHKAN PARAMETER INI
}) {
  if (_isListening) {
    debugPrint('PedometerService: Already listening');
    return;
  }

  _savedSteps = savedDailySteps;

  try {
    _subscription = Pedometer.stepCountStream.listen(
      // ... isi yang sudah ada, tidak diubah ...
    );

    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
      // ... isi yang sudah ada, tidak diubah ...
    );

    _isListening = true;

    // ← TAMBAHKAN INI di akhir blok try
    if (onMidnightReset != null) {
      _scheduleMidnightReset(onMidnightReset);
    }

    debugPrint('PedometerService: Started listening');
  } catch (e) {
    _errorMessage = 'Failed to start pedometer: $e';
    debugPrint('PedometerService: Exception - $_errorMessage');
  }
}
```

### 4d. Update `stopListening()` — cancel timer

```dart
void stopListening() {
  _subscription?.cancel();
  _subscription = null;

  _statusSubscription?.cancel();
  _statusSubscription = null;

  _midnightTimer?.cancel();    // ← TAMBAHKAN INI
  _midnightTimer = null;

  _isListening = false;
  _initialStepsSet = false;
  debugPrint('PedometerService: Stopped listening');
}
```

> `dispose()` tidak perlu diubah karena sudah memanggil `stopListening()`.

---

## Step 5 — Modifikasi `diet_plan_provider.dart`

### 5a. Tambah import `NotificationService`

```dart
import 'package:nutribunda/data/datasources/local/local_steps_datasource.dart';
import '../../core/services/notification_service.dart';   // ← TAMBAHKAN INI
import 'base_provider.dart';
import '../../data/models/user_model.dart';
import '../../core/services/pedometer_service.dart';
```

### 5b. Tambah field tracker milestone di dalam class

```dart
class DietPlanProvider extends BaseProvider {
  // ... semua field yang sudah ada ...

  int _lastNotifiedMilestone = 0;                                    // ← TAMBAHKAN
  final NotificationService _notificationService = NotificationService();  // ← TAMBAHKAN
```

### 5c. Update `updateSteps()` — tambah logika notifikasi

Cari method `updateSteps()` yang sudah ada, tambahkan blok notifikasi setelah `safeNotifyListeners()`:

```dart
void updateSteps(int steps) {
  _checkAndResetForNewDay();
  _steps = steps;

  if (_user == null || _user!.weight == null) {
    _caloriesBurned = 0;
    safeNotifyListeners();
    return;
  }

  final weight = _user!.weight!;
  _caloriesBurned = steps * 0.04 * weight / 1000;

  safeNotifyListeners();

  // ← TAMBAHKAN BLOK INI: Notifikasi setiap kelipatan 100 langkah
  final currentMilestone = (steps ~/ 100) * 100;
  if (currentMilestone > 0 && currentMilestone > _lastNotifiedMilestone) {
    _lastNotifiedMilestone = currentMilestone;
    _notificationService.showStepMilestoneNotification(currentMilestone);
  }

  if (steps % 10 == 0 || steps == 0) {
    _saveTodayStepsLocally();
  }
}
```

### 5d. Update `startPedometerTracking()` — tambah callback midnight reset

```dart
void startPedometerTracking() {
  if (_pedometerService.isListening) {
    return;
  }

  _pedometerService.startListening(
    (steps) {
      updateSteps(steps);
    },
    savedDailySteps: _steps,
    onMidnightReset: () {               // ← TAMBAHKAN CALLBACK INI
      _steps = 0;
      _caloriesBurned = 0;
      _lastNotifiedMilestone = 0;       // reset milestone tracker
      safeNotifyListeners();
      _saveTodayStepsLocally();         // simpan 0 ke DB untuk hari baru
      debugPrint('DietPlanProvider: Midnight reset applied');
    },
  );
}
```

### 5e. Update `resetDailySteps()` — tambah reset milestone

```dart
void resetDailySteps() {
  _steps = 0;
  _caloriesBurned = 0;
  _lastNotifiedMilestone = 0;    // ← TAMBAHKAN INI
  _pedometerService.resetDailySteps();
  safeNotifyListeners();
}
```

---

## Step 6 — Modifikasi `pedometer_controls.dart` (UI Smartwatch)

Ganti seluruh isi file dengan kode berikut — **semua tombol dihapus**:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/diet_plan_provider.dart';

/// Pedometer Widget — Smartwatch Style
/// Aktif otomatis tanpa tombol Mulai/Berhenti/Reset
class PedometerControls extends StatelessWidget {
  const PedometerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DietPlanProvider>(
      builder: (context, provider, child) {
        final hasError = provider.pedometerError != null;
        final steps = provider.steps;
        final caloriesBurned = provider.caloriesBurned;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan status always-on
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_walk,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Pedometer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusIndicator(context, hasError),
                  ],
                ),
                const SizedBox(height: 16),

                // Pesan error jika ada
                if (hasError) ...[
                  _buildErrorMessage(context, provider.pedometerError!),
                  const SizedBox(height: 16),
                ],

                // Tampilan langkah
                _buildStepDisplay(context, steps, caloriesBurned),

                const SizedBox(height: 12),

                // Info reset harian otomatis
                _buildDailyResetInfo(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Status indicator — selalu "Aktif" seperti smartwatch
  Widget _buildStatusIndicator(BuildContext context, bool hasError) {
    final color = hasError ? Colors.red : Colors.green;
    final text = hasError ? 'Error' : 'Aktif';
    final icon =
        hasError ? Icons.error_outline : Icons.check_circle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(fontSize: 12, color: Colors.red[800]),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan angka langkah — pulsing dot selalu aktif
  Widget _buildStepDisplay(
    BuildContext context,
    int steps,
    double caloriesBurned,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Pulsing dot selalu tampil (tidak butuh tombol)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 12),
                child: _PulsingDot(),
              ),
              Text(
                steps.toString(),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'langkah',
                  style:
                      TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.whatshot,
                    size: 18, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  '${caloriesBurned.toStringAsFixed(1)} kkal terbakar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyResetInfo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          'Reset otomatis setiap tengah malam',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

/// Pulsing dot — selalu beranimasi tanpa perlu state aktif/nonaktif
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: Colors.green
                    .withValues(alpha: _animation.value * 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Step 7 — Update `AndroidManifest.xml`

Buka `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>

    <!-- Sudah ada — pastikan ada -->
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />

    <!-- TAMBAHKAN: Wajib untuk Android 13+ agar notifikasi muncul -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application ...>
      <!-- ... isi application tidak perlu diubah ... -->
    </application>

</manifest>
```

> **Catatan v20.0.0:** Kamu **tidak** perlu menambahkan `VIBRATE` atau `RECEIVE_BOOT_COMPLETED` karena fitur yang kita gunakan hanya `show()` instan (bukan scheduled/repeating via plugin).

---

## Ringkasan Alur Kerja Setelah Perubahan

```
App dibuka
    │
    ▼
NotificationService().initialize()
    ├── Setup plugin (Android + iOS)
    └── Request permission otomatis
    │
    ▼
loadTodaySteps() → baca DB → inject ke PedometerService
    │
    ▼
startPedometerTracking() → AKTIF otomatis, TANPA tombol
    │
    ├── Setiap langkah baru → updateSteps()
    │       ├── Hitung kalori
    │       ├── steps kelipatan 100? → showStepMilestoneNotification()
    │       └── Simpan ke SQLite setiap 10 langkah
    │
    └── Timer tengah malam berjalan di background
            └── 00:00 → resetDailySteps() → steps=0, simpan DB, reschedule
```

---

## Checklist Akhir

- [ ] `pubspec.yaml` — `flutter_local_notifications: ^20.0.0` ditambahkan & `flutter pub get` dijalankan
- [ ] `notification_service.dart` — file baru dibuat dengan API v20.0.0 (`show(id:, title:, body:, notificationDetails:)`)
- [ ] `main.dart` — `await NotificationService().initialize()` dipanggil sebelum `runApp`
- [ ] `pedometer_service.dart` — `_midnightTimer` dan `_scheduleMidnightReset()` ditambahkan, `startListening()` memiliki parameter `onMidnightReset`
- [ ] `diet_plan_provider.dart` — `_lastNotifiedMilestone`, notifikasi milestone di `updateSteps()`, dan `onMidnightReset` callback di `startPedometerTracking()` ditambahkan
- [ ] `pedometer_controls.dart` — semua tombol dihapus, UI always-on
- [ ] `AndroidManifest.xml` — `POST_NOTIFICATIONS` permission ditambahkan