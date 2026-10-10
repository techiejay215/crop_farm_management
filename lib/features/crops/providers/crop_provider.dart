import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/crop_model.dart';
import '../data/crop_repository.dart';
import '../data/crop_style.dart';

final cropRepositoryProvider =
    Provider<CropRepository>((ref) => CropRepository());

final selectedFarmIdProvider = StateProvider<String?>((ref) => null);

/// Filter chip state: 'all', 'growing', 'harvest_ready', 'harvested'
final cropFilterProvider = StateProvider<String>((ref) => 'all');

/// Free-text search over name / variety / location.
final cropSearchProvider = StateProvider<String>((ref) => '');

final cropsStreamProvider = StreamProvider<List<Crop>>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(cropRepositoryProvider).streamCrops(farmId);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
class CropSummary {
  final int totalCrops;
  final int growingCount;
  final int readyCount;
  final int harvestedCount;
  final double totalAcreage;
  final int totalPlants;

  const CropSummary({
    required this.totalCrops,
    required this.growingCount,
    required this.readyCount,
    required this.harvestedCount,
    required this.totalAcreage,
    required this.totalPlants,
  });

  static const empty = CropSummary(
    totalCrops: 0,
    growingCount: 0,
    readyCount: 0,
    harvestedCount: 0,
    totalAcreage: 0,
    totalPlants: 0,
  );

  bool get isEmpty => totalCrops == 0;
}

final cropSummaryProvider = Provider<CropSummary>((ref) {
  final list = ref.watch(cropsStreamProvider).value ?? const <Crop>[];
  if (list.isEmpty) return CropSummary.empty;

  var growing = 0;
  var ready = 0;
  var harvested = 0;
  var acreage = 0.0;
  var plants = 0;

  for (final c in list) {
    switch (c.stage) {
      case 'harvest_ready':
        ready++;
        break;
      case 'harvested':
        harvested++;
        break;
      default:
        growing++;
    }
    acreage += c.acreage;
    plants += c.plantCount;
  }

  return CropSummary(
    totalCrops: list.length,
    growingCount: growing,
    readyCount: ready,
    harvestedCount: harvested,
    totalAcreage: acreage,
    totalPlants: plants,
  );
});

// ---------------------------------------------------------------------------
// Filtered + sorted list
// ---------------------------------------------------------------------------
final filteredCropsProvider = Provider<List<Crop>>((ref) {
  final all = ref.watch(cropsStreamProvider).value ?? const <Crop>[];
  final filter = ref.watch(cropFilterProvider);
  final query = ref.watch(cropSearchProvider).trim().toLowerCase();

  final filtered = all.where((c) {
    if (filter != 'all' && c.stage != filter) return false;
    if (query.isEmpty) return true;
    return c.cropName.toLowerCase().contains(query) ||
        c.variety.toLowerCase().contains(query) ||
        c.location.toLowerCase().contains(query);
  }).toList();

  // Sort: ready-to-harvest first (most urgent), then growing sorted
  // by soonest expected harvest, then harvested by recency.
  int stageRank(String s) {
    switch (s) {
      case 'harvest_ready':
        return 0;
      case 'growing':
        return 1;
      default:
        return 2;
    }
  }

  filtered.sort((a, b) {
    final r = stageRank(a.stage).compareTo(stageRank(b.stage));
    if (r != 0) return r;

    if (a.stage == 'growing') {
      final aDate = a.expectedHarvest ?? DateTime(2100);
      final bDate = b.expectedHarvest ?? DateTime(2100);
      return aDate.compareTo(bDate);
    }
    if (a.stage == 'harvested') {
      final aDate = a.plantingDate ?? DateTime(2000);
      final bDate = b.plantingDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    }
    return a.cropName.compareTo(b.cropName);
  });

  return filtered;
});

final cropCountsProvider =
    Provider<({int all, int growing, int ready, int harvested})>((ref) {
  final all = ref.watch(cropsStreamProvider).value ?? const <Crop>[];
  var growing = 0;
  var ready = 0;
  var harvested = 0;
  for (final c in all) {
    switch (c.stage) {
      case 'harvest_ready':
        ready++;
        break;
      case 'harvested':
        harvested++;
        break;
      default:
        growing++;
    }
  }
  return (
    all: all.length,
    growing: growing,
    ready: ready,
    harvested: harvested,
  );
});