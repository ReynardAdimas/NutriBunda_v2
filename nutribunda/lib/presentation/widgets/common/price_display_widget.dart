import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';

/// Widget untuk menampilkan harga makanan dengan konversi mata uang otomatis.
///
/// Gunakan widget ini di mana pun harga makanan ditampilkan agar konversi
/// berjalan konsisten di seluruh aplikasi.
///
/// Contoh penggunaan:
/// ```dart
/// PriceDisplay(priceIDR: food.estimatedPricePer100g ?? 0)
/// PriceDisplay(priceIDR: food.estimatedPricePer100g ?? 0, suffix: '/100g')
/// ```
class PriceDisplay extends StatelessWidget {
  final double priceIDR;
  final String? suffix;
  final TextStyle? style;
  final Color? color;

  const PriceDisplay({
    super.key,
    required this.priceIDR,
    this.suffix,
    this.style,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, _) {
        // Jika rate sedang dimuat dan bukan IDR, tampilkan loading kecil
        if (provider.isLoadingRate && provider.needsConversion) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 6),
              Text(
                'Memuat...',
                style: style ??
                    TextStyle(
                      fontSize: 13,
                      color: color ?? Colors.grey,
                    ),
              ),
            ],
          );
        }

        final formatted = provider.formatPrice(priceIDR);
        final displayText = suffix != null ? '$formatted$suffix' : formatted;

        return Text(
          displayText,
          style: style ??
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
        );
      },
    );
  }
}

/// Variant untuk menampilkan harga per serving size tertentu
class PriceDisplayForServing extends StatelessWidget {
  final double priceIDRPer100g;
  final double servingGrams;
  final TextStyle? style;
  final Color? color;

  const PriceDisplayForServing({
    super.key,
    required this.priceIDRPer100g,
    required this.servingGrams,
    this.style,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, _) {
        final formatted =
            provider.formatPriceForServing(priceIDRPer100g, servingGrams);

        return Text(
          formatted,
          style: style ??
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
        );
      },
    );
  }
}