import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../../core/services/currency_service.dart';

/// Halaman untuk memilih mata uang tampilan harga makanan
class CurrencySettingsPage extends StatelessWidget {
  const CurrencySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mata Uang Harga'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Consumer<CurrencyProvider>(
            builder: (context, provider, _) {
              return IconButton( 
                icon: provider.isLoadingRate
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(Icons.refresh), 
                tooltip: 'Refresh Kurs',
                onPressed: provider.isLoadingRate
                  ? null
                  : () => provider.refreshRate(),
              );
            }
          )
        ],
      ),
      body: Consumer<CurrencyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingCurrencies) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat daftar mata uang...'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Info banner
              _buildInfoBanner(context, provider),

              // Daftar mata uang
              Expanded(
                child: provider.supportedCurrencies.isEmpty
                    ? _buildEmptyState(context, provider)
                    : _buildCurrencyList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context, CurrencyProvider provider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.currency_exchange,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Mata Uang Aktif',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mata uang saat ini: ${provider.selectedCurrency}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (provider.currentRate != null && provider.needsConversion)
            Text(
              '1 IDR ≈ ${provider.currentRate!.toStringAsFixed(6)} ${provider.selectedCurrency}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          if (provider.isLoadingRate)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Mengambil kurs terbaru...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrencyList(BuildContext context, CurrencyProvider provider) {
    return ListView.builder(
      itemCount: provider.supportedCurrencies.length,
      itemBuilder: (context, index) {
        final currency = provider.supportedCurrencies[index];
        final isSelected = currency.code == provider.selectedCurrency;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade200,
            child: Text(
              currency.code.substring(0, 2),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
          title: Text(
            currency.code,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(currency.name),
          trailing: isSelected
              ? Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () => _onCurrencySelected(context, provider, currency),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, CurrencyProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat daftar mata uang',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => provider.loadSupportedCurrencies(),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  void _onCurrencySelected(
    BuildContext context,
    CurrencyProvider provider,
    SupportedCurrency currency,
  ) async {
    await provider.setSelectedCurrency(currency.code);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mata uang diubah ke ${currency.code} — ${currency.name}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}