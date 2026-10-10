import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../auth/providers/auth_provider.dart';
import '../data/farm_model.dart';
import '../data/farm_payment_info.dart';
import '../data/farm_repository.dart';

final farmRepositoryProvider =
    Provider<FarmRepository>((ref) => FarmRepository());

final farmsStreamProvider = StreamProvider<List<Farm>>((ref) {
  final userAsync = ref.watch(authStateProvider);
  final userDataAsync = ref.watch(userDataProvider);

  final user = userAsync.value;
  final userData = userDataAsync.value;

  if (user == null) return const Stream.empty();

  final role = userData?['role'] ?? 'customer';
  return ref
      .watch(farmRepositoryProvider)
      .streamFarms(userId: user.uid, role: role);
});

/// Filter tab state (All / Main / Rented)
final farmFilterProvider = StateProvider<String>((ref) => 'all');

/// Free-text search across name / location / landlord.
final farmSearchProvider = StateProvider<String>((ref) => '');

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
class FarmSummary {
  final int totalFarms;
  final int mainFarms;
  final int rentedFarms;
  final double totalAcreage;
  final int totalCrops;

  const FarmSummary({
    required this.totalFarms,
    required this.mainFarms,
    required this.rentedFarms,
    required this.totalAcreage,
    required this.totalCrops,
  });

  static const empty = FarmSummary(
    totalFarms: 0,
    mainFarms: 0,
    rentedFarms: 0,
    totalAcreage: 0,
    totalCrops: 0,
  );

  bool get isEmpty => totalFarms == 0;
}

final farmSummaryProvider = Provider<FarmSummary>((ref) {
  final list = ref.watch(farmsStreamProvider).value ?? const <Farm>[];
  if (list.isEmpty) return FarmSummary.empty;

  var mainCount = 0;
  var rentedCount = 0;
  var acreage = 0.0;
  var crops = 0;

  for (final f in list) {
    if (f.type == 'rented') {
      rentedCount++;
    } else {
      mainCount++;
    }
    acreage += f.acreage;
    crops += f.cropCount;
  }

  return FarmSummary(
    totalFarms: list.length,
    mainFarms: mainCount,
    rentedFarms: rentedCount,
    totalAcreage: acreage,
    totalCrops: crops,
  );
});

// ---------------------------------------------------------------------------
// Filtered list + chip counts
// ---------------------------------------------------------------------------
final filteredFarmsProvider = Provider<List<Farm>>((ref) {
  final all = ref.watch(farmsStreamProvider).value ?? const <Farm>[];
  final filter = ref.watch(farmFilterProvider);
  final query = ref.watch(farmSearchProvider).trim().toLowerCase();

  return all.where((f) {
    if (filter != 'all' && f.type != filter) return false;
    if (query.isEmpty) return true;
    return f.farmName.toLowerCase().contains(query) ||
        f.location.toLowerCase().contains(query) ||
        (f.landlord?.toLowerCase().contains(query) ?? false);
  }).toList();
});

final farmCountsProvider =
    Provider<({int all, int main, int rented})>((ref) {
  final all = ref.watch(farmsStreamProvider).value ?? const <Farm>[];
  var main = 0;
  var rented = 0;
  for (final f in all) {
    if (f.type == 'rented') {
      rented++;
    } else {
      main++;
    }
  }
  return (all: all.length, main: main, rented: rented);
});

// ---------------------------------------------------------------------------
// Payment info (live) for the currently selected farm
// ---------------------------------------------------------------------------

/// Live payment info for the currently selected farm.
/// Returns null while loading or if not yet configured.
final farmPaymentInfoProvider =
    StreamProvider<FarmPaymentInfo?>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(farmRepositoryProvider).watchPaymentInfo(farmId);
});