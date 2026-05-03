import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/diet_plan_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pedometer Controls Widget
/// Requirements: 5.6, 5.7, 5.8 - UI controls untuk pedometer tracking
class PedometerControls extends StatelessWidget {
  const PedometerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DietPlanProvider>(
      builder: (context, provider, child) {
        final isActive = provider.isPedometerActive;
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
                // Header with status indicator
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
                    _buildStatusIndicator(context, isActive, hasError),
                  ],
                ),
                const SizedBox(height: 16),

                // Error message if any
                if (hasError) ...[
                  _buildErrorMessage(context, provider.pedometerError!),
                  const SizedBox(height: 16),
                ],

                // Step count display with animation
                _buildStepDisplay(context, steps, caloriesBurned, isActive),
                const SizedBox(height: 16),

                // Control buttons
                _buildControlButtons(context, provider, isActive),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Status indicator showing active/stopped state
  /// Requirements: 5.8 - Menampilkan status tracking
  Widget _buildStatusIndicator(
    BuildContext context,
    bool isActive,
    bool hasError,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (hasError) {
      statusColor = Colors.red;
      statusText = 'Error';
      statusIcon = Icons.error_outline;
    } else if (isActive) {
      statusColor = Colors.green;
      statusText = 'Aktif';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.grey;
      statusText = 'Berhenti';
      statusIcon = Icons.pause_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Error message display
  /// Requirements: 5.8 - Error handling dan user feedback
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
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedometer Error',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Step count display with real-time visual indicator
  /// Requirements: 5.8 - Visual indicator untuk real-time step updates
  Widget _buildStepDisplay(
    BuildContext context,
    int steps,
    double caloriesBurned,
    bool isActive,
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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Steps count with pulsing animation when active
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isActive)
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calories burned
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.whatshot,
                  size: 18,
                  color: Colors.orange[700],
                ),
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

  /// Control buttons for start/stop/reset
  /// Requirements: 5.8 - Start/stop/reset controls
  Widget _buildControlButtons(
    BuildContext context,
    DietPlanProvider provider,
    bool isActive,
  ) {
    return Row(
      children: [
        // Start/Stop button
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              if (isActive) {
                provider.stopPedometerTracking();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pedometer dihentikan'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                _startPedometerWithPermissionCheck(context, provider);
              }
            },
            icon: Icon(
              isActive ? Icons.pause : Icons.play_arrow,
              size: 20,
            ),
            label: Text(
              isActive ? 'Berhenti' : 'Mulai',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? Colors.orange
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Reset button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _showResetConfirmation(context, provider);
            },
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text(
              'Reset',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.grey[400]!),
            ),
          ),
        ),
      ],
    );
  }

  /// Start pedometer with permission check
  /// Requirements: 5.8 - Permission handling UI untuk sensor akses
  void _startPedometerWithPermissionCheck(
  BuildContext context,
  DietPlanProvider provider,
) async {
  final status = await Permission.activityRecognition.request();

  if (!context.mounted) return;

  if (status.isGranted) {
    provider.startPedometerTracking();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedometer dimulai')),
    );
  } else {
    _showPermissionDialog(context, 'Izin sensor aktivitas diperlukan untuk menghitung langkah kaki.');
  }
}

  /// Show permission dialog when sensor access is denied
  /// Requirements: 5.8 - Permission handling UI
  void _showPermissionDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.sensors_off, color: Colors.orange),
            SizedBox(width: 12),
            Text('Izin Sensor Diperlukan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Untuk menggunakan pedometer:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPermissionStep('1', 'Buka Pengaturan perangkat'),
                  _buildPermissionStep('2', 'Pilih Aplikasi > NutriBunda'),
                  _buildPermissionStep('3', 'Aktifkan izin Sensor Aktivitas'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // In a real app, you would open app settings here
              // using a package like app_settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Silakan aktifkan izin sensor di pengaturan'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            label: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show reset confirmation dialog
  void _showResetConfirmation(
    BuildContext context,
    DietPlanProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Reset Pedometer?'),
        content: const Text(
          'Apakah Anda yakin ingin mereset hitungan langkah hari ini? '
          'Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.resetDailySteps();
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pedometer telah direset'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

/// Pulsing dot animation for real-time indicator
/// Requirements: 5.8 - Visual indicator untuk real-time updates
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
                color: Colors.green.withValues(alpha: _animation.value * 0.5),
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
