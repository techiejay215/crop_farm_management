// lib/features/expenses/providers/expense_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

final expenseRepositoryProvider =
    Provider<ExpenseRepository>((ref) => ExpenseRepository());

/// Category filter: 'all' or a specific category value.
final expenseFilterProvider = StateProvider<String>((ref) => 'all');

/// Free text search over description / crop / location.
final expenseSearchProvider = StateProvider<String>((ref) => '');

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(expenseRepositoryProvider).streamExpenses(farmId);
});

// ---------------------------------------------------------------------------
// Derived data — everything below is computed, nothing is stored twice.
// ---------------------------------------------------------------------------

class ExpenseSummary {
  const ExpenseSummary({
    required this.total,
    required this.thisMonth,
    required this.lastMonth,
    required this.count,
    required this.average,
  });

  final double total;
  final double thisMonth;
  final double lastMonth;
  final int count;
  final double average;

  static const empty = ExpenseSummary(
    total: 0,
    thisMonth: 0,
    lastMonth: 0,
    count: 0,
    average: 0,
  );

  /// Null when there is no previous month to compare against.
  double? get monthChangePct {
    if (lastMonth <= 0) return null;
    return ((thisMonth - lastMonth) / lastMonth) * 100;
  }
}

final expenseSummaryProvider = Provider<ExpenseSummary>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? const <Expense>[];
  if (expenses.isEmpty) return ExpenseSummary.empty;

  final now = DateTime.now();
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);

  var total = 0.0;
  var thisMonth = 0.0;
  var lastMonth = 0.0;

  for (final e in expenses) {
    total += e.amount;
    final d = e.date;
    if (d == null) continue;
    if (!d.isBefore(thisMonthStart)) {
      thisMonth += e.amount;
    } else if (!d.isBefore(lastMonthStart)) {
      lastMonth += e.amount;
    }
  }

  return ExpenseSummary(
    total: total,
    thisMonth: thisMonth,
    lastMonth: lastMonth,
    count: expenses.length,
    average: total / expenses.length,
  );
});

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.total,
    required this.share,
  });

  final String category;
  final double total;

  /// 0..1 of the overall spend.
  final double share;
}

/// Sorted biggest first — drives the breakdown chart.
/// Deliberately ignores the category filter so the chart always shows the
/// full picture (the filter only narrows the list below it).
final categoryTotalsProvider = Provider<List<CategoryTotal>>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? const <Expense>[];
  if (expenses.isEmpty) return const <CategoryTotal>[];

  final sums = <String, double>{};
  var total = 0.0;
  for (final e in expenses) {
    sums[e.category] = (sums[e.category] ?? 0) + e.amount;
    total += e.amount;
  }

  final list = sums.entries
      .map((e) => CategoryTotal(
            category: e.key,
            total: e.value,
            share: total == 0 ? 0 : e.value / total,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return list;
});

class MonthlyTotal {
  const MonthlyTotal({required this.month, required this.total});

  final DateTime month;
  final double total;
}

/// Last 6 months including the current one, oldest first.
final monthlyTotalsProvider = Provider<List<MonthlyTotal>>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? const <Expense>[];
  final now = DateTime.now();
  final months =
      List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));
  final sums = <DateTime, double>{for (final m in months) m: 0.0};

  for (final e in expenses) {
    final d = e.date;
    if (d == null) continue;
    final key = DateTime(d.year, d.month, 1);
    if (sums.containsKey(key)) sums[key] = sums[key]! + e.amount;
  }

  return [
    for (final m in months) MonthlyTotal(month: m, total: sums[m]!),
  ];
});

/// The list actually rendered: category filter + search applied.
final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final all = ref.watch(expensesStreamProvider).value ?? const <Expense>[];
  final filter = ref.watch(expenseFilterProvider);
  final query = ref.watch(expenseSearchProvider).trim().toLowerCase();

  return all.where((e) {
    if (filter != 'all' && e.category != filter) return false;
    if (query.isEmpty) return true;
    return e.description.toLowerCase().contains(query) ||
        (e.cropName?.toLowerCase().contains(query) ?? false) ||
        (e.location?.toLowerCase().contains(query) ?? false);
  }).toList();
});

/// Kept for the dashboard.
final expenseTotalsProvider = Provider<Map<String, double>>((ref) {
  final totals = <String, double>{};
  for (final t in ref.watch(categoryTotalsProvider)) {
    totals[t.category] = t.total;
  }
  return totals;
});