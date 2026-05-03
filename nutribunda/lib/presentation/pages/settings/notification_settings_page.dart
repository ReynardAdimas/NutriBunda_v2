import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends State<NotificationSettingsPage> {

  @override
  void initState() {
    super.initState();
    // Ensure provider is initialized and permission is requested
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    });
  }

  Future<void> _pickVitaminTime(NotificationProvider provider) async {
    final parts = provider.vitaminTime.split(':');
    final currentTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFE91E8C)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await provider.setVitaminTime(timeStr);
    }
  }

  Widget _reminderTile({
    required String title,
    required String timeLabel,
    required IconData icon,
    required Color color,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    VoidCallback? onTimeTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: enabled ? onTimeTap : null,
                  child: Text(
                    onTimeTap != null
                        ? '$timeLabel • Ketuk untuk ubah'
                        : timeLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: enabled ? color : Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengingat Makan & Vitamin',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          // Show loading while initializing
          if (provider.isLoading && !provider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          // If permission not granted, show request button
          if (!provider.permissionGranted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Izin Notifikasi Diperlukan',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Untuk mengirim pengingat makan dan vitamin, aplikasi memerlukan izin notifikasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              final granted =
                                  await provider.requestPermissions();
                              if (!granted && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Izin notifikasi ditolak. Aktifkan di Pengaturan perangkat.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Izinkan Notifikasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Main settings UI
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Timezone Selector ─────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.public,
                          color: Colors.indigo, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Zona Waktu',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    DropdownButton<String>(
                      value: provider.timezone,
                      underline: const SizedBox(),
                      items: provider.timezoneOptions.map((tz) {
                        return DropdownMenuItem(
                          value: tz,
                          child: Text(tz,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          provider.changeTimezone(value);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── Section Label: MPASI ──────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text('Pengingat MPASI',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
              ),

              // Master MPASI toggle
              _reminderTile(
                title: 'Semua Pengingat MPASI',
                timeLabel: 'Aktifkan/nonaktifkan semua',
                icon: Icons.restaurant_menu,
                color: const Color(0xFFE91E8C),
                enabled: provider.mpasiEnabled,
                onToggle: (v) => provider.toggleMpasiNotifications(v),
              ),

              // Individual meal toggles (only when master is enabled)
              if (provider.mpasiEnabled) ...[
                // Sarapan — index 0
                _reminderTile(
                  title: 'Sarapan',
                  timeLabel: '07:00',
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFFE91E8C),
                  enabled: provider.mpasiMeals[0],
                  onToggle: (v) => provider.toggleMpasiMeal(0, v),
                ),
                // Makan Siang — index 1
                _reminderTile(
                  title: 'Makan Siang',
                  timeLabel: '12:00',
                  icon: Icons.lunch_dining_outlined,
                  color: const Color(0xFFFF9800),
                  enabled: provider.mpasiMeals[1],
                  onToggle: (v) => provider.toggleMpasiMeal(1, v),
                ),
                // Makan Sore — index 2
                _reminderTile(
                  title: 'Makan Sore',
                  timeLabel: '17:00',
                  icon: Icons.cookie_outlined,
                  color: const Color(0xFF4CAF50),
                  enabled: provider.mpasiMeals[2],
                  onToggle: (v) => provider.toggleMpasiMeal(2, v),
                ),
                // Makan Malam — index 3
                _reminderTile(
                  title: 'Makan Malam',
                  timeLabel: '19:00',
                  icon: Icons.dinner_dining_outlined,
                  color: const Color(0xFF9C27B0),
                  enabled: provider.mpasiMeals[3],
                  onToggle: (v) => provider.toggleMpasiMeal(3, v),
                ),
              ],

              const SizedBox(height: 8),

              // ── Section Label: Vitamin ─────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text('Pengingat Vitamin',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
              ),

              // Vitamin toggle
              _reminderTile(
                title: 'Minum Vitamin',
                timeLabel: provider.formatTimeForDisplay(provider.vitaminTime),
                icon: Icons.medication_outlined,
                color: const Color(0xFF2196F3),
                enabled: provider.vitaminEnabled,
                onToggle: (v) => provider.toggleVitaminNotifications(v),
                onTimeTap: () => _pickVitaminTime(provider),
              ),

              const SizedBox(height: 16),

              // ── Status summary ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.getNotificationSummary(),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}