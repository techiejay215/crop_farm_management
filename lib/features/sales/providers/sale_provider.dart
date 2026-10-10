import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/sale_model.dart';
import '../data/sale_repository.dart';

final saleRepositoryProvider =
    Provider<SaleRepository>((ref) => SaleRepository());

// Status filter: 'all', 'completed', 'pending'
final saleFilterProvider = StateProvider<String>((ref) => 'all');

/// Free-text search over buyer / crop / location.
final saleSearchProvider = StateProvider<String>((ref) => '');

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(saleRepositoryProvider).streamSales(farmId);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

/// Revenue = completed only. Pending is tracked separately so real money
/// and owed money never get mixed up.
class SalesSummary {
  final double totalRevenue;
  final double thisMonth;
  final double lastMonth;
  final double pendingAmount;

  final int completedCount;
  final int pendingCount;
  final int totalCount;

  const SalesSummary({
    required this.totalRevenue,
    required this.thisMonth,
    required this.lastMonth,
    required this.pendingAmount,
    required this.completedCount,
    required this.pendingCount,
    required this.totalCount,
  });

  static const empty = SalesSummary(
    totalRevenue: 0,
    thisMonth: 0,
    lastMonth: 0,
    pendingAmount: 0,
    completedCount: 0,
    pendingCount: 0,
    totalCount: 0,
  );

  bool get isEmpty => totalCount == 0;
  bool get hasPending => pendingCount > 0;

  /// Null when there is no previous month to compare against.
  double? get monthChangePct {
    if (lastMonth <= 0) return null;
    return ((thisMonth - lastMonth) / lastMonth) * 100;
  }
}

final salesSummaryProvider = Provider<SalesSummary>((ref) {
  final all = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  if (all.isEmpty) return SalesSummary.empty;

  final now = DateTime.now();
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);

  var revenue = 0.0;
  var thisMonth = 0.0;
  var lastMonth = 0.0;
  var pending = 0.0;
  var completed = 0;
  var pendingCount = 0;

  for (final s in all) {
    if (s.status == 'completed') {
      revenue += s.totalAmount;
      completed++;
      final d = s.saleDate;
      if (d == null) continue;
      if (!d.isBefore(thisMonthStart)) {
        thisMonth += s.totalAmount;
      } else if (!d.isBefore(lastMonthStart)) {
        lastMonth += s.totalAmount;
      }
    } else {
      pending += s.totalAmount;
      pendingCount++;
    }
  }

  return SalesSummary(
    totalRevenue: revenue,
    thisMonth: thisMonth,
    lastMonth: lastMonth,
    pendingAmount: pending,
    completedCount: completed,
    pendingCount: pendingCount,
    totalCount: all.length,
  );
});

// ---------------------------------------------------------------------------
// Filtered list actually rendered
// ---------------------------------------------------------------------------

final filteredSalesProvider = Provider<List<Sale>>((ref) {
  final all = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final filter = ref.watch(saleFilterProvider);
  final query = ref.watch(saleSearchProvider).trim().toLowerCase();

  return all.where((s) {
    if (filter != 'all' && s.status != filter) return false;
    if (query.isEmpty) return true;
    return s.buyer.toLowerCase().contains(query) ||
        s.cropName.toLowerCase().contains(query) ||
        s.location.toLowerCase().contains(query);
  }).toList();
});

/// Counts for the filter chips.
final saleCountsProvider =
    Provider<({int all, int completed, int pending})>((ref) {
  final all = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  var completed = 0;
  var pending = 0;
  for (final s in all) {
    if (s.status == 'pending') {
      pending++;
    } else {
      completed++;
    }
  }
  return (all: all.length, completed: completed, pending: pending);
});