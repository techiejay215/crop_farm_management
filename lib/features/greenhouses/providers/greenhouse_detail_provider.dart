import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crops/data/crop_activity_model.dart';
import '../../crops/data/crop_model.dart';
import '../../crops/providers/crop_activity_provider.dart';
import '../../crops/providers/crop_provider.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../harvests/data/harvest_model.dart';
import '../../harvests/providers/harvest_provider.dart';
import '../../sales/data/sale_model.dart';
import '../../sales/providers/sale_provider.dart';
import '../data/greenhouse_model.dart';
import 'greenhouse_provider.dart';

/// Bundled data for one greenhouse.
class GreenhouseDetail {
  final Greenhouse greenhouse;
  final Crop? crop;
  final List<CropActivity> activities;
  final List<Harvest> harvests;
  final List<Sale> sales;
  final List<Expense> expenses;

  const GreenhouseDetail({
    required this.greenhouse,
    this.crop,
    required this.activities,
    required this.harvests,
    required this.sales,
    required this.expenses,
  });

  // ---- Financials ----
  double get revenue => sales
      .where((s) => s.status == 'completed')
      .fold(0.0, (a, b) => a + b.totalAmount);

  double get pendingRevenue => sales
      .where((s) => s.status != 'completed')
      .fold(0.0, (a, b) => a + b.totalAmount);

  double get totalExpenses =>
      expenses.fold(0.0, (a, b) => a + b.amount);

  double get profit => revenue - totalExpenses;

  double? get margin => revenue <= 0 ? null : profit / revenue;

  // ---- Yield ----
  double get grossYield =>
      harvests.fold(0.0, (a, b) => a + b.quantity);

  double get netYield => harvests.fold(
        0.0,
        (a, b) =>
            a + (b.quantity - b.wastedQuantity).clamp(0, double.infinity),
      );

  double get wasted =>
      harvests.fold(0.0, (a, b) => a + b.wastedQuantity);

  String get dominantUnit {
    final counts = <String, int>{};
    for (final h in harvests) {
      counts[h.unit] = (counts[h.unit] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'kg';
    return counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  double? get density {
    if (greenhouse.size <= 0 || greenhouse.plantCount <= 0) return null;
    return greenhouse.plantCount / greenhouse.size;
  }

  bool get hasActivity =>
      crop != null ||
      activities.isNotEmpty ||
      harvests.isNotEmpty ||
      sales.isNotEmpty ||
      expenses.isNotEmpty;
}

/// Loads everything for one greenhouse.
final greenhouseDetailProvider =
    FutureProvider.family<GreenhouseDetail?, String>((ref, greenhouseId) async {
  final greenhouses =
      await ref.watch(greenhousesStreamProvider.future);
  final gh = greenhouses.where((g) => g.id == greenhouseId).firstOrNull;
  if (gh == null) return null;

  // ---- Crop grown in this greenhouse ----
  final crops = await ref.watch(cropsStreamProvider.future);
  final key = gh.name.trim().toLowerCase();

  Crop? crop = crops
      .where((c) => c.location.trim().toLowerCase() == key)
      .firstOrNull;

  if (crop == null && gh.currentCrop.trim().isNotEmpty) {
    final ck = gh.currentCrop.trim().toLowerCase();
    crop = crops
        .where((c) => c.cropName.trim().toLowerCase() == ck)
        .firstOrNull;
  }

  // ---- Activities for that crop ----
  List<CropActivity> activities = const [];
  if (crop != null) {
    activities = await ref.watch(
      cropActivitiesStreamProvider(
        (farmId: crop.farmId, cropId: crop.id),
      ).future,
    );
  }

  // ---- Sub-records matched by location == greenhouse.name ----
  final allHarvests = await ref.watch(harvestsStreamProvider.future);
  final harvests = allHarvests
      .where((h) => h.location.trim().toLowerCase() == key)
      .toList();

  final allSales = await ref.watch(salesStreamProvider.future);
  final sales = allSales
      .where((s) => s.location.trim().toLowerCase() == key)
      .toList();

  final allExpenses = await ref.watch(expensesStreamProvider.future);
  final expenses = allExpenses
      .where((e) =>
          (e.location ?? '').trim().toLowerCase() == key)
      .toList();

  return GreenhouseDetail(
    greenhouse: gh,
    crop: crop,
    activities: activities,
    harvests: harvests,
    sales: sales,
    expenses: expenses,
  );
});