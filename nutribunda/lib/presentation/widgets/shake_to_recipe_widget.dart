import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/accelerometer_service.dart';
import '../providers/recipe_provider.dart';
import '../pages/recipe/recipe_detail_screen.dart';

/// Widget untuk menampilkan shake-to-recipe feature
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
class ShakeToRecipeWidget extends StatefulWidget {
  const ShakeToRecipeWidget({super.key});

  @override
  State<ShakeToRecipeWidget> createState() => _ShakeToRecipeWidgetState();
}

class _ShakeToRecipeWidgetState extends State<ShakeToRecipeWidget>
    with SingleTickerProviderStateMixin {
  final AccelerometerService _accelerometerService = AccelerometerService();
  bool _isShakeEnabled = false;
  bool _isShaking = false;

  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticIn,
      ),
    );

    _startShakeDetection();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _accelerometerService.dispose();
    super.dispose();
  }

  /// FIX: Cek ketersediaan sensor setelah start, baru update flag
  void _startShakeDetection() {
    _accelerometerService.startListening(() {
      _onShakeDetected();
    });

    // FIX: set enabled hanya jika sensor benar-benar tersedia
    setState(() {
      _isShakeEnabled = _accelerometerService.isSensorAvailable;
    });
  }

  void _onShakeDetected() {
    if (!mounted || _isShaking) return;

    setState(() {
      _isShaking = true;
    });

    _animationController.repeat(reverse: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            const Text('Mencari resep acak...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );

    final recipeProvider = context.read<RecipeProvider>();
    recipeProvider.getRandomRecipe().then((_) {
      _animationController.stop();
      _animationController.reset();

      setState(() {
        _isShaking = false;
      });

      if (mounted && recipeProvider.currentRecipe != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              recipe: recipeProvider.currentRecipe!,
            ),
          ),
        );
      } else if (mounted && recipeProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(recipeProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Jika sensor tidak tersedia, tampilkan UI fallback
    if (!_isShakeEnabled && _accelerometerService.errorMessage != null) {
      return _buildSensorUnavailableUI();
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * (_isShaking ? 1 : 0), 0),
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isShaking
                            ? Icons.restaurant_menu
                            : Icons.phone_android,
                        size: 48,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isShaking ? 'Mencari Resep...' : 'Shake untuk Resep Acak',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isShaking
                          ? 'Mohon tunggu sebentar'
                          : 'Goyangkan smartphone Anda untuk mendapatkan resep MPASI acak!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// FIX: UI fallback saat sensor akselerometer tidak tersedia
  Widget _buildSensorUnavailableUI() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Fitur Shake Tidak Tersedia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Perangkat ini tidak memiliki sensor akselerometer '
                'yang diperlukan untuk fitur shake-to-recipe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              // Tombol fallback untuk tetap bisa akses resep acak
              ElevatedButton.icon(
                onPressed: _isShaking ? null : _onShakeDetected,
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: const Text('Tampilkan Resep Acak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}