import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';

/// Edit Profile Screen dengan form untuk edit data profil dan upload foto
/// Requirements: 12.1, 12.2, 12.3, 12.4, 12.5 - Edit profil dan upload foto
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _babyWeightController = TextEditingController();

  bool _isBreastfeeding = false;
  String _activityLevel = 'sedentary';
  String _timezone = 'WIB';

  // Data bayi
  DateTime? _babyBirthDate;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    // Baca dari AuthProvider karena dashboard juga membaca dari sini
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user ??
        context.read<ProfileProvider>().user; // fallback ke ProfileProvider

    if (user != null) {
      _nameController.text = user.fullName;
      _weightController.text = user.weight?.toString() ?? '';
      _heightController.text = user.height?.toString() ?? '';
      _ageController.text = user.age?.toString() ?? '';
      _isBreastfeeding = user.isBreastfeeding;
      _activityLevel = user.activityLevel;
      _timezone = user.timezone;

      // Load baby data
      _babyBirthDate = user.babyBirthDate;
      _babyWeightController.text = user.babyWeightKg?.toString() ?? '';
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

  /// Tampilkan date picker untuk tanggal lahir bayi
  Future<void> _selectBabyBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _babyBirthDate ?? now.subtract(const Duration(days: 180)),
      firstDate: now.subtract(const Duration(days: 730)), // maks 2 tahun lalu
      lastDate: now,
      helpText: 'Pilih Tanggal Lahir Bayi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      setState(() {
        _babyBirthDate = picked;
      });
    }
  }

  /// Format tanggal lahir bayi untuk ditampilkan
  String _formatBabyBirthDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Hitung usia bayi dalam bulan sebagai helper text
  String? _getBabyAgeLabel() {
    if (_babyBirthDate == null) return null;
    final now = DateTime.now();
    final months =
        (now.year - _babyBirthDate!.year) * 12 +
        (now.month - _babyBirthDate!.month);
    if (months < 0) return null;
    if (months < 24) return '$months bulan';
    return '${months ~/ 12} tahun ${months % 12} bulan';
  }

  /// Save profile changes
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Gunakan AuthProvider agar _user di dalamnya terupdate,
    // sehingga dashboard_screen yang membaca AuthProvider.user
    // langsung mendapat data bayi terbaru tanpa perlu restart.
    final authProvider = context.read<AuthProvider>();

    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final age = int.tryParse(_ageController.text);
    final babyWeightKg = _babyWeightController.text.isNotEmpty
        ? double.tryParse(_babyWeightController.text)
        : null;

    final success = await authProvider.updateProfile(
      fullName: _nameController.text,
      weight: weight,
      height: height,
      age: age,
      isBreastfeeding: _isBreastfeeding,
      activityLevel: _activityLevel,
      timezone: _timezone,
      babyBirthDate: _babyBirthDate,
      babyWeightKg: babyWeightKg,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Gagal memperbarui profil',
          ),
        ),
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
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nama lengkap tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Weight Field
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Berat Badan (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monitor_weight),
                      helperText: 'Rentang: 30-200 kg',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final weight = double.tryParse(value);
                      if (weight == null) return 'Masukkan angka yang valid';
                      if (weight < 30 || weight > 200) {
                        return 'Berat badan harus antara 30-200 kg';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Height Field
                  TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: 'Tinggi Badan (cm)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                      helperText: 'Rentang: 100-250 cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final height = double.tryParse(value);
                      if (height == null) return 'Masukkan angka yang valid';
                      if (height < 100 || height > 250) {
                        return 'Tinggi badan harus antara 100-250 cm';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Age Field
                  TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'Usia (tahun)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                      helperText: 'Rentang: 15-60 tahun',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final age = int.tryParse(value);
                      if (age == null) return 'Masukkan angka yang valid';
                      if (age < 15 || age > 60) {
                        return 'Usia harus antara 15-60 tahun';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Breastfeeding Status
                  Card(
                    child: SwitchListTile(
                      title: const Text('Status Menyusui'),
                      subtitle: const Text('Sedang menyusui'),
                      value: _isBreastfeeding,
                      onChanged: (value) {
                        setState(() => _isBreastfeeding = value);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Activity Level Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _activityLevel,
                    decoration: const InputDecoration(
                      labelText: 'Tingkat Aktivitas',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_run),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'sedentary',
                        child: Text('Sedentary (Tidak Aktif)'),
                      ),
                      DropdownMenuItem(
                        value: 'lightly_active',
                        child: Text('Lightly Active (Ringan)'),
                      ),
                      DropdownMenuItem(
                        value: 'moderately_active',
                        child: Text('Moderately Active (Sedang)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _activityLevel = value);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Timezone Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _timezone,
                    decoration: const InputDecoration(
                      labelText: 'Zona Waktu',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'WIB', child: Text('WIB (UTC+7)')),
                      DropdownMenuItem(value: 'WITA', child: Text('WITA (UTC+8)')),
                      DropdownMenuItem(value: 'WIT', child: Text('WIT (UTC+9)')),
                      DropdownMenuItem(value: 'London', child: Text('London (UTC+0/+1)')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _timezone = value);
                    },
                  ),

                  const SizedBox(height: 24),

                  // ─── Seksi Data Bayi ───────────────────────────────────
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.child_care,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Data Bayi (MPASI)',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Isi data bayi untuk kalkulasi target kalori MPASI yang akurat '
                    '(metode Holliday-Segar / WHO). Jika dikosongkan, app akan '
                    'menggunakan data standar WHO sebagai fallback.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),

                  const SizedBox(height: 16),

                  // Tanggal Lahir Bayi — tap-to-pick
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
                              ? 'Usia bayi saat ini: ${_getBabyAgeLabel()}'
                              : 'Opsional — untuk menghitung usia otomatis',
                          suffixIcon: _babyBirthDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Hapus tanggal',
                                  onPressed: () =>
                                      setState(() => _babyBirthDate = null),
                                )
                              : const Icon(Icons.edit_calendar_outlined),
                        ),
                        controller: TextEditingController(
                          text: _babyBirthDate != null
                              ? _formatBabyBirthDate(_babyBirthDate!)
                              : '',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Berat Badan Bayi
                  TextFormField(
                    controller: _babyWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Berat Badan Bayi (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                      hintText: 'Contoh: 8.5',
                      helperText: 'Opsional — rentang: 2–30 kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final w = double.tryParse(value);
                      if (w == null) {
                        return 'Masukkan angka yang valid (contoh: 8.5)';
                      }
                      if (w < 2 || w > 30) {
                        return 'Berat bayi harus antara 2–30 kg';
                      }
                      return null;
                    },
                  ),
                  // ──────────────────────────────────────────────────────

                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
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