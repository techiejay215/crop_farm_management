import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/greenhouse_model.dart';
import '../data/greenhouse_repository.dart';
import '../data/greenhouse_style.dart';

// ===========================================================================
// Repository
// ===========================================================================
final greenhouseRepositoryProvider =
    Provider<GreenhouseRepository>((ref) => GreenhouseRepository());

// ===========================================================================
// Stream — all greenhouses for the selected farm
// ===========================================================================
final greenhousesStreamProvider = StreamProvider<List<Greenhouse>>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(greenhouseRepositoryProvider).streamGreenhouses(farmId);
});

// ===========================================================================
// Filter + search state
// ===========================================================================
final greenhouseFilterProvider = StateProvider<String>((ref) => 'all');
final greenhouseSearchProvider = StateProvider<String>((ref) => '');

// ===========================================================================
// Filtered list
// ===========================================================================
final filteredGreenhousesProvider = Provider<List<Greenhouse>>((ref) {
  final all = ref.watch(greenhousesStreamProvider).value ?? const <Greenhouse>[];
  final filter = ref.watch(greenhouseFilterProvider);
  final query = ref.watch(greenhouseSearchProvider).trim().toLowerCase();

  var list = all;

  if (filter == 'active') {
    list = list
        .where((g) =>
            g.currentCrop.trim().isNotEmpty && g.plantCount > 0)
        .toList();
  } else if (filter == 'empty') {
    list = list
        .where((g) =>
            g.currentCrop.trim().isEmpty || g.plantCount == 0)
        .toList();
  }

  if (query.isNotEmpty) {
    list = list.where((g) {
      return g.name.toLowerCase().contains(query) ||
          g.currentCrop.toLowerCase().contains(query);
    }).toList();
  }

  return list;
});

// ===========================================================================
// Counts per filter
// ===========================================================================
final greenhouseCountsProvider =
    Provider<({int all, int active, int empty})>((ref) {
  final all = ref.watch(greenhousesStreamProvider).value ?? const <Greenhouse>[];
  var active = 0;
  var empty = 0;
  for (final g in all) {
    final isActive =
        g.currentCrop.trim().isNotEmpty && g.plantCount > 0;
    if (isActive) {
      active++;
    } else {
      empty++;
    }
  }
  return (all: all.length, active: active, empty: empty);
});

// ===========================================================================
// Summary
// ===========================================================================
class GreenhouseSummary {
  final double totalArea;
  final int active;
  final int emptyCount;
  final int totalPlants;
  final double? avgDensity;

  const GreenhouseSummary({
    required this.totalArea,
    required this.active,
    required this.emptyCount,
    required this.totalPlants,
    required this.avgDensity,
  });

  static const empty = GreenhouseSummary(
    totalArea: 0,
    active: 0,
    emptyCount: 0,
    totalPlants: 0,
    avgDensity: null,
  );
}

final greenhouseSummaryProvider = Provider<GreenhouseSummary>((ref) {
  final all = ref.watch(greenhousesStreamProvider).value ?? const <Greenhouse>[];

  if (all.isEmpty) return GreenhouseSummary.empty;

  var area = 0.0;
  var plants = 0;
  var active = 0;
  var empty = 0;

  for (final g in all) {
    area += g.size;
    plants += g.plantCount;
    final isActive =
        g.currentCrop.trim().isNotEmpty && g.plantCount > 0;
    if (isActive) {
      active++;
    } else {
      empty++;
    }
  }

  final density =
      area <= 0 || plants <= 0 ? null : plants / area;

  return GreenhouseSummary(
    totalArea: area,
    active: active,
    emptyCount: empty,
    totalPlants: plants,
    avgDensity: density,
  );
});

// ===========================================================================
// Expose density helper (used by the summary card)
// ===========================================================================
// (GreenhouseStyle.density is imported above and can be used directly.)s