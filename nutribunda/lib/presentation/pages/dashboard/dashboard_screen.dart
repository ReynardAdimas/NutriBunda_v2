import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/food_diary_provider.dart';
import '../../providers/diet_plan_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/dashboard/nutrition_progress_bar.dart';
import '../../widgets/dashboard/nutrition_chart.dart';
import '../../widgets/shake_to_recipe_widget.dart';
import '../../widgets/diet_plan/pedometer_controls.dart';
import '../../widgets/diet_plan/diet_plan_dashboard.dart';
import '../recipe/favorite_recipes_screen.dart';
import '../chat/chat_screen.dart';
import '../quiz_screen.dart';
import '../settings/notification_settings_page.dart';
import 'notification_center_screen.dart';
import '../../../core/services/nutrition_tracker_service.dart';
import '../../../data/models/nutrition_summary.dart';

/// Dashboard screen dengan nutrition summary untuk baby dan mother
/// Requirements: 4.6, 13.2 - Display daily nutrition summary on Dashboard
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  NutritionSummary? _babySummary;
  NutritionSummary? _motherSummary;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Load data for both profiles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _initializeDietPlan();
    });

    // Auto-refresh setiap 60 detik
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh ketika kembali ke halaman ini (misalnya setelah tambah diary)
    // Hanya refresh jika sudah ada data sebelumnya (bukan load pertama)
    if (_babySummary != null || _motherSummary != null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDietPlan() async {
    final authProvider = context.read<AuthProvider>();
    final dietPlanProvider = context.read<DietPlanProvider>();

    // Fix #1: Set currentUserId SEBELUM loadTodaySteps dipanggil,
    // agar guard `if (_currentUserId == null) return;` tidak memblokir.
    if (authProvider.user != null) {
      dietPlanProvider.setUser(authProvider.user!);

      final userId = authProvider.user!.id.hashCode.abs();
      dietPlanProvider.setCurrentUserId(userId);
      
    }

    // Fix #2: Minta permission ACTIVITY_RECOGNITION sebelum memulai pedometer.
    // Permission ini wajib ada di Android 10+ (API 29+) agar sensor berfungsi.
    if (dietPlanProvider.canCalculateDietPlan) {
      final status = await Permission.activityRecognition.request();
      if (status.isGranted) {
        dietPlanProvider.loadTodaySteps();
      } else if (status.isPermanentlyDenied) {
        // Arahkan ke settings jika user menolak permanen
        openAppSettings();
      }
      // Jika hanya ditolak (bukan permanen), pedometer tidak dijalankan
      // tapi app tetap berfungsi normal
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<FoodDiaryProvider>();
      
      // Load baby profile data
      provider.setSelectedProfile('baby');
      await provider.loadEntries();
      _babySummary = provider.nutritionSummary;
      
      // Load mother profile data
      provider.setSelectedProfile('mother');
      await provider.loadEntries();
      _motherSummary = provider.nutritionSummary;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AppBar manual
        Container(
          color: Theme.of(context).colorScheme.primary,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationCenterScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // Body
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 400,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 400,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<FoodDiaryProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              _buildDateHeader(context, provider),
              const SizedBox(height: 24),

              // Diet Plan & Pedometer Section
              _buildDietPlanSection(context),
              const SizedBox(height: 24),

              // Baby nutrition summary
              if (_babySummary != null)
                _buildProfileSection(
                  context,
                  'baby',
                  'Nutrisi Bayi',
                  Icons.child_care,
                  Colors.blue,
                  _babySummary!,
                ),
              const SizedBox(height: 24),

              // Mother nutrition summary
              if (_motherSummary != null)
                _buildProfileSection(
                  context,
                  'mother',
                  'Nutrisi Ibu',
                  Icons.person,
                  Colors.pink,
                  _motherSummary!,
                ),
              const SizedBox(height: 24),

              // Shake-to-Recipe widget
              const ShakeToRecipeWidget(),
              const SizedBox(height: 24),

              // Quick actions
              _buildQuickActions(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(BuildContext context, FoodDiaryProvider provider) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final dateStr = dateFormat.format(provider.selectedDate);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Hari Ini',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                provider.setSelectedDate(
                  provider.selectedDate.subtract(const Duration(days: 1)),
                );
                _loadData();
              },
              tooltip: 'Hari Sebelumnya',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                provider.setSelectedDate(
                  provider.selectedDate.add(const Duration(days: 1)),
                );
                _loadData();
              },
              tooltip: 'Hari Berikutnya',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietPlanSection(BuildContext context) {
    return Consumer<DietPlanProvider>(
      builder: (context, dietPlanProvider, child) {
        // Check if user profile data is complete
        if (!dietPlanProvider.canCalculateDietPlan) {
          return Card(
            elevation: 2,
            color: Colors.blue[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_walk,
                    size: 48,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Diet Plan & Pedometer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lengkapi data profil Anda (berat badan, tinggi badan, usia) untuk menggunakan fitur ini',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to profile screen
                      Navigator.pushNamed(context, '/profile');
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('Lengkapi Profil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show Diet Plan and Pedometer if profile is complete
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Diet Plan & Aktivitas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pedometer Controls
            const PedometerControls(),
            const SizedBox(height: 16),

            // Diet Plan Dashboard (compact version for home)
            const DietPlanDashboard(
              compact: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileSection(
    BuildContext context,
    String profileType,
    String title,
    IconData icon,
    Color color,
    NutritionSummary summary,
  ) {
    final progress = NutritionTrackerService.calculateProgress(
      summary: summary,
      profileType: profileType,
    );

    // Check if target exceeded
    final hasWarning = NutritionTrackerService.hasExceededTarget(progress);
    final warningMessage = NutritionTrackerService.getWarningMessage(progress);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Target Harian',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Warning message if exceeded
            if (hasWarning) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Chart and legend
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Chart
                NutritionChart(
                  progress: progress,
                  size: 140,
                ),
                const SizedBox(width: 20),

                // Legend
                Expanded(
                  child: NutritionChartLegend(
                    progress: progress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Progress bars
            NutritionProgressBars(
              progress: progress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aksi Cepat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            // Quiz Game button
            SizedBox(
              width: double.infinity,
              child: _buildQuickActionButton(
                context,
                'Kuis Gizi Bunda - Uji Pengetahuan',
                Icons.quiz,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuizScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // TanyaBunda AI button
            SizedBox(
              width: double.infinity,
              child: _buildQuickActionButton(
                context,
                'TanyaBunda AI - Konsultasi Gizi',
                Icons.smart_toy,
                Colors.green,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Favorite recipes button
            SizedBox(
              width: double.infinity,
              child: _buildQuickActionButton(
                context,
                'Resep Favorit',
                Icons.favorite,
                Colors.red,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteRecipesScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Notification settings button
            SizedBox(
              width: double.infinity,
              child: _buildQuickActionButton(
                context,
                'Pengaturan Notifikasi',
                Icons.notifications_active,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationSettingsPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
