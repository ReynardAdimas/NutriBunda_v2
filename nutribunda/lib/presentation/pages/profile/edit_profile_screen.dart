import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/profile_provider.dart';

/// Edit Profile Screen
/// Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _weightController   = TextEditingController();
  final _heightController   = TextEditingController();
  final _ageController      = TextEditingController();
  final _babyWeightController = TextEditingController();

  bool _isBreastfeeding = false;
  String _activityLevel = 'sedentary';
  String _timezone      = 'WIB';
  DateTime? _babyBirthDate;

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hanya load sekali saat pertama kali
    if (!_isInitialized) {
      _loadUserData();
      _isInitialized = true;
    }
  }

  void _loadUserData() {
    // ProfileProvider adalah sumber kebenaran tunggal untuk halaman profil
    final user = context.read<ProfileProvider>().user;
    if (user != null) {
      _nameController.text        = user.fullName;
      _weightController.text      = user.weight?.toString() ?? '';
      _heightController.text      = user.height?.toString() ?? '';
      _ageController.text         = user.age?.toString() ?? '';
      _isBreastfeeding            = user.isBreastfeeding;
      _activityLevel              = user.activityLevel;
      _timezone                   = user.timezone;
      _babyBirthDate              = user.babyBirthDate;
      _babyWeightController.text  = user.babyWeightKg?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _babyWeightController.dispose();
    super.dispose();
  }

  Future<void> _selectBabyBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _babyBirthDate ?? now.subtract(const Duration(days: 180)),
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
      helpText: 'Pilih Tanggal Lahir Bayi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _babyBirthDate = picked);
  }

  String _formatDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String? _babyAgeLabel() {
    if (_babyBirthDate == null) return null;
    final now = DateTime.now();
    final months = (now.year - _babyBirthDate!.year) * 12 +
        (now.month - _babyBirthDate!.month);
    if (months < 0) return null;
    return months < 24 ? '$months bulan' : '${months ~/ 12} thn ${months % 12} bln';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProfileProvider>();

    final weight      = double.tryParse(_weightController.text);
    final height      = double.tryParse(_heightController.text);
    final age         = int.tryParse(_ageController.text);
    final babyWeight  = _babyWeightController.text.isNotEmpty
        ? double.tryParse(_babyWeightController.text)
        : null;

    final success = await provider.updateProfile(
      fullName:        _nameController.text,
      weight:          weight,
      height:          height,
      age:             age,
      isBreastfeeding: _isBreastfeeding,
      activityLevel:   _activityLevel,
      timezone:        _timezone,
      babyBirthDate:   _babyBirthDate,
      babyWeightKg:    babyWeight,
    );

    if (!mounted) return;

    if (success) {
      // Re-fetch agar ProfileProvider punya data terbaru dari server
      await provider.fetchProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Gagal memperbarui profil')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── Nama ────────────────────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nama tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Berat Badan Ibu ──────────────────────────────────────
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Berat Badan (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monitor_weight),
                      helperText: 'Rentang: 30–200 kg',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final w = double.tryParse(v);
                      if (w == null) return 'Masukkan angka yang valid';
                      if (w < 30 || w > 200) return 'Harus antara 30–200 kg';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Tinggi Badan ─────────────────────────────────────────
                  TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: 'Tinggi Badan (cm)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                      helperText: 'Rentang: 100–250 cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final h = double.tryParse(v);
                      if (h == null) return 'Masukkan angka yang valid';
                      if (h < 100 || h > 250) return 'Harus antara 100–250 cm';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Usia ─────────────────────────────────────────────────
                  TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'Usia (tahun)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                      helperText: 'Rentang: 15–60 tahun',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final a = int.tryParse(v);
                      if (a == null) return 'Masukkan angka yang valid';
                      if (a < 15 || a > 60) return 'Harus antara 15–60 tahun';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Status Menyusui ──────────────────────────────────────
                  Card(
                    child: SwitchListTile(
                      title: const Text('Status Menyusui'),
                      subtitle: const Text('Sedang menyusui'),
                      value: _isBreastfeeding,
                      onChanged: (v) => setState(() => _isBreastfeeding = v),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tingkat Aktivitas ────────────────────────────────────
                  DropdownButtonFormField<String>(
                    value: _activityLevel,
                    decoration: const InputDecoration(
                      labelText: 'Tingkat Aktivitas',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_run),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'sedentary',         child: Text('Sedentary (Tidak Aktif)')),
                      DropdownMenuItem(value: 'lightly_active',    child: Text('Lightly Active (Ringan)')),
                      DropdownMenuItem(value: 'moderately_active', child: Text('Moderately Active (Sedang)')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _activityLevel = v); },
                  ),
                  const SizedBox(height: 16),

                  // ── Zona Waktu ───────────────────────────────────────────
                  DropdownButtonFormField<String>(
                    value: _timezone,
                    decoration: const InputDecoration(
                      labelText: 'Zona Waktu',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'WIB',    child: Text('WIB (UTC+7)')),
                      DropdownMenuItem(value: 'WITA',   child: Text('WITA (UTC+8)')),
                      DropdownMenuItem(value: 'WIT',    child: Text('WIT (UTC+9)')),
                      DropdownMenuItem(value: 'London', child: Text('London (UTC+0/+1)')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _timezone = v); },
                  ),

                  const SizedBox(height: 24),

                  // ════════════════════════════════════════════════════════
                  // SEKSI DATA BAYI
                  // ════════════════════════════════════════════════════════
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.child_care,
                            color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Data Bayi (MPASI)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Isi data bayi untuk kalkulasi target kalori MPASI yang akurat '
                    '(Holliday-Segar + WHO/IDAI). Jika dikosongkan, digunakan data statis WHO.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // ── Tanggal Lahir Bayi ───────────────────────────────────
                  GestureDetector(
                    onTap: _selectBabyBirthDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Lahir Bayi',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today),
                          hintText: 'Ketuk untuk memilih tanggal',
                          helperText: _babyBirthDate != null
                              ? 'Usia bayi: ${_babyAgeLabel()}'
                              : 'Opsional — untuk menghitung usia otomatis',
                          suffixIcon: _babyBirthDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _babyBirthDate = null),
                                )
                              : const Icon(Icons.edit_calendar_outlined),
                        ),
                        controller: TextEditingController(
                          text: _babyBirthDate != null ? _formatDate(_babyBirthDate!) : '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Berat Badan Bayi ─────────────────────────────────────
                  TextFormField(
                    controller: _babyWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Berat Badan Bayi (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                      hintText: 'Contoh: 8.5',
                      helperText: 'Opsional — rentang: 2–30 kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final w = double.tryParse(v);
                      if (w == null) return 'Masukkan angka yang valid (contoh: 8.5)';
                      if (w < 2 || w > 30) return 'Berat bayi harus antara 2–30 kg';
                      return null;
                    },
                  ),
                  // ════════════════════════════════════════════════════════

                  const SizedBox(height: 24),

                  // ── Tombol Simpan ────────────────────────────────────────
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan Perubahan'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}