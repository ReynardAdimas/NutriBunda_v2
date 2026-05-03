import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutribunda/data/models/nutrition_summary.dart';

/// Widget contoh yang menampilkan ringkasan nutrisi
/// Buat file ini di: lib/presentation/widgets/nutrition_summary_card.dart
///
/// class NutritionSummaryCard extends StatelessWidget {
///   final NutritionSummary summary;
///   final double calorieTarget;
///   const NutritionSummaryCard({
///     super.key,
///     required this.summary,
///     required this.calorieTarget,
///   });
///
///   @override
///   Widget build(BuildContext context) {
///     final progress = (summary.calories / calorieTarget).clamp(0.0, 1.0);
///     return Card(
///       child: Padding(
///         padding: const EdgeInsets.all(16),
///         child: Column(
///           children: [
///             Text('${summary.calories.toStringAsFixed(0)} kkal',
///                 key: const Key('calories-text')),
///             LinearProgressIndicator(value: progress,
///                 key: const Key('calories-progress')),
///             Text('Protein: ${summary.protein.toStringAsFixed(1)}g',
///                 key: const Key('protein-text')),
///           ],
///         ),
///       ),
///     );
///   }
/// }

// Inline widget untuk keperluan test (hapus jika sudah punya file terpisah)
class NutritionSummaryCard extends StatelessWidget {
  final NutritionSummary summary;
  final double calorieTarget;

  const NutritionSummaryCard({
    super.key,
    required this.summary,
    required this.calorieTarget,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (summary.calories / calorieTarget).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${summary.calories.toStringAsFixed(0)} kkal',
              key: const Key('calories-text'),
            ),
            LinearProgressIndicator(
              value: progress,
              key: const Key('calories-progress'),
            ),
            Text(
              'Protein: ${summary.protein.toStringAsFixed(1)}g',
              key: const Key('protein-text'),
            ),
            Text(
              'Karbohidrat: ${summary.carbs.toStringAsFixed(1)}g',
              key: const Key('carbs-text'),
            ),
            Text(
              'Lemak: ${summary.fat.toStringAsFixed(1)}g',
              key: const Key('fat-text'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  Widget buildCard(NutritionSummary summary, {double target = 2000.0}) {
    return MaterialApp(
      home: Scaffold(
        body: NutritionSummaryCard(
          summary: summary,
          calorieTarget: target,
        ),
      ),
    );
  }

  group('NutritionSummaryCard — tampilan data', () {
    testWidgets('harus menampilkan nilai kalori dengan benar', (tester) async {
      const summary = NutritionSummary(
        calories: 1250.0,
        protein: 45.5,
        carbs: 180.0,
        fat: 35.0,
      );

      await tester.pumpWidget(buildCard(summary));

      expect(find.byKey(const Key('calories-text')), findsOneWidget);
      expect(find.text('1250 kkal'), findsOneWidget);
    });

    testWidgets('harus menampilkan nilai protein dengan benar', (tester) async {
      const summary = NutritionSummary(protein: 45.5);

      await tester.pumpWidget(buildCard(summary));

      expect(find.text('Protein: 45.5g'), findsOneWidget);
    });

    testWidgets('harus menampilkan nilai karbohidrat dan lemak', (tester) async {
      const summary = NutritionSummary(carbs: 180.0, fat: 35.0);

      await tester.pumpWidget(buildCard(summary));

      expect(find.text('Karbohidrat: 180.0g'), findsOneWidget);
      expect(find.text('Lemak: 35.0g'), findsOneWidget);
    });
  });

  group('NutritionSummaryCard — progress indicator', () {
    testWidgets('progress bar harus ada di widget', (tester) async {
      const summary = NutritionSummary(calories: 1000.0);

      await tester.pumpWidget(buildCard(summary, target: 2000.0));

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('calories-progress')),
      );

      // 1000 / 2000 = 0.5 (50%)
      expect(progressBar.value, closeTo(0.5, 0.001));
    });

    testWidgets('progress bar tidak boleh melebihi 1.0 meski kalori over target',
        (tester) async {
      const summary = NutritionSummary(calories: 5000.0);

      await tester.pumpWidget(buildCard(summary, target: 2000.0));

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('calories-progress')),
      );

      expect(progressBar.value, equals(1.0));
    });

    testWidgets('harus menampilkan nol untuk summary kosong', (tester) async {
      const summary = NutritionSummary();

      await tester.pumpWidget(buildCard(summary));

      expect(find.text('0 kkal'), findsOneWidget);
    });
  });
}
