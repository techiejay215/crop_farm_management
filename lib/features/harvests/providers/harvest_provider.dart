import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/harvest_model.dart';
import '../data/harvest_repository.dart';
import '../data/harvest_style.dart';

final harvestRepositoryProvider =
    Provider<HarvestRepository>((ref) => HarvestRepository());

/// Time filter: 'all', 'today', 'week', 'month'
final harvestFilterProvider = StateProvider<String>((ref) => 'all');

/// Free-text search over crop / location / notes.
final harvestSearchProvider = StateProvider<String>((ref) => '');

/// Optional grade filter: null = all, or 'A' / 'B' / 'C'.
final harvestGradeFilterProvider = StateProvider<String?>((ref) => null);

final harvestsStreamProvider = StreamProvider<List<Harvest>>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(harvestRepositoryProvider).streamHarvests(farmId);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
class HarvestSummary {
  /// Sums only harvests whose unit matches [dominantUnit] — mixing kg with
  /// crates would produce a meaningless number.
  final double grossYield;
  final double netYield;
  final double wasted;
  final String dominantUnit;

  final int count;
  final int thisMonthCount;
  final int todayCount;

  /// 0..1
  final double wasteRatio;

  /// True when the underlying records use more than one unit.
  final bool hasMixedUnits;

  const HarvestSummary({
    required this.grossYield,
    required this.netYield,
    required this.wasted,
    required this.dominantUnit,
    required this.count,
    required this.thisMonthCount,
    required this.todayCount,
    required this.wasteRatio,
    required this.hasMixedUnits,
  });

  static const empty = HarvestSummary(
    grossYield: 0,
    netYield: 0,
    wasted: 0,
    dominantUnit: 'kg',
    count: 0,
    thisMonthCount: 0,
    todayCount: 0,
    wasteRatio: 0,
    hasMixedUnits: false,
  );

  bool get isEmpty => count == 0;
  bool get hasWaste => wasted > 0;
}

final harvestSummaryProvider = Provider<HarvestSummary>((ref) {
  final all = ref.watch(harvestsStreamProvider).value ?? const <Harvest>[];
  if (all.isEmpty) return HarvestSummary.empty;

  // 1. Determine dominant unit by count of records.
  final unitCounts = <String, int>{};
  for (final h in all) {
    unitCounts[h.unit] = (unitCounts[h.unit] ?? 0) + 1;
  }
  final dominant = unitCounts.entries
      .reduce((a, b) => a.value >= b.value ? a : b)
      .key;
  final mixed = unitCounts.length > 1;

  // 2. Aggregate only the dominant unit.
  final now = DateTime.now();
  var gross = 0.0;
  var net = 0.0;
  var wasted = 0.0;
  var thisMonth = 0;
  var today = 0;

  for (final h in all) {
    if (h.unit != dominant) continue;
    gross += h.quantity;
    wasted += h.wastedQuantity;
    net += (h.quantity - h.wastedQuantity).clamp(0, double.infinity);

    final d = h.harvestDate;
    if (d == null) continue;
    if (d.year == now.year && d.month == now.month) {
      thisMonth++;
      if (d.day == now.day) today++;
    }
  }

  return HarvestSummary(
    grossYield: gross,
    netYield: net,
    wasted: wasted,
    dominantUnit: dominant,
    count: all.length,
    thisMonthCount: thisMonth,
    todayCount: today,
    wasteRatio: gross <= 0 ? 0 : wasted / gross,
    hasMixedUnits: mixed,
  );
});

// ---------------------------------------------------------------------------
// Filtered list
// ---------------------------------------------------------------------------
final filteredHarvestsProvider = Provider<List<Harvest>>((ref) {
  final all = ref.watch(harvestsStreamProvider).value ?? const <Harvest>[];
  final timeFilter = ref.watch(harvestFilterProvider);
  final gradeFilter = ref.watch(harvestGradeFilterProvider);
  final query = ref.watch(harvestSearchProvider).trim().toLowerCase();

  final now = DateTime.now();

  return all.where((h) {
    // Time
    final d = h.harvestDate;
    switch (timeFilter) {
      case 'today':
        if (d == null ||
            d.year != now.year ||
            d.month != now.month ||
            d.day != now.day) {
          return false;
        }
        break;
      case 'week':
        if (d == null || now.difference(d).inDays > 7) return false;
        break;
      case 'month':
        if (d == null || d.year != now.year || d.month != now.month) {
          return false;
        }
        break;
      default:
        break;
    }

    // Grade
    if (gradeFilter != null && h.grade.toUpperCase() != gradeFilter) {
      return false;
    }

    // Search
    if (query.isNotEmpty) {
      final hit = h.cropName.toLowerCase().contains(query) ||
          h.location.toLowerCase().contains(query) ||
          (h.notes?.toLowerCase().contains(query) ?? false);
      if (!hit) return false;
    }

    return true;
  }).toList();
});

/// Counts for the time filter chips.
final harvestTimeCountsProvider =
    Provider<({int all, int today, int week, int month})>((ref) {
  final all = ref.watch(harvestsStreamProvider).value ?? const <Harvest>[];
  final now = DateTime.now();
  var today = 0;
  var week = 0;
  var month = 0;
  for (final h in all) {
    final d = h.harvestDate;
    if (d == null) continue;
    if (now.difference(d).inDays <= 7) week++;
    if (d.year == now.year && d.month == now.month) {
      month++;
      if (d.day == now.day) today++;
    }
  }
  return (all: all.length, today: today, week: week, month: month);
});