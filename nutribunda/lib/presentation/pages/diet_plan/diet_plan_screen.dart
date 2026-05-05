import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/diet_plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_diary_provider.dart';
import '../../widgets/diet_plan/physical_data_form.dart';
import '../../widgets/diet_plan/diet_plan_dashboard.dart';
import '../../widgets/diet_plan/pedometer_controls.dart';

/// Diet Plan Screen - Main screen untuk Diet Plan ibu pasca-melahirkan
/// Requirements: 5.6, 5.7, 5.8, 5.9, 5.10, 5.11 - Diet plan dashboard dengan progress tracking dan pedometer
class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

// ✅ PERBAIKAN: 'with WidgetsBindingObserver' harus menyatu di baris deklarasi class state
class _DietPlanScreenState extends State<DietPlanScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Daftarkan observer untuk deteksi AppLifecycleState (background/foreground)
    // Langkah 10: Diperlukan agar forceSaveSteps() dipanggil saat app masuk background
    WidgetsBinding.instance.addObserver(this);

    // Load user data and initialize diet plan setelah frame pertama selesai render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDietPlan();
    });
  }

  /// Langkah 10: Dipanggil otomatis saat AppLifecycleState berubah
  /// Menyimpan data steps ke SQLite saat app di-pause atau ditutup
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Paksa simpan steps ke SQLite sebelum app masuk background
      context.read<DietPlanProvider>().forceSaveSteps();
    }
  }

  Future<void> _initializeDietPlan() async {
    final authProvider = context.read<AuthProvider>();
    final dietPlanProvider = context.read<DietPlanProvider>();

    // Set user data dari auth provider
    if (authProvider.user != null) {
      dietPlanProvider.setUser(authProvider.user!);

      // Langkah 10: Set userId lokal agar steps bisa disimpan ke SQLite.
      // UserModel.id bertipe String (UUID dari backend), sedangkan SQLite
      // menggunakan INTEGER. Kita gunakan hashCode sebagai konversi yang konsisten
      // selama satu instalasi app — nilainya selalu sama untuk UUID yang sama.
      final userId = authProvider.user!.id.hashCode.abs();
      dietPlanProvider.setCurrentUserId(userId);
    }

    // Load food diary data untuk profil ibu (untuk kalkulasi kalori dikonsumsi)
    final foodDiaryProvider = context.read<FoodDiaryProvider>();
    foodDiaryProvider.setSelectedProfile('mother');
    await foodDiaryProvider.loadEntries();

    // Requirements: 5.6, 5.8 - Auto-start pedometer tracking saat screen dibuka
    // loadTodaySteps() sudah otomatis memulai sensor setelah load data dari DB
    if (dietPlanProvider.canCalculateDietPlan) {
      await dietPlanProvider.loadTodaySteps();
    }
  }

  @override
  void dispose() {
    // Hapus observer lifecycle agar tidak terjadi memory leak
    WidgetsBinding.instance.removeObserver(this);
    // Pedometer berjalan terus (always-on) — tidak di-stop saat screen di-dispose.
    // PedometerService hanya berhenti saat DietPlanProvider.dispose() dipanggil
    // ketika app benar-benar ditutup.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet Plan'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<DietPlanProvider>(
        builder: (context, dietPlanProvider, child) {
          // Requirement 5.11: Check if profile data is complete
          if (!dietPlanProvider.canCalculateDietPlan) {
            return _buildIncompleteDataView(dietPlanProvider);
          }

          // Show diet plan dashboard if data is complete
          return _buildDietPlanDashboard(dietPlanProvider);
        },
      ),
    );
  }

  /// Requirement 5.11: Display message to complete profile data
  Widget _buildIncompleteDataView(DietPlanProvider provider) {
    final missingFields = provider.missingProfileData;

    return RefreshIndicator(
      onRefresh: () async {
        await _initializeDietPlan();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning card
            Card(
              elevation: 2,
              color: Colors.orange[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data Profil Belum Lengkap',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Untuk menggunakan fitur Diet Plan, silakan lengkapi data profil Anda terlebih dahulu.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data yang perlu dilengkapi:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...missingFields.map((field) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Colors.orange[700],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getFieldLabel(field),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Physical data form
            PhysicalDataForm(
              onSaved: () async {
                await _initializeDietPlan();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data profil berhasil disimpan'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietPlanDashboard(DietPlanProvider provider) {
    return RefreshIndicator(
      onRefresh: () async {
        await _initializeDietPlan();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pedometer Controls - Requirements: 5.6, 5.7, 5.8
            const PedometerControls(),
            const SizedBox(height: 16),

            // Diet Plan Dashboard
            DietPlanDashboard(
              onEditProfile: () {
                _showEditProfileDialog();
              },
            ),
            const SizedBox(height: 16),

            // Info card
            Card(
              elevation: 1,
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kalori terbakar dari langkah kaki akan diperbarui secara otomatis',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Data Profil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PhysicalDataForm(
                onSaved: () async {
                  Navigator.of(dialogContext).pop();
                  await _initializeDietPlan();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data profil berhasil diperbarui'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'weight':
        return 'Berat Badan (kg)';
      case 'height':
        return 'Tinggi Badan (cm)';
      case 'age':
        return 'Usia (tahun)';
      default:
        return field;
    }
  }
}