import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/labour_model.dart';
import '../data/labour_repository.dart';

final labourRepositoryProvider =
    Provider<LabourRepository>((ref) => LabourRepository());

/// Payment filter: 'all', 'paid', 'pending'
final labourFilterProvider = StateProvider<String>((ref) => 'all');

/// Free-text search over worker / task / location.
final labourSearchProvider = StateProvider<String>((ref) => '');

final labourStreamProvider = StreamProvider<List<Labour>>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(labourRepositoryProvider).streamLabour(farmId);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
class LabourSummary {
  final double totalCost;
  final double paidAmount;
  final double pendingAmount;

  final double thisMonth;
  final double lastMonth;

  final int totalRecords;
  final int pendingRecords;
  final int workerCount;

  const LabourSummary({
    required this.totalCost,
    required this.paidAmount,
    required this.pendingAmount,
    required this.thisMonth,
    required this.lastMonth,
    required this.totalRecords,
    required this.pendingRecords,
    required this.workerCount,
  });

  static const empty = LabourSummary(
    totalCost: 0,
    paidAmount: 0,
    pendingAmount: 0,
    thisMonth: 0,
    lastMonth: 0,
    totalRecords: 0,
    pendingRecords: 0,
    workerCount: 0,
  );

  bool get isEmpty => totalRecords == 0;
  bool get hasPending => pendingAmount > 0;

  double? get monthChangePct {
    if (lastMonth <= 0) return null;
    return ((thisMonth - lastMonth) / lastMonth) * 100;
  }
}

final labourSummaryProvider = Provider<LabourSummary>((ref) {
  final all = ref.watch(labourStreamProvider).value ?? const <Labour>[];
  if (all.isEmpty) return LabourSummary.empty;

  final now = DateTime.now();
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);

  var total = 0.0;
  var paid = 0.0;
  var pending = 0.0;
  var thisMonth = 0.0;
  var lastMonth = 0.0;
  var pendingRecords = 0;
  final workers = <String>{};

  for (final l in all) {
    total += l.totalAmount;
    paid += l.amountPaid;
    pending += l.pendingAmount;
    if (l.pendingAmount > 0) pendingRecords++;
    if (l.workerName.isNotEmpty) workers.add(l.workerName.toLowerCase());

    final d = l.date;
    if (d == null) continue;
    if (!d.isBefore(thisMonthStart)) {
      thisMonth += l.totalAmount;
    } else if (!d.isBefore(lastMonthStart)) {
      lastMonth += l.totalAmount;
    }
  }

  return LabourSummary(
    totalCost: total,
    paidAmount: paid,
    pendingAmount: pending,
    thisMonth: thisMonth,
    lastMonth: lastMonth,
    totalRecords: all.length,
    pendingRecords: pendingRecords,
    workerCount: workers.length,
  );
});

/// Back-compat with dashboard.
final pendingWagesProvider = Provider<double>((ref) {
  return ref.watch(labourSummaryProvider).pendingAmount;
});

// ---------------------------------------------------------------------------
// Filtered list
// ---------------------------------------------------------------------------
final filteredLabourProvider = Provider<List<Labour>>((ref) {
  final all = ref.watch(labourStreamProvider).value ?? const <Labour>[];
  final filter = ref.watch(labourFilterProvider);
  final query = ref.watch(labourSearchProvider).trim().toLowerCase();

  return all.where((l) {
    if (filter == 'paid' && l.pendingAmount > 0) return false;
    if (filter == 'pending' && l.pendingAmount <= 0) return false;
    if (query.isEmpty) return true;
    return l.workerName.toLowerCase().contains(query) ||
        l.task.toLowerCase().contains(query) ||
        (l.location?.toLowerCase().contains(query) ?? false);
  }).toList();
});

/// Counts for the filter chips.
final labourCountsProvider =
    Provider<({int all, int paid, int pending})>((ref) {
  final all = ref.watch(labourStreamProvider).value ?? const <Labour>[];
  var paid = 0;
  var pending = 0;
  for (final l in all) {
    if (l.pendingAmount > 0) {
      pending++;
    } else {
      paid++;
    }
  }
  return (all: all.length, paid: paid, pending: pending);
});