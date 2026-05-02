import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/food_diary_provider.dart';
import '../../widgets/diary/food_search_widget.dart';
import '../../../data/models/food_model.dart';
import '../../widgets/common/price_display_widget.dart';

/// Add Diary Entry Screen
/// Requirements: 4.2, 4.4 - Food search, manual entry, meal time selection
class AddDiaryEntryScreen extends StatefulWidget {
  const AddDiaryEntryScreen({Key? key}) : super(key: key);

  @override
  State<AddDiaryEntryScreen> createState() => _AddDiaryEntryScreenState();
}

class _AddDiaryEntryScreenState extends State<AddDiaryEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  FoodModel? _selectedFood;
  String? _customFoodName;
  final _servingSizeController = TextEditingController();
  String _selectedMealTime = 'breakfast';
  DateTime _selectedDate = DateTime.now();
  bool _isManualEntry = false;

  // Manual nutrition entry controllers
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize with provider's selected date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FoodDiaryProvider>();
      setState(() {
        _selectedDate = provider.selectedDate;
      });
    });
  }

  @override
  void dispose() {
    _servingSizeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FoodDiaryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Makanan'),
        actions: [
          TextButton(
            onPressed: _isManualEntry
                ? () {
                    setState(() {
                      _isManualEntry = false;
                      _customFoodName = null;
                      _caloriesController.clear();
                      _proteinController.clear();
                      _carbsController.clear();
                      _fatController.clear();
                    });
                  }
                : () {
                    setState(() {
                      _isManualEntry = true;
                      _selectedFood = null;
                    });
                  },
            child: Text(
              _isManualEntry ? 'Pilih dari Database' : 'Input Manual',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Profile Type Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      provider.selectedProfile == 'baby'
                          ? Icons.child_care
                          : Icons.person,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Profil: ${provider.selectedProfile == 'baby' ? 'Bayi' : 'Ibu'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Food Selection or Manual Entry
            if (!_isManualEntry) ...[
              const Text(
                'Pilih Makanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              FoodSearchWidget(
                onFoodSelected: (food) {
                  setState(() {
                    _selectedFood = food;
                  });
                },
                category:
                    provider.selectedProfile == 'baby' ? 'mpasi' : 'ibu',
              ),
              if (_selectedFood != null) ...[
                const SizedBox(height: 16),
                _buildSelectedFoodCard(),
              ],
            ] else ...[
              const Text(
                'Nama Makanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Masukkan nama makanan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama makanan harus diisi';
                  }
                  return null;
                },
                onSaved: (value) {
                  _customFoodName = value;
                },
              ),
              const SizedBox(height: 16),
              _buildManualNutritionInputs(),
            ],

            const SizedBox(height: 24),

            // Serving Size
            const Text(
              'Porsi (gram)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _servingSizeController,
              decoration: const InputDecoration(
                hintText: 'Contoh: 100',
                border: OutlineInputBorder(),
                suffixText: 'gram',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              // Rebuild nutrition preview saat serving size berubah
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Porsi harus diisi';
                }
                final size = double.tryParse(value);
                if (size == null || size <= 0) {
                  return 'Porsi harus lebih dari 0';
                }
                return null;
              },
            ),

            // Nutrition Preview (for database food)
            if (_selectedFood != null &&
                _servingSizeController.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNutritionPreview(),
            ],

            const SizedBox(height: 24),

            // Meal Time
            const Text(
              'Waktu Makan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildMealTimeSelector(),

            const SizedBox(height: 24),

            // Date
            const Text(
              'Tanggal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                          .format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitEntry,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Simpan',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFoodCard() {
    if (_selectedFood == null) return const SizedBox.shrink();

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFood!.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedFood = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Per 100g: ${_selectedFood!.caloriesPer100g.toStringAsFixed(1)} kkal',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualNutritionInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informasi Nutrisi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Kalori',
                  border: OutlineInputBorder(),
                  suffixText: 'kkal',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (_isManualEntry && (value == null || value.isEmpty)) {
                    return 'Wajib diisi';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _proteinController,
                decoration: const InputDecoration(
                  labelText: 'Protein',
                  border: OutlineInputBorder(),
                  suffixText: 'g',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (_isManualEntry && (value == null || value.isEmpty)) {
                    return 'Wajib diisi';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _carbsController,
                decoration: const InputDecoration(
                  labelText: 'Karbohidrat',
                  border: OutlineInputBorder(),
                  suffixText: 'g',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (_isManualEntry && (value == null || value.isEmpty)) {
                    return 'Wajib diisi';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _fatController,
                decoration: const InputDecoration(
                  labelText: 'Lemak',
                  border: OutlineInputBorder(),
                  suffixText: 'g',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (_isManualEntry && (value == null || value.isEmpty)) {
                    return 'Wajib diisi';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionPreview() {
    final servingSize = double.tryParse(_servingSizeController.text) ?? 0;
    if (servingSize <= 0 || _selectedFood == null) {
      return const SizedBox.shrink();
    }

    final nutrition = _selectedFood!.calculateNutrition(servingSize);
    final hasPrice = _selectedFood!.estimatedPricePer100g != null;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Judul ──────────────────────────────────────────────────────
            const Text(
              'Nutrisi untuk porsi ini:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            // ── Baris Nutrisi ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientInfo(
                    'Kalori', '${nutrition.calories.toStringAsFixed(1)} kkal'),
                _buildNutrientInfo(
                    'Protein', '${nutrition.protein.toStringAsFixed(1)}g'),
                _buildNutrientInfo(
                    'Karbo', '${nutrition.carbs.toStringAsFixed(1)}g'),
                _buildNutrientInfo(
                    'Lemak', '${nutrition.fat.toStringAsFixed(1)}g'),
              ],
            ),

            // ── Estimasi Harga (Step 7b) ───────────────────────────────────
            // Hanya tampil jika data harga tersedia di database
            if (hasPrice) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Estimasi Harga',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Widget ini otomatis konversi ke mata uang pilihan user
                  // via CurrencyProvider. Fallback ke IDR jika rate belum ada.
                  PriceDisplayForServing(
                    priceIDRPer100g: _selectedFood!.estimatedPricePer100g!,
                    servingGrams: servingSize,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    color: Colors.green[700],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Keterangan satuan agar user tidak bingung
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'untuk ${servingSize.toStringAsFixed(0)}g porsi',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMealTimeSelector() {
    final mealTimes = [
      {'value': 'breakfast', 'label': 'Makan Pagi', 'icon': Icons.wb_sunny},
      {
        'value': 'lunch',
        'label': 'Makan Siang',
        'icon': Icons.wb_sunny_outlined
      },
      {'value': 'dinner', 'label': 'Makan Malam', 'icon': Icons.nightlight},
      {'value': 'snack', 'label': 'Selingan', 'icon': Icons.cookie},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mealTimes.map((mealTime) {
        final isSelected = _selectedMealTime == mealTime['value'];
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mealTime['icon'] as IconData,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Text(mealTime['label'] as String),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedMealTime = mealTime['value'] as String;
              });
            }
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    // Validate food selection
    if (!_isManualEntry && _selectedFood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih makanan dari database'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final provider = context.read<FoodDiaryProvider>();
    final servingSize = double.parse(_servingSizeController.text);

    final success = await provider.addEntry(
      profileType: provider.selectedProfile,
      foodId: _selectedFood?.id,
      customFoodName: _customFoodName,
      servingSize: servingSize,
      mealTime: _selectedMealTime,
      entryDate: _selectedDate,
      calories:
          _isManualEntry ? double.parse(_caloriesController.text) : null,
      protein:
          _isManualEntry ? double.parse(_proteinController.text) : null,
      carbs: _isManualEntry ? double.parse(_carbsController.text) : null,
      fat: _isManualEntry ? double.parse(_fatController.text) : null,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (success && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Makanan berhasil ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Gagal menambahkan makanan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}