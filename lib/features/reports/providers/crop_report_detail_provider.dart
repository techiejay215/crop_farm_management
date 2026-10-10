import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farms/providers/farm_provider.dart';
import '../data/crop_report_detail_models.dart';
import 'report_providers.dart';

/// Pulls every detail record for a single crop name, in scope of the
/// currently selected date range.
///
/// Farms are automatically scoped by role: customers only see their own
/// farms because `farmsStreamProvider` filters by ownerId for non-admins.
final cropReportDetailProvider =
    FutureProvider.family<CropReportDetail, String>((ref, cropName) async {
  final db = FirebaseFirestore.instance;
  final farms = await ref.watch(farmsStreamProvider.future);
  final range = ref.watch(cropReportRangeProvider);

  final instances = <CropInstance>[];
  final activities = <CropActivityRow>[];
  final expenses = <CropExpenseRow>[];
  final income = <CropIncomeRow>[];
  final harvests = <CropHarvestRow>[];

  // Unit tally — used to pick a dominant unit.
  final unitCounts = <String, int>{};

  for (final farm in farms) {
    final farmId = farm.id;
    final farmName = farm.farmName;

    // ---- Crop instances with this name ----
    final cropDocs = await db
        .collection('farms')
        .doc(farmId)
        .collection('crops')
        .where('cropName', isEqualTo: cropName)
        .get();

    for (final cropDoc in cropDocs.docs) {
      final c = cropDoc.data();
      instances.add(CropInstance(
        farmName: farmName,
        location: (c['location'] ?? '') as String,
        plantCount: (c['plantCount'] ?? 0) as int,
        acreage: ((c['acreage'] ?? 0) as num).toDouble(),
        stage: (c['stage'] ?? 'growing') as String,
        plantingDate: (c['plantingDate'] as Timestamp?)?.toDate(),
      ));

      // ---- Activities for this crop instance ----
      final actDocs = await cropDoc.reference.collection('activities').get();

      for (final a in actDocs.docs) {
        final d = a.data();
        final date = (d['date'] as Timestamp?)?.toDate();
        if (!range.contains(date)) continue;

        final unit = d['unit'] as String?;
        if (unit != null && unit.isNotEmpty) {
          unitCounts[unit] = (unitCounts[unit] ?? 0) + 1;
        }

        activities.add(CropActivityRow(
          farmName: farmName,
          location: (c['location'] ?? '') as String,
          date: date,
          type: (d['type'] ?? 'other') as String,
          description: (d['description'] ?? '') as String,
          quantity: (d['quantity'] as num?)?.toDouble(),
          unit: unit,
          cost: (d['cost'] as num?)?.toDouble(),
          income: (d['income'] as num?)?.toDouble(),
          person: d['personResponsible'] as String?,
        ));
      }
    }

    // ---- Expenses tagged with this crop name ----
    final expDocs = await db
        .collection('farms')
        .doc(farmId)
        .collection('expenses')
        .where('cropName', isEqualTo: cropName)
        .get();

    for (final e in expDocs.docs) {
      final d = e.data();
      final date = (d['date'] as Timestamp?)?.toDate();
      if (!range.contains(date)) continue;
      expenses.add(CropExpenseRow(
        farmName: farmName,
        date: date,
        category: (d['category'] ?? 'other') as String,
        description: (d['description'] ?? '') as String,
        amount: ((d['amount'] ?? 0) as num).toDouble(),
        location: d['location'] as String?,
      ));
    }

    // ---- Sales tagged with this crop name ----
    final saleDocs = await db
        .collection('farms')
        .doc(farmId)
        .collection('sales')
        .where('cropName', isEqualTo: cropName)
        .get();

    for (final s in saleDocs.docs) {
      final d = s.data();
      final date = (d['saleDate'] as Timestamp?)?.toDate();
      if (!range.contains(date)) continue;

      final unit = (d['unit'] ?? 'kg') as String;
      unitCounts[unit] = (unitCounts[unit] ?? 0) + 1;

      income.add(CropIncomeRow(
        farmName: farmName,
        date: date,
        buyer: (d['buyer'] ?? '') as String,
        quantity: ((d['quantity'] ?? 0) as num).toDouble(),
        unit: unit,
        pricePerUnit: ((d['pricePerUnit'] ?? 0) as num).toDouble(),
        total: ((d['totalAmount'] ?? 0) as num).toDouble(),
        status: (d['status'] ?? 'completed') as String,
      ));
    }

    // ---- Harvests tagged with this crop name ----
    final harDocs = await db
        .collection('farms')
        .doc(farmId)
        .collection('harvests')
        .where('cropName', isEqualTo: cropName)
        .get();

    for (final h in harDocs.docs) {
      final d = h.data();
      final date = (d['harvestDate'] as Timestamp?)?.toDate();
      if (!range.contains(date)) continue;

      final unit = (d['unit'] ?? 'kg') as String;
      unitCounts[unit] = (unitCounts[unit] ?? 0) + 1;

      harvests.add(CropHarvestRow(
        farmName: farmName,
        date: date,
        quantity: ((d['quantity'] ?? 0) as num).toDouble(),
        unit: unit,
        grade: (d['grade'] ?? 'A') as String,
        wasted: ((d['wastedQuantity'] ?? 0) as num).toDouble(),
      ));
    }
  }

  // Pick the dominant unit (most frequent), default to kg.
  String dominantUnit = 'kg';
  int best = 0;
  for (final e in unitCounts.entries) {
    if (e.value > best) {
      best = e.value;
      dominantUnit = e.key;
    }
  }

  // Sort chronologically (newest first).
  activities.sort((a, b) =>
      (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
  expenses.sort((a, b) =>
      (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
  income.sort((a, b) =>
      (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
  harvests.sort((a, b) =>
      (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

  return CropReportDetail(
    cropName: cropName,
    dominantUnit: dominantUnit,
    hasMixedUnits: unitCounts.length > 1,
    instances: instances,
    activities: activities,
    expenses: expenses,
    income: income,
    harvests: harvests,
  );
});