import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/diet_plan_provider.dart';

/// Pedometer Widget — Smartwatch Style
///
/// Tidak ada tombol mulai/berhenti/reset.
/// Pedometer berjalan terus-menerus secara otomatis.
/// Notifikasi dikirim setiap kelipatan 100 langkah.
/// Reset otomatis terjadi setiap tengah malam.
///
/// Requirements: 5.6, 5.7, 5.8
class PedometerControls extends StatelessWidget {
  const PedometerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DietPlanProvider>(
      builder: (context, provider, child) {
        final hasError = provider.pedometerError != null;
        final steps = provider.steps;
        final caloriesBurned = provider.caloriesBurned;
        final pedestrianStatus =
            provider.pedometerService.pedestrianStatus;

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
                // Header
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
                    _buildStatusBadge(
                        context, pedestrianStatus, hasError),
                  ],
                ),

                const SizedBox(height: 16),

                // Error message (jika ada)
                if (hasError) ...[
                  _buildErrorMessage(context, provider.pedometerError!),
                  const SizedBox(height: 16),
                ],

                // Step display utama
                _buildStepDisplay(
                    context, steps, caloriesBurned, pedestrianStatus),

                const SizedBox(height: 12),

                // Info reset harian
                _buildDailyResetInfo(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Badge status berjalan/berhenti/error — seperti indikator smartwatch
  Widget _buildStatusBadge(
    BuildContext context,
    String pedestrianStatus,
    bool hasError,
  ) {
    Color color;
    String label;
    IconData icon;

    if (hasError) {
      color = Colors.red;
      label = 'Error';
      icon = Icons.error_outline;
    } else if (pedestrianStatus == 'walking') {
      color = Colors.green;
      label = 'Berjalan';
      icon = Icons.directions_walk;
    } else if (pedestrianStatus == 'stopped') {
      color = Colors.blueGrey;
      label = 'Istirahat';
      icon = Icons.pause_circle_outline;
    } else {
      // 'unknown' — sensor aktif tapi belum ada data gerak
      color = Colors.teal;
      label = 'Aktif';
      icon = Icons.sensors;
    }

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
          // Dot animasi kecil saat berjalan
          if (pedestrianStatus == 'walking' && !hasError)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PulsingDot(color: color),
            ),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
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
          Icon(Icons.warning_amber_rounded,
              color: Colors.red[700], size: 20),
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

  /// Tampilan langkah utama — desain smartwatch-style
  Widget _buildStepDisplay(
    BuildContext context,
    int steps,
    double caloriesBurned,
    String pedestrianStatus,
  ) {
    final isWalking = pedestrianStatus == 'walking';
    final nextMilestone = ((steps ~/ 100) + 1) * 100;
    final progressToNext =
        steps == 0 ? 0.0 : ((steps % 100) / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.12),
            Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Angka langkah
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isWalking)
                const Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 12),
                  child: _PulsingDot(color: Colors.green),
                ),
              Text(
                steps.toString(),
                style: TextStyle(
                  fontSize: 52,
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

          const SizedBox(height: 8),

          // Progress bar ke milestone berikutnya
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menuju $nextMilestone langkah',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${(progressToNext * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressToNext,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Kalori terbakar
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

  /// Info kecil bahwa pedometer reset otomatis tiap malam
  Widget _buildDailyResetInfo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          'Langkah direset otomatis setiap tengah malam',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}

/// Pulsing dot animation
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({this.color = Colors.green});

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

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color
                    .withValues(alpha: _animation.value * 0.5),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}