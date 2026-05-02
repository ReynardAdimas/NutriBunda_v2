import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/food_diary_provider.dart';
import '../../../data/models/food_model.dart';
import '../common/price_display_widget.dart';

/// Food Search Widget with Autocomplete
/// Requirements: 4.2 - Food search dengan autocomplete
class FoodSearchWidget extends StatefulWidget {
  final Function(FoodModel) onFoodSelected;
  final String? category;

  const FoodSearchWidget({
    Key? key,
    required this.onFoodSelected,
    this.category,
  }) : super(key: key);

  @override
  State<FoodSearchWidget> createState() => _FoodSearchWidgetState();
}

class _FoodSearchWidgetState extends State<FoodSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String _formatPrice(double price) {
    final formatted = price.toStringAsFixed(0); 
    final buffer = StringBuffer(); 
    int cnt = 0; 
    for(int i=formatted.length-1;i>=0;i--)
    {
      if(cnt >0 && cnt %3==0) buffer.write('.');
      buffer.write(formatted[i]);
      cnt++;
    }
    return buffer.toString().split('').reversed.join('');
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start new timer for debouncing
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        context.read<FoodDiaryProvider>().searchFoods(
              query,
              category: widget.category,
            );
      } else {
        context.read<FoodDiaryProvider>().clearSearchResults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FoodDiaryProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search TextField
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari makanan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          provider.clearSearchResults();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),

            // Loading indicator
            if (provider.isLoadingFoods) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],

            // Search results
            if (!provider.isLoadingFoods && provider.searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: provider.searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final food = provider.searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.restaurant,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      title: Text(
                        food.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        children: [
                          Text(
                            '${food.caloriesPer100g.toStringAsFixed(1)} kkal per 100g',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ), 
                          if(food.estimatedPricePer100g != null) 
                            PriceDisplay(
                              priceIDR: food.estimatedPricePer100g!, 
                              suffix: '/100g',
                              style: const TextStyle(fontSize: 13),
                              color: Colors.green.shade700,
                            )
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        widget.onFoodSelected(food);
                        _searchController.clear();
                        provider.clearSearchResults();
                      },
                    );
                  },
                ),
              ),
            ],

            // No results message
            if (!provider.isLoadingFoods &&
                _searchController.text.isNotEmpty &&
                provider.searchResults.isEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada hasil untuk "${_searchController.text}"',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
