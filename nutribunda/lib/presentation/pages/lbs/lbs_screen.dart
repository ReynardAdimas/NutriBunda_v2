import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/lbs_service.dart';

class LBSScreen extends StatefulWidget {
  const LBSScreen({super.key});

  @override
  State<LBSScreen> createState() => _LBSScreenState();
}

class _LBSScreenState extends State<LBSScreen> {

  final LbsService _lbsService = LbsService();

  bool _isLoading = false;
  String? _statusMessage;

  // ──────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────

  Future<void> _getLocationAndOpen(String facilityType) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final serviceEnabled = await _lbsService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showDialog(
          'Layanan Lokasi Nonaktif',
          'Aktifkan GPS / Layanan Lokasi di pengaturan perangkat kamu, lalu coba lagi.',
        );
      }
      return;
    }

    final position = await _lbsService.getCurrentPosition();

    if (!mounted) return;

    if (position == null) {
      final permission = await _lbsService.checkPermission();
      setState(() => _isLoading = false);
      if (permission == LocationPermission.deniedForever) {
        _showDialog(
          'Izin Lokasi Ditolak Permanen',
          'Buka Pengaturan → Aplikasi → NutriBunda → Izin, lalu aktifkan izin Lokasi.',
        );
      } else {
        _showDialog(
          'Izin Lokasi Diperlukan',
          'NutriBunda memerlukan izin lokasi untuk menemukan fasilitas kesehatan terdekat. '
              'Silakan izinkan akses lokasi saat diminta.',
        );
      }
      return;
    }

    setState(() {
      _isLoading = false;
      _statusMessage =
          'Lokasi: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    });

    await _lbsService.openNearbyByType(
        position.latitude, position.longitude, facilityType);
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(content,
            style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

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
                children: const [
                  Text(
                    'Peta Fasilitas Kesehatan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Ikon lokasi besar ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        size: 72, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Judul & deskripsi ──
                const Text(
                  'Temukan Fasilitas Kesehatan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Gunakan lokasi GPS kamu untuk menemukan rumah sakit, puskesmas, dan apotek terdekat melalui Google Maps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500, height: 1.5),
                ),
                const SizedBox(height: 32),

                // ── Tombol utama: Gunakan Lokasi Saya ──
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _getLocationAndOpen('puskesmas terdekat'),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location_rounded, size: 20),
                  label: Text(
                    _isLoading ? 'Mendapatkan Lokasi...' : 'Gunakan Lokasi Saya',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 3 tombol kategori fasilitas ──
                const Text(
                  'Cari berdasarkan kategori:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FacilityButton(
                        emoji: '🏥',
                        label: 'Rumah\nSakit',
                        onTap: _isLoading
                            ? null
                            : () => _getLocationAndOpen('rumah sakit terdekat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FacilityButton(
                        emoji: '🏪',
                        label: 'Puskesmas',
                        onTap: _isLoading
                            ? null
                            : () => _getLocationAndOpen('puskesmas terdekat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FacilityButton(
                        emoji: '💊',
                        label: 'Apotek',
                        onTap: _isLoading
                            ? null
                            : () => _getLocationAndOpen('apotek terdekat'),
                      ),
                    ),
                  ],
                ),

                // ── Status lokasi (muncul jika sudah dapat posisi) ──
                if (_statusMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed_rounded,
                            color: Colors.green.shade600, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Catatan footer ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.blue.shade400, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hasil pencarian akan dibuka di Google Maps. Pastikan Google Maps sudah terpasang di perangkat anda.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// WIDGET: Tombol kategori fasilitas
// ──────────────────────────────────────────

class _FacilityButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback? onTap;

  const _FacilityButton({
    required this.emoji,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
