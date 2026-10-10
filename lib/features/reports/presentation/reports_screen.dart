import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/data/dashboard_stats.dart';
import '../../farms/providers/farm_provider.dart';

// Simple provider: per-crop profitability across all user's farms
final cropProfitabilityProvider =
    FutureProvider<List<CropProfitability>>((ref) async {
  final farms = await ref.watch(farmsStreamProvider.future);
  final db = FirebaseFirestore.instance;

  final map = <String, Map<String, double>>{};

  for (final farm in farms) {
    final results = await Future.wait([
      db.collection('farms').doc(farm.id).collection('harvests').get(),
      db.collection('farms').doc(farm.id).collection('sales').get(),
      db.collection('farms').doc(farm.id).collection('expenses').get(),
    ]);

    for (final doc in results[0].docs) {
      final d = doc.data();
      final crop = d['cropName'] ?? 'Unknown';
      map.putIfAbsent(crop, () => {'prod': 0, 'sales': 0, 'rev': 0, 'exp': 0});
      map[crop]!['prod'] =
          (map[crop]!['prod'] ?? 0) + (d['quantity'] ?? 0).toDouble();
    }
    for (final doc in results[1].docs) {
      final d = doc.data();
      final crop = d['cropName'] ?? 'Unknown';
      map.putIfAbsent(crop, () => {'prod': 0, 'sales': 0, 'rev': 0, 'exp': 0});
      map[crop]!['sales'] =
          (map[crop]!['sales'] ?? 0) + (d['quantity'] ?? 0).toDouble();
      map[crop]!['rev'] =
          (map[crop]!['rev'] ?? 0) + (d['totalAmount'] ?? 0).toDouble();
    }
    for (final doc in results[2].docs) {
      final d = doc.data();
      final crop = d['cropName'];
      if (crop == null) continue;
      map.putIfAbsent(crop, () => {'prod': 0, 'sales': 0, 'rev': 0, 'exp': 0});
      map[crop]!['exp'] =
          (map[crop]!['exp'] ?? 0) + (d['amount'] ?? 0).toDouble();
    }
  }

  return map.entries
      .map((e) => CropProfitability(
            cropName: e.key,
            productionKg: e.value['prod'] ?? 0,
            salesKg: e.value['sales'] ?? 0,
            revenue: e.value['rev'] ?? 0,
            expenses: e.value['exp'] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.profit.compareTo(a.profit));
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropAsync = ref.watch(cropProfitabilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: cropAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (crops) {
          if (crops.isEmpty) {
            return const Center(
              child: Text('No data yet. Add harvests, sales and expenses.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: crops.length,
            itemBuilder: (_, i) {
              final c = crops[i];
              final profitable = c.profit >= 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.cropName,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (profitable
                                      ? AppTheme.profitGreen
                                      : AppTheme.alertRed)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              profitable ? 'PROFIT' : 'LOSS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: profitable
                                    ? AppTheme.profitGreen
                                    : AppTheme.alertRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _row('Production', '${c.productionKg.toStringAsFixed(0)} kg'),
                      _row('Sold', '${c.salesKg.toStringAsFixed(0)} kg'),
                      _row('Revenue',
                          'KSh ${c.revenue.toStringAsFixed(0)}'),
                      _row('Expenses',
                          'KSh ${c.expenses.toStringAsFixed(0)}'),
                      const Divider(height: 20),
                      _row(
                        'Cost per kg',
                        'KSh ${c.costPerKg.toStringAsFixed(2)}',
                        highlight: true,
                      ),
                      _row(
                        'Selling price per kg',
                        'KSh ${c.pricePerKg.toStringAsFixed(2)}',
                        highlight: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Profit',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'KSh ${c.profit.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: profitable
                                  ? AppTheme.profitGreen
                                  : AppTheme.alertRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? AppTheme.primaryGreen : null,
            ),
          ),
        ],
      ),
    );
  }
}