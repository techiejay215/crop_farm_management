import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farms/providers/farm_provider.dart';
import '../data/dashboard_stats.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final farms = await ref.watch(farmsStreamProvider.future);
  final db = FirebaseFirestore.instance;

  int activeCrops = 0;
  double totalProduction = 0;
  double totalRevenue = 0;
  double totalExpenses = 0;
  double pendingWages = 0;

  final farmPerformance = <FarmPerformance>[];
  final monthBuckets = <String, MonthlyProduction>{};
  final recentSales = <RecentSale>[];
  final expenseByCategory = <String, double>{};
  final now = DateTime.now();

  // Initialize last 6 months buckets
  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final label = _monthLabel(d.month);
    monthBuckets[label] = MonthlyProduction(
      monthLabel: label,
      productionKg: 0,
      salesKg: 0,
    );
  }

  for (final farm in farms) {
    final farmId = farm.id;

    // Fetch subcollections in parallel
    final results = await Future.wait([
      db.collection('farms').doc(farmId).collection('crops').get(),
      db.collection('farms').doc(farmId).collection('harvests').get(),
      db.collection('farms').doc(farmId).collection('sales').get(),
      db.collection('farms').doc(farmId).collection('expenses').get(),
      db.collection('farms').doc(farmId).collection('labour').get(),
    ]);

    final cropsSnap = results[0];
    final harvestsSnap = results[1];
    final salesSnap = results[2];
    final expensesSnap = results[3];
    final labourSnap = results[4];

    activeCrops += cropsSnap.docs.length;

    double farmProduction = 0;
    for (final doc in harvestsSnap.docs) {
      final d = doc.data();
      final qty = (d['quantity'] ?? 0).toDouble();
      farmProduction += qty;
      totalProduction += qty;

      final hd = (d['harvestDate'] as Timestamp?)?.toDate();
      if (hd != null) {
        final label = _monthLabel(hd.month);
        if (monthBuckets.containsKey(label)) {
          final b = monthBuckets[label]!;
          monthBuckets[label] = MonthlyProduction(
            monthLabel: label,
            productionKg: b.productionKg + qty,
            salesKg: b.salesKg,
          );
        }
      }
    }

    double farmRevenue = 0;
    for (final doc in salesSnap.docs) {
      final d = doc.data();
      final amount = (d['totalAmount'] ?? 0).toDouble();
      final qty = (d['quantity'] ?? 0).toDouble();
      farmRevenue += amount;
      totalRevenue += amount;

      final sd = (d['saleDate'] as Timestamp?)?.toDate();
      if (sd != null) {
        final label = _monthLabel(sd.month);
        if (monthBuckets.containsKey(label)) {
          final b = monthBuckets[label]!;
          monthBuckets[label] = MonthlyProduction(
            monthLabel: label,
            productionKg: b.productionKg,
            salesKg: b.salesKg + qty,
          );
        }
      }

      recentSales.add(RecentSale(
        cropName: d['cropName'] ?? '',
        buyer: d['buyer'] ?? '',
        quantity: qty,
        unit: d['unit'] ?? 'kg',
        totalAmount: amount,
        date: sd,
      ));
    }

    double farmExpenses = 0;
    for (final doc in expensesSnap.docs) {
      final d = doc.data();
      final amount = (d['amount'] ?? 0).toDouble();
      final cat = d['category'] ?? 'other';
      farmExpenses += amount;
      totalExpenses += amount;
      expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + amount;
    }

    for (final doc in labourSnap.docs) {
      final d = doc.data();
      final total = (d['totalAmount'] ?? 0).toDouble();
      final paid = (d['amountPaid'] ?? 0).toDouble();
      final pending = (total - paid).clamp(0, double.infinity);
      pendingWages += pending;
      farmExpenses += paid;
      totalExpenses += paid;
      expenseByCategory['labour'] =
          (expenseByCategory['labour'] ?? 0) + paid;
    }

    farmPerformance.add(FarmPerformance(
      farmId: farmId,
      farmName: farm.farmName,
      acreage: farm.acreage,
      cropCount: cropsSnap.docs.length,
      revenue: farmRevenue,
      expenses: farmExpenses,
    ));
  }

  recentSales.sort((a, b) =>
      (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

  return DashboardStats(
    totalFarms: farms.length,
    activeCrops: activeCrops,
    totalProductionKg: totalProduction,
    totalRevenue: totalRevenue,
    totalExpenses: totalExpenses,
    pendingWages: pendingWages,
    farms: farmPerformance,
    monthlyProduction: monthBuckets.values.toList(),
    recentSales: recentSales.take(5).toList(),
    expenseByCategory: expenseByCategory,
  );
});

String _monthLabel(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[(m - 1) % 12];
}