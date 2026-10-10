import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/data/expense_model.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../expenses/widgets/expense_category_style.dart';
import '../../farms/data/farm_model.dart';
import '../../farms/providers/farm_provider.dart';
import '../../greenhouses/data/greenhouse_model.dart';
import '../../greenhouses/providers/greenhouse_provider.dart';
import '../../harvests/data/harvest_model.dart';
import '../../harvests/data/harvest_style.dart';
import '../../harvests/providers/harvest_provider.dart';
import '../../labour/data/labour_model.dart';
import '../../labour/providers/labour_provider.dart';
import '../../sales/data/sale_model.dart';
import '../../sales/providers/sale_provider.dart';
import '../data/report_models.dart';

// ---------------------------------------------------------------------------
// Range — single source of truth for the screen
// ---------------------------------------------------------------------------
final expenseReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last3Months),
);

// ---------------------------------------------------------------------------
// Filtered source lists
// ---------------------------------------------------------------------------

/// Expenses inside the selected range.
/// "All time" keeps un-dated entries; a bounded range requires a date.
final expensesInRangeProvider = Provider<List<Expense>>((ref) {
  final all = ref.watch(expensesStreamProvider).value ?? const <Expense>[];
  final range = ref.watch(expenseReportRangeProvider);
  if (range.preset == ReportPreset.allTime) return all.toList();
  return all.where((e) => range.contains(e.date)).toList();
});

/// Expenses inside the equivalent previous window — used for comparison.
final expensesInPreviousRangeProvider = Provider<List<Expense>>((ref) {
  final all = ref.watch(expensesStreamProvider).value ?? const <Expense>[];
  final range = ref.watch(expenseReportRangeProvider);
  if (!range.hasPrevious) return const <Expense>[];
  final prev = range.previous;
  return all.where((e) => prev.contains(e.date)).toList();
});

// ---------------------------------------------------------------------------
// KPIs
// ---------------------------------------------------------------------------
final expenseKpisProvider = Provider<ExpenseKpis>((ref) {
  final list = ref.watch(expensesInRangeProvider);
  if (list.isEmpty) return ExpenseKpis.empty;

  final amounts = list.map((e) => e.amount).toList()..sort();
  final total = amounts.fold<double>(0, (s, v) => s + v);
  final average = total / amounts.length;
  final median = _median(amounts);
  final highest = amounts.last;

  final days = <int>{};
  for (final e in list) {
    final d = e.date;
    if (d != null) days.add(d.year * 10000 + d.month * 100 + d.day);
  }

  Expense? top;
  for (final e in list) {
    if (top == null || e.amount > top.amount) top = e;
  }

  return ExpenseKpis(
    total: total,
    count: amounts.length,
    average: average,
    median: median,
    highest: highest,
    activeDays: days.length,
    highestDescription: top?.description,
  );
});

double _median(List<double> sorted) {
  if (sorted.isEmpty) return 0;
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2];
  return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

final expenseDeltaProvider = Provider<PeriodDelta>((ref) {
  final current = ref.watch(expenseKpisProvider).total;
  final previous = ref.watch(expensesInPreviousRangeProvider)
      .fold<double>(0, (s, e) => s + e.amount);
  return PeriodDelta(current: current, previous: previous);
});

// ---------------------------------------------------------------------------
// Category breakdown
// ---------------------------------------------------------------------------
final expenseCategoryBreakdownProvider = Provider<List<BreakdownRow>>((ref) {
  final list = ref.watch(expensesInRangeProvider);
  if (list.isEmpty) return const <BreakdownRow>[];

  final sums = <String, double>{};
  final counts = <String, int>{};
  var total = 0.0;

  for (final e in list) {
    sums[e.category] = (sums[e.category] ?? 0) + e.amount;
    counts[e.category] = (counts[e.category] ?? 0) + 1;
    total += e.amount;
  }

  return sums.entries.map((entry) {
    final t = entry.value;
    final c = counts[entry.key] ?? 0;
    return BreakdownRow(
      key: entry.key,
      label: ExpenseCategories.of(entry.key).label,
      count: c,
      total: t,
      share: total == 0 ? 0 : t / total,
      average: c == 0 ? 0 : t / c,
    );
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));
});

// ---------------------------------------------------------------------------
// Monthly trend — capped at 24 buckets so "All" stays readable
// ---------------------------------------------------------------------------
final expenseMonthlyTrendProvider = Provider<List<TrendPoint>>((ref) {
  final list = ref.watch(expensesInRangeProvider);
  final range = ref.watch(expenseReportRangeProvider);

  var start = DateTime(range.start.year, range.start.month, 1);
  final end = DateTime(range.end.year, range.end.month, 1);
  final totalMonths =
      (end.year - start.year) * 12 + (end.month - start.month) + 1;
  if (totalMonths > 24) {
    start = DateTime(end.year, end.month - 23, 1);
  }

  final months = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  final sums = <DateTime, double>{for (final m in months) m: 0.0};
  final counts = <DateTime, int>{for (final m in months) m: 0};

  for (final e in list) {
    final d = e.date;
    if (d == null) continue;
    final key = DateTime(d.year, d.month, 1);
    if (sums.containsKey(key)) {
      sums[key] = sums[key]! + e.amount;
      counts[key] = counts[key]! + 1;
    }
  }

  return months
      .map((m) => TrendPoint(bucket: m, value: sums[m]!, count: counts[m]!))
      .toList();
});

// ---------------------------------------------------------------------------
// Top N biggest single expenses
// ---------------------------------------------------------------------------
final topExpensesProvider = Provider<List<Expense>>((ref) {
  final list = [...ref.watch(expensesInRangeProvider)];
  list.sort((a, b) => b.amount.compareTo(a.amount));
  return list.take(5).toList();
});

// ===========================================================================
// SALES
// ===========================================================================

/// Sales palette — index-based, since crops and buyers have no fixed colour.
const List<Color> salesPalette = [
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFF4511E),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFFFFA000),
  Color(0xFF5E35B1),
  Color(0xFF00ACC1),
  Color(0xFFE53935),
  Color(0xFF6D4C41),
];

Color salesColorAt(int index) =>
    salesPalette[index % salesPalette.length];

final salesReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last3Months),
);

final salesInRangeProvider = Provider<List<Sale>>((ref) {
  final all = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final range = ref.watch(salesReportRangeProvider);
  if (range.preset == ReportPreset.allTime) return all.toList();
  return all.where((s) => range.contains(s.saleDate)).toList();
});

final salesInPreviousRangeProvider = Provider<List<Sale>>((ref) {
  final all = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final range = ref.watch(salesReportRangeProvider);
  if (!range.hasPrevious) return const <Sale>[];
  final prev = range.previous;
  return all.where((s) => prev.contains(s.saleDate)).toList();
});

final salesKpisProvider = Provider<SalesKpis>((ref) {
  final list = ref.watch(salesInRangeProvider);
  if (list.isEmpty) return SalesKpis.empty;

  var revenue = 0.0;
  var pending = 0.0;
  var pendingCount = 0;
  var quantity = 0.0;
  var highest = 0.0;
  var count = 0;

  final unitCounts = <String, int>{};
  final buyerSums = <String, double>{};

  for (final s in list) {
    if (s.status == 'completed') {
      revenue += s.totalAmount;
      quantity += s.quantity;
      count++;
      if (s.totalAmount > highest) highest = s.totalAmount;
      unitCounts[s.unit] = (unitCounts[s.unit] ?? 0) + 1;
      if (s.buyer.isNotEmpty) {
        buyerSums[s.buyer] = (buyerSums[s.buyer] ?? 0) + s.totalAmount;
      }
    } else {
      pending += s.totalAmount;
      pendingCount++;
    }
  }

  final unit = unitCounts.isEmpty
      ? 'kg'
      : unitCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

  String? topBuyer;
  var topBuyerRevenue = 0.0;
  buyerSums.forEach((buyer, amount) {
    if (amount > topBuyerRevenue) {
      topBuyerRevenue = amount;
      topBuyer = buyer;
    }
  });

  return SalesKpis(
    revenue: revenue,
    count: count,
    average: count == 0 ? 0 : revenue / count,
    highest: highest,
    quantity: quantity,
    quantityUnit: unit,
    pendingAmount: pending,
    pendingCount: pendingCount,
    topBuyer: topBuyer,
    topBuyerRevenue: topBuyerRevenue,
  );
});

final salesDeltaProvider = Provider<PeriodDelta>((ref) {
  final current = ref.watch(salesKpisProvider).revenue;
  final previous = ref
      .watch(salesInPreviousRangeProvider)
      .where((s) => s.status == 'completed')
      .fold<double>(0, (sum, s) => sum + s.totalAmount);
  return PeriodDelta(current: current, previous: previous);
});

/// Generic breakdown over completed sales for a chosen key extractor.
List<BreakdownRow> _salesBreakdown(
  List<Sale> sales,
  String Function(Sale) keyOf,
  String Function(Sale) labelOf,
) {
  final sums = <String, double>{};
  final counts = <String, int>{};
  final labels = <String, String>{};
  var total = 0.0;

  for (final s in sales) {
    if (s.status != 'completed') continue;
    final k = keyOf(s);
    if (k.isEmpty) continue;
    sums[k] = (sums[k] ?? 0) + s.totalAmount;
    counts[k] = (counts[k] ?? 0) + 1;
    labels.putIfAbsent(k, () => labelOf(s));
    total += s.totalAmount;
  }

  return sums.entries.map((e) {
    final c = counts[e.key] ?? 0;
    return BreakdownRow(
      key: e.key,
      label: labels[e.key] ?? e.key,
      count: c,
      total: e.value,
      share: total == 0 ? 0 : e.value / total,
      average: c == 0 ? 0 : e.value / c,
    );
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));
}

final salesByCropProvider = Provider<List<BreakdownRow>>((ref) {
  final list = ref.watch(salesInRangeProvider);
  if (list.isEmpty) return const <BreakdownRow>[];
  return _salesBreakdown(list, (s) => s.cropName, (s) => s.cropName);
});

final salesByBuyerProvider = Provider<List<BreakdownRow>>((ref) {
  final list = ref.watch(salesInRangeProvider);
  if (list.isEmpty) return const <BreakdownRow>[];
  return _salesBreakdown(list, (s) => s.buyer, (s) => s.buyer);
});

final salesMonthlyTrendProvider = Provider<List<TrendPoint>>((ref) {
  final list = ref.watch(salesInRangeProvider);
  final range = ref.watch(salesReportRangeProvider);

  var start = DateTime(range.start.year, range.start.month, 1);
  final end = DateTime(range.end.year, range.end.month, 1);
  final totalMonths =
      (end.year - start.year) * 12 + (end.month - start.month) + 1;
  if (totalMonths > 24) {
    start = DateTime(end.year, end.month - 23, 1);
  }

  final months = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  final sums = <DateTime, double>{for (final m in months) m: 0.0};
  final counts = <DateTime, int>{for (final m in months) m: 0};

  for (final s in list) {
    if (s.status != 'completed') continue;
    final d = s.saleDate;
    if (d == null) continue;
    final key = DateTime(d.year, d.month, 1);
    if (sums.containsKey(key)) {
      sums[key] = sums[key]! + s.totalAmount;
      counts[key] = counts[key]! + 1;
    }
  }

  return months
      .map((m) => TrendPoint(bucket: m, value: sums[m]!, count: counts[m]!))
      .toList();
});

final topSalesProvider = Provider<List<Sale>>((ref) {
  final list = ref
      .watch(salesInRangeProvider)
      .where((s) => s.status == 'completed')
      .toList()
    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  return list.take(5).toList();
});

// ===========================================================================
// LABOUR
// ===========================================================================

final labourReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last3Months),
);

final labourInRangeProvider = Provider<List<Labour>>((ref) {
  final all = ref.watch(labourStreamProvider).value ?? const <Labour>[];
  final range = ref.watch(labourReportRangeProvider);
  if (range.preset == ReportPreset.allTime) return all.toList();
  return all.where((l) => range.contains(l.date)).toList();
});

final labourInPreviousRangeProvider = Provider<List<Labour>>((ref) {
  final all = ref.watch(labourStreamProvider).value ?? const <Labour>[];
  final range = ref.watch(labourReportRangeProvider);
  if (!range.hasPrevious) return const <Labour>[];
  final prev = range.previous;
  return all.where((l) => prev.contains(l.date)).toList();
});

final labourKpisProvider = Provider<LabourKpis>((ref) {
  final list = ref.watch(labourInRangeProvider);
  if (list.isEmpty) return LabourKpis.empty;

  var total = 0.0;
  var paid = 0.0;
  var pending = 0.0;
  var days = 0.0;
  var pendingRecords = 0;

  final workers = <String>{};
  final workerCost = <String, double>{};

  for (final l in list) {
    total += l.totalAmount;
    paid += l.amountPaid;
    pending += l.pendingAmount;
    days += l.daysWorked;
    if (l.pendingAmount > 0) pendingRecords++;
    if (l.workerName.isNotEmpty) {
      workers.add(l.workerName.toLowerCase());
      workerCost[l.workerName] =
          (workerCost[l.workerName] ?? 0) + l.totalAmount;
    }
  }

  String? topWorker;
  var topCost = 0.0;
  workerCost.forEach((w, c) {
    if (c > topCost) {
      topCost = c;
      topWorker = w;
    }
  });

  return LabourKpis(
    totalCost: total,
    paid: paid,
    pending: pending,
    totalRecords: list.length,
    pendingRecords: pendingRecords,
    workerCount: workers.length,
    totalDays: days,
    averageDailyRate: days == 0 ? 0 : total / days,
    averagePerRecord: total / list.length,
    topWorker: topWorker,
    topWorkerCost: topCost,
  );
});

final labourDeltaProvider = Provider<PeriodDelta>((ref) {
  final current = ref.watch(labourKpisProvider).totalCost;
  final previous = ref
      .watch(labourInPreviousRangeProvider)
      .fold<double>(0, (s, l) => s + l.totalAmount);
  return PeriodDelta(current: current, previous: previous);
});

List<BreakdownRow> _labourBreakdown(
  List<Labour> records,
  String Function(Labour) keyOf,
  String Function(Labour) labelOf,
) {
  final sums = <String, double>{};
  final counts = <String, int>{};
  final labels = <String, String>{};
  var total = 0.0;

  for (final l in records) {
    final k = keyOf(l);
    if (k.isEmpty) continue;
    sums[k] = (sums[k] ?? 0) + l.totalAmount;
    counts[k] = (counts[k] ?? 0) + 1;
    labels.putIfAbsent(k, () => labelOf(l));
    total += l.totalAmount;
  }

  return sums.entries.map((e) {
    final c = counts[e.key] ?? 0;
    return BreakdownRow(
      key: e.key,
      label: labels[e.key] ?? e.key,
      count: c,
      total: e.value,
      share: total == 0 ? 0 : e.value / total,
      average: c == 0 ? 0 : e.value / c,
    );
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));
}

final labourByWorkerProvider = Provider<List<BreakdownRow>>((ref) {
  final list = ref.watch(labourInRangeProvider);
  if (list.isEmpty) return const <BreakdownRow>[];
  return _labourBreakdown(list, (l) => l.workerName, (l) => l.workerName);
});

final labourByTaskProvider = Provider<List<BreakdownRow>>((ref) {
  final list = ref.watch(labourInRangeProvider);
  if (list.isEmpty) return const <BreakdownRow>[];
  return _labourBreakdown(list, (l) => l.task, (l) => l.task);
});

final labourMonthlyTrendProvider = Provider<List<TrendPoint>>((ref) {
  final list = ref.watch(labourInRangeProvider);
  final range = ref.watch(labourReportRangeProvider);

  var start = DateTime(range.start.year, range.start.month, 1);
  final end = DateTime(range.end.year, range.end.month, 1);
  final totalMonths =
      (end.year - start.year) * 12 + (end.month - start.month) + 1;
  if (totalMonths > 24) {
    start = DateTime(end.year, end.month - 23, 1);
  }

  final months = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  final sums = <DateTime, double>{for (final m in months) m: 0.0};
  final counts = <DateTime, int>{for (final m in months) m: 0};

  for (final l in list) {
    final d = l.date;
    if (d == null) continue;
    final key = DateTime(d.year, d.month, 1);
    if (sums.containsKey(key)) {
      sums[key] = sums[key]! + l.totalAmount;
      counts[key] = counts[key]! + 1;
    }
  }

  return months
      .map((m) => TrendPoint(bucket: m, value: sums[m]!, count: counts[m]!))
      .toList();
});

final topLabourProvider = Provider<List<Labour>>((ref) {
  final list = [...ref.watch(labourInRangeProvider)]
    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  return list.take(5).toList();
});

// ===========================================================================
// FINANCIAL SUMMARY
// ===========================================================================

/// One range drives sales, expenses and labour so the three numbers
/// can never drift apart on the same screen.
final financialReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last6Months),
);

/// Core aggregation — pure function over the three source lists and a range.
FinancialKpis _computeFinancial({
  required ReportRange range,
  required List<Sale> sales,
  required List<Expense> expenses,
  required List<Labour> labour,
}) {
  final allTime = range.preset == ReportPreset.allTime;

  var revenue = 0.0;
  var directExpenses = 0.0;
  var labourCost = 0.0;
  var labourExcluded = 0.0;

  for (final s in sales) {
    if (s.status != 'completed') continue;
    if (!allTime && !range.contains(s.saleDate)) continue;
    revenue += s.totalAmount;
  }

  for (final e in expenses) {
    if (!allTime && !range.contains(e.date)) continue;
    if (e.category == 'labour') {
      labourExcluded += e.amount;
    } else {
      directExpenses += e.amount;
    }
  }

  for (final l in labour) {
    if (!allTime && !range.contains(l.date)) continue;
    labourCost += l.totalAmount;
  }

  return FinancialKpis(
    revenue: revenue,
    expenses: directExpenses,
    labour: labourCost,
    labourExcluded: labourExcluded,
  );
}

final financialKpisProvider = Provider<FinancialKpis>((ref) {
  final range = ref.watch(financialReportRangeProvider);
  return _computeFinancial(
    range: range,
    sales: ref.watch(salesStreamProvider).value ?? const [],
    expenses: ref.watch(expensesStreamProvider).value ?? const [],
    labour: ref.watch(labourStreamProvider).value ?? const [],
  );
});

final financialPreviousKpisProvider = Provider<FinancialKpis>((ref) {
  final range = ref.watch(financialReportRangeProvider);
  if (!range.hasPrevious) return FinancialKpis.empty;
  return _computeFinancial(
    range: range.previous,
    sales: ref.watch(salesStreamProvider).value ?? const [],
    expenses: ref.watch(expensesStreamProvider).value ?? const [],
    labour: ref.watch(labourStreamProvider).value ?? const [],
  );
});

/// Net profit delta vs the previous window.
final financialProfitDeltaProvider = Provider<PeriodDelta>((ref) {
  final current = ref.watch(financialKpisProvider).netProfit;
  final previous = ref.watch(financialPreviousKpisProvider).netProfit;
  return PeriodDelta(current: current, previous: previous);
});

/// Monthly revenue vs cost pairs for the dual bar chart.
final financialTrendProvider = Provider<List<DualTrendPoint>>((ref) {
  final range = ref.watch(financialReportRangeProvider);
  final allTime = range.preset == ReportPreset.allTime;

  final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final expenses = ref.watch(expensesStreamProvider).value ?? const <Expense>[];
  final labour = ref.watch(labourStreamProvider).value ?? const <Labour>[];

  var start = DateTime(range.start.year, range.start.month, 1);
  final end = DateTime(range.end.year, range.end.month, 1);
  final totalMonths =
      (end.year - start.year) * 12 + (end.month - start.month) + 1;
  if (totalMonths > 24) {
    start = DateTime(end.year, end.month - 23, 1);
  }

  final months = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  final revBuckets = <DateTime, double>{for (final m in months) m: 0.0};
  final costBuckets = <DateTime, double>{for (final m in months) m: 0.0};

  DateTime? bucketOf(DateTime? d) {
    if (d == null) return null;
    final key = DateTime(d.year, d.month, 1);
    return revBuckets.containsKey(key) ? key : null;
  }

  for (final s in sales) {
    if (s.status != 'completed') continue;
    if (!allTime && !range.contains(s.saleDate)) continue;
    final k = bucketOf(s.saleDate);
    if (k != null) revBuckets[k] = revBuckets[k]! + s.totalAmount;
  }
  for (final e in expenses) {
    if (e.category == 'labour') continue;
    if (!allTime && !range.contains(e.date)) continue;
    final k = bucketOf(e.date);
    if (k != null) costBuckets[k] = costBuckets[k]! + e.amount;
  }
  for (final l in labour) {
    if (!allTime && !range.contains(l.date)) continue;
    final k = bucketOf(l.date);
    if (k != null) costBuckets[k] = costBuckets[k]! + l.totalAmount;
  }

  return months
      .map((m) => DualTrendPoint(
            bucket: m,
            revenue: revBuckets[m]!,
            cost: costBuckets[m]!,
          ))
      .toList();
});

// ===========================================================================
// HARVEST
// ===========================================================================

final harvestReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last6Months),
);

final harvestsInRangeProvider = Provider<List<Harvest>>((ref) {
  final all = ref.watch(harvestsStreamProvider).value ?? const <Harvest>[];
  final range = ref.watch(harvestReportRangeProvider);
  if (range.preset == ReportPreset.allTime) return all.toList();
  return all.where((h) => range.contains(h.harvestDate)).toList();
});

final harvestsInPreviousRangeProvider = Provider<List<Harvest>>((ref) {
  final all = ref.watch(harvestsStreamProvider).value ?? const <Harvest>[];
  final range = ref.watch(harvestReportRangeProvider);
  if (!range.hasPrevious) return const <Harvest>[];
  final prev = range.previous;
  return all.where((h) => prev.contains(h.harvestDate)).toList();
});

/// Dominant unit across a list of harvests.
String _dominantUnit(List<Harvest> list) {
  if (list.isEmpty) return 'kg';
  final counts = <String, int>{};
  for (final h in list) {
    counts[h.unit] = (counts[h.unit] ?? 0) + 1;
  }
  return counts.entries
      .reduce((a, b) => a.value >= b.value ? a : b)
      .key;
}

/// Net yield for a list of harvests, restricted to a given unit.
double _netYieldFor(List<Harvest> list, String unit) {
  var total = 0.0;
  for (final h in list) {
    if (h.unit != unit) continue;
    total += (h.quantity - h.wastedQuantity)
        .clamp(0, double.infinity)
        .toDouble();
  }
  return total;
}

final harvestKpisProvider = Provider<HarvestKpis>((ref) {
  final list = ref.watch(harvestsInRangeProvider);
  if (list.isEmpty) return HarvestKpis.empty;

  final unit = _dominantUnit(list);
  final mixed = list.any((h) => h.unit != unit);

  var gross = 0.0;
  var wasted = 0.0;
  var net = 0.0;
  final days = <int>{};
  final cropYield = <String, double>{};

  for (final h in list) {
    if (h.unit != unit) continue;
    final g = h.quantity;
    final w = h.wastedQuantity.clamp(0.0, g).toDouble();
    final n = (g - w).clamp(0, double.infinity).toDouble();

    gross += g;
    wasted += w;
    net += n;

    final d = h.harvestDate;
    if (d != null) {
      days.add(d.year * 10000 + d.month * 100 + d.day);
    }
    if (h.cropName.isNotEmpty) {
      cropYield[h.cropName] = (cropYield[h.cropName] ?? 0) + n;
    }
  }

  String? topCrop;
  var topYield = 0.0;
  cropYield.forEach((crop, y) {
    if (y > topYield) {
      topYield = y;
      topCrop = crop;
    }
  });

  return HarvestKpis(
    grossYield: gross,
    netYield: net,
    wasted: wasted,
    dominantUnit: unit,
    hasMixedUnits: mixed,
    count: list.length,
    activeDays: days.length,
    averageNet: list.isEmpty ? 0 : net / list.length,
    wasteRatio: gross <= 0 ? 0 : wasted / gross,
    topCrop: topCrop,
    topCropYield: topYield,
  );
});

final harvestDeltaProvider = Provider<PeriodDelta>((ref) {
  final range = ref.watch(harvestReportRangeProvider);
  final current = ref.watch(harvestKpisProvider);

  if (!range.hasPrevious) {
    return PeriodDelta(current: current.netYield, previous: 0);
  }

  final prevList = ref.watch(harvestsInPreviousRangeProvider);
  final prevUnit = _dominantUnit(prevList);
  final prevNet = _netYieldFor(prevList, prevUnit);

  // Compare within the *current* dominant unit — the only fair comparison.
  return PeriodDelta(current: current.netYield, previous: prevNet);
});

/// Group by crop with per-crop dominant unit so mixed-unit crops stay honest.
final harvestByCropProvider = Provider<List<BreakdownRow>>((ref) {
  final list = ref.watch(harvestsInRangeProvider);
  if (list.isEmpty) return const <BreakdownRow>[];

  // Bucket: crop → unit → {gross, wasted, count}
  final buckets = <String, Map<String, _CropBucket>>{};

  for (final h in list) {
    if (h.cropName.isEmpty) continue;
    final cropMap = buckets.putIfAbsent(h.cropName, () => {});
    final b = cropMap.putIfAbsent(h.unit, () => _CropBucket());
    final w = h.wastedQuantity.clamp(0.0, h.quantity).toDouble();
    b.gross += h.quantity;
    b.wasted += w;
    b.count += 1;
  }

  // Pick dominant unit per crop, emit a row.
  var grandTotal = 0.0;
  final rows = <BreakdownRow>[];
  final unitForRow = <String, String>{};

  buckets.forEach((crop, byUnit) {
    final dominant = byUnit.entries
        .reduce((a, b) => a.value.count >= b.value.count ? a : b)
        .key;
    final b = byUnit[dominant]!;
    final net = (b.gross - b.wasted).clamp(0, double.infinity).toDouble();
    grandTotal += net;

    unitForRow[crop] = dominant;
    rows.add(BreakdownRow(
      key: crop,
      label: crop,
      count: b.count,
      total: net,
      share: 0, // filled after we know the total
      average: b.count == 0 ? 0 : net / b.count,
    ));
  });

  // Normalise shares.
  final normalised = rows
      .map((r) => BreakdownRow(
            key: r.key,
            label: r.label,
            count: r.count,
            total: r.total,
            share: grandTotal == 0 ? 0 : r.total / grandTotal,
            average: r.average,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return normalised;
});

/// Human-readable unit per crop, exposed for the report UI.
final harvestCropUnitsProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(harvestsInRangeProvider);
  final result = <String, String>{};
  final counts = <String, Map<String, int>>{};

  for (final h in list) {
    if (h.cropName.isEmpty) continue;
    final m = counts.putIfAbsent(h.cropName, () => {});
    m[h.unit] = (m[h.unit] ?? 0) + 1;
  }

  counts.forEach((crop, byUnit) {
    result[crop] = byUnit.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  });
  return result;
});

/// Grade split — always the 3 canonical grades, even when one is empty.
final harvestByGradeProvider = Provider<List<BreakdownRow>>((ref) {
  final list = ref.watch(harvestsInRangeProvider);
  if (list.isEmpty) return const <BreakdownRow>[];

  final sums = <String, double>{'A': 0, 'B': 0, 'C': 0};
  final counts = <String, int>{'A': 0, 'B': 0, 'C': 0};
  var total = 0.0;

  for (final h in list) {
    final g = h.grade.toUpperCase();
    if (!sums.containsKey(g)) continue;
    final net = (h.quantity - h.wastedQuantity.clamp(0.0, h.quantity))
        .clamp(0, double.infinity)
        .toDouble();
    sums[g] = sums[g]! + net;
    counts[g] = counts[g]! + 1;
    total += net;
  }

  return ['A', 'B', 'C']
      .where((g) => counts[g]! > 0)
      .map((g) => BreakdownRow(
            key: g,
            label: 'Grade $g',
            count: counts[g]!,
            total: sums[g]!,
            share: total == 0 ? 0 : sums[g]! / total,
            average: counts[g] == 0 ? 0 : sums[g]! / counts[g]!,
          ))
      .toList();
});

/// Net vs wasted per month, for the dual bar chart.
final harvestTrendProvider = Provider<List<DualTrendPoint>>((ref) {
  final range = ref.watch(harvestReportRangeProvider);
  final allTime = range.preset == ReportPreset.allTime;
  final list = ref.watch(harvestsInRangeProvider);

  // Trend follows the dominant unit of the whole period — the only
  // comparison that doesn't mix apples and oranges.
  final unit = _dominantUnit(list);

  var start = DateTime(range.start.year, range.start.month, 1);
  final end = DateTime(range.end.year, range.end.month, 1);
  final totalMonths =
      (end.year - start.year) * 12 + (end.month - start.month) + 1;
  if (totalMonths > 24) {
    start = DateTime(end.year, end.month - 23, 1);
  }

  final months = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  final netBuckets = <DateTime, double>{for (final m in months) m: 0.0};
  final wasteBuckets = <DateTime, double>{for (final m in months) m: 0.0};

  for (final h in list) {
    if (h.unit != unit) continue;
    final d = h.harvestDate;
    if (d == null) continue;
    final key = DateTime(d.year, d.month, 1);
    if (!netBuckets.containsKey(key)) continue;
    final w = h.wastedQuantity.clamp(0.0, h.quantity).toDouble();
    final n = (h.quantity - w).clamp(0, double.infinity).toDouble();
    netBuckets[key] = netBuckets[key]! + n;
    wasteBuckets[key] = wasteBuckets[key]! + w;
  }

  return months
      .map((m) => DualTrendPoint(
            bucket: m,
            revenue: netBuckets[m]!,
            cost: wasteBuckets[m]!,
          ))
      .toList();
});

/// Biggest harvests by net yield.
final topHarvestsProvider = Provider<List<Harvest>>((ref) {
  final list = [...ref.watch(harvestsInRangeProvider)]
    ..sort((a, b) {
      final aNet = (a.quantity - a.wastedQuantity)
          .clamp(0, double.infinity)
          .toDouble();
      final bNet = (b.quantity - b.wastedQuantity)
          .clamp(0, double.infinity)
          .toDouble();
      return bNet.compareTo(aNet);
    });
  return list.take(5).toList();
});

/// Small internal helper for the crop-bucket aggregation.
class _CropBucket {
  double gross = 0;
  double wasted = 0;
  int count = 0;
}

// ===========================================================================
// FARM REPORT
// ===========================================================================

final farmReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last6Months),
);

/// Fetches subcollection data for every farm and aggregates per farm.
///
/// This is intentionally a FutureProvider (not Stream) — we fan out several
/// queries per farm, and re-running on every Firestore tick would be wasteful.
/// Pull-to-refresh on the screen invalidates it.
final farmReportProvider = FutureProvider<List<FarmFinancials>>((ref) async {
  final farms = await ref.watch(farmsStreamProvider.future);
  final range = ref.watch(farmReportRangeProvider);
  final allTime = range.preset == ReportPreset.allTime;
  final db = FirebaseFirestore.instance;

  final futures = farms.map((farm) async {
    final results = await Future.wait([
      db.collection('farms').doc(farm.id).collection('sales').get(),
      db.collection('farms').doc(farm.id).collection('expenses').get(),
      db.collection('farms').doc(farm.id).collection('labour').get(),
      db.collection('farms').doc(farm.id).collection('harvests').get(),
    ]);

    // --- Sales ---
    var revenue = 0.0;
    var saleCount = 0;
    for (final doc in results[0].docs) {
      final d = doc.data();
      if (d['status'] != 'completed') continue;
      final date = (d['saleDate'] as Timestamp?)?.toDate();
      if (!allTime && !range.contains(date)) continue;
      revenue += (d['totalAmount'] ?? 0).toDouble();
      saleCount++;
    }

    // --- Expenses (labour-category excluded) ---
    var directExpenses = 0.0;
    var expenseCount = 0;
    for (final doc in results[1].docs) {
      final d = doc.data();
      if (d['category'] == 'labour') continue;
      final date = (d['date'] as Timestamp?)?.toDate();
      if (!allTime && !range.contains(date)) continue;
      directExpenses += (d['amount'] ?? 0).toDouble();
      expenseCount++;
    }

    // --- Labour ---
    var labourCost = 0.0;
    var labourCount = 0;
    for (final doc in results[2].docs) {
      final d = doc.data();
      final date = (d['date'] as Timestamp?)?.toDate();
      if (!allTime && !range.contains(date)) continue;
      labourCost += (d['totalAmount'] ?? 0).toDouble();
      labourCount++;
    }

    // --- Harvests (dominant unit) ---
    final inRange = <Map<String, dynamic>>[];
    for (final doc in results[3].docs) {
      final d = doc.data();
      final date = (d['harvestDate'] as Timestamp?)?.toDate();
      if (!allTime && !range.contains(date)) continue;
      inRange.add(d);
    }
    final unitCounts = <String, int>{};
    for (final d in inRange) {
      final u = d['unit'] as String? ?? 'kg';
      unitCounts[u] = (unitCounts[u] ?? 0) + 1;
    }
    final dominant = unitCounts.isEmpty
        ? 'kg'
        : unitCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

    var gross = 0.0;
    var net = 0.0;
    for (final d in inRange) {
      if ((d['unit'] as String? ?? 'kg') != dominant) continue;
      final qty = (d['quantity'] ?? 0).toDouble();
      final wasted = ((d['wastedQuantity'] ?? 0) as num)
          .toDouble()
          .clamp(0.0, qty)
          .toDouble();
      gross += qty;
      net += qty - wasted;
    }

    return FarmFinancials(
      farmId: farm.id,
      farmName: farm.farmName,
      type: farm.type,
      location: farm.location,
      acreage: farm.acreage,
      revenue: revenue,
      expenses: directExpenses,
      labour: labourCost,
      grossYield: gross,
      netYield: net,
      yieldUnit: dominant,
      saleCount: saleCount,
      expenseCount: expenseCount,
      labourCount: labourCount,
      harvestCount: inRange.length,
    );
  });

  final list = await Future.wait(futures);
  list.sort((a, b) => b.profit.compareTo(a.profit));
  return list;
});

// ===========================================================================
// CROP REPORT
// ===========================================================================

final cropReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last6Months),
);

/// Aggregates crop data across all farms by crop name.
///
/// Each farm's crops, harvests, sales, expenses and labour subcollections
/// are queried in parallel, then bucketed by crop name (case-sensitive —
/// the model uses consistent naming).
final cropReportProvider = FutureProvider<List<CropFinancials>>((ref) async {
  final farms = await ref.watch(farmsStreamProvider.future);
  final range = ref.watch(cropReportRangeProvider);
  final allTime = range.preset == ReportPreset.allTime;
  final db = FirebaseFirestore.instance;

  // Structure: cropName → {field → accumulated value}
  final data = <String, _CropAccumulator>{};

  _CropAccumulator getAcc(String name) =>
      data.putIfAbsent(name, () => _CropAccumulator());

  for (final farm in farms) {
    final results = await Future.wait([
      db.collection('farms').doc(farm.id).collection('crops').get(),
      db.collection('farms').doc(farm.id).collection('harvests').get(),
      db.collection('farms').doc(farm.id).collection('sales').get(),
      db.collection('farms').doc(farm.id).collection('expenses').get(),
      db.collection('farms').doc(farm.id).collection('labour').get(),
    ]);

    // --- Crops (entries per crop) ---
    for (final doc in results[0].docs) {
      final d = doc.data();
      final name = (d['cropName'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      getAcc(name).cropCount++;
    }

    // --- Harvests (gross, wasted, unit) ---
    for (final doc in results[1].docs) {
      final d = doc.data();
      final name = (d['cropName'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final date = (d['harvestDate'] as Timestamp?)?.toDate();
      if (!allTime && !range.contains(date)) continue;
      final unit = d['unit'] as String? ?? 'kg';
      final qty = (d['quantity'] ?? 0).toDouble();
      final wasted = ((d['wastedQuantity'] ?? 0) as num)
          .toDouble()
          .clamp(0.0, qty)
          .toDouble();
      final acc = getAcc(name);
      acc.unitCounts[unit] = (acc.unitCounts[unit] ?? 0) + 1;
      // Store per-unit buckets so we can pick the dominant unit later.
      acc.perUnitGross.update(unit, (v) => v + qty, ifAbsent: () => qty);
      acc.perUnitWaste
          .update(unit, (v) => v + wasted, ifAbsent: () => wasted);
      acc.harvestCount++;
    }

    // --- Sales (revenue, quantity sold, unit) ---
    for (final doc in results[2].docs) {
      final d = doc.data();
      if (d['status'] != 'completed') continue;
      final name = (d['cropName'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final date = (d['saleDate'] as Timestamp?)?.toDate();
      if (!allTime && !range.contains(date)) continue;
      final acc = getAcc(name);
      acc.revenue += (d['totalAmount'] ?? 0).toDouble();
      acc.soldQty += (d['quantity'] ?? 0).toDouble();
      acc.saleCount++;
    }

    // --- Expenses (matched by cropName field if present) ---
    for (final doc in results[3].docs) {
      final d = doc.data();
      if (d['category'] == 'labour') continue;
      final name = (d['cropName'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final date = (d['date'] as Timestamp?)?.toDate();
      if (!allTime && !range.contains(date)) continue;
      getAcc(name).expenses += (d['amount'] ?? 0).toDouble();
    }

    // --- Labour (matched by task? skip — labour has no cropName field) ---
    // Labour records don't carry a cropName, so we cannot attribute them
    // per crop reliably. We deliberately skip them here to avoid inventing
    // attribution. The Farm and Financial reports handle labour correctly.
  }

  final list = data.entries.map((entry) {
    final acc = entry.value;
    final unit = acc.dominantUnit;
    final gross = acc.perUnitGross[unit] ?? 0;
    final wasted = acc.perUnitWaste[unit] ?? 0;
    final net = (gross - wasted).clamp(0, double.infinity).toDouble();

    return CropFinancials(
      cropName: entry.key,
      dominantUnit: unit,
      revenue: acc.revenue,
      expenses: acc.expenses,
      labour: 0, // not attributable per crop
      grossYield: gross,
      netYield: net,
      wasted: wasted,
      cropCount: acc.cropCount,
      harvestCount: acc.harvestCount,
      saleCount: acc.saleCount,
      averagePricePerUnit:
          acc.soldQty > 0 ? acc.revenue / acc.soldQty : 0,
      wasteRatio: gross <= 0 ? 0 : wasted / gross,
    );
  }).toList()
    ..sort((a, b) => b.profit.compareTo(a.profit));

  return list;
});

class _CropAccumulator {
  double revenue = 0;
  double expenses = 0;
  double soldQty = 0;
  int cropCount = 0;
  int harvestCount = 0;
  int saleCount = 0;

  /// unit → count of harvests in that unit.
  final Map<String, int> unitCounts = {};

  /// unit → gross yield
  final Map<String, double> perUnitGross = {};

  /// unit → wasted
  final Map<String, double> perUnitWaste = {};

  /// Dominant unit by harvest record count.
  String get dominantUnit {
    if (unitCounts.isEmpty) return 'kg';
    return unitCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }
}

// ===========================================================================
// GREENHOUSE REPORT
// ===========================================================================

final greenhouseReportRangeProvider = StateProvider<ReportRange>(
  (ref) => ReportRange.fromPreset(ReportPreset.last6Months),
);

/// Aggregates per-greenhouse performance by matching `location` on
/// harvests/sales/expenses/labour against greenhouse names.
///
/// Matching is case-insensitive and trimmed to be forgiving of slight
/// formatting differences.
final greenhouseReportProvider =
    FutureProvider<List<GreenhouseFinancials>>((ref) async {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const [];

  final range = ref.watch(greenhouseReportRangeProvider);
  final allTime = range.preset == ReportPreset.allTime;
  final db = FirebaseFirestore.instance;

  // 1. Load all greenhouses for this farm and index by lowercase name.
  final ghSnap =
      await db.collection('farms').doc(farmId).collection('greenhouses').get();
  final greenhouses = ghSnap.docs
      .map((d) => Greenhouse.fromFirestore(d, farmId))
      .toList();

  if (greenhouses.isEmpty) return const [];

  final byName = <String, Greenhouse>{};
  for (final gh in greenhouses) {
    byName[gh.name.trim().toLowerCase()] = gh;
  }

  // 2. Pull the four source collections in parallel.
  final results = await Future.wait([
    db.collection('farms').doc(farmId).collection('harvests').get(),
    db.collection('farms').doc(farmId).collection('sales').get(),
    db.collection('farms').doc(farmId).collection('expenses').get(),
    db.collection('farms').doc(farmId).collection('labour').get(),
  ]);

  // 3. Accumulate per greenhouse.
  final acc = <String, _GhAccumulator>{
    for (final gh in greenhouses) gh.id: _GhAccumulator(gh),
  };

  void visit(
    String? location,
    void Function(Greenhouse gh, _GhAccumulator a) apply,
  ) {
    if (location == null) return;
    final key = location.trim().toLowerCase();
    if (key.isEmpty) return;
    final gh = byName[key];
    if (gh == null) return;
    final a = acc[gh.id];
    if (a == null) return;
    apply(gh, a);
  }

  // Harvests
  for (final doc in results[0].docs) {
    final d = doc.data();
    final date = (d['harvestDate'] as Timestamp?)?.toDate();
    if (!allTime && !range.contains(date)) continue;
    visit(d['location'] as String?, (gh, a) {
      final unit = d['unit'] as String? ?? 'kg';
      final qty = (d['quantity'] ?? 0).toDouble();
      final wasted = ((d['wastedQuantity'] ?? 0) as num)
          .toDouble()
          .clamp(0.0, qty)
          .toDouble();
      a.unitCounts[unit] = (a.unitCounts[unit] ?? 0) + 1;
      a.perUnitGross.update(unit, (v) => v + qty, ifAbsent: () => qty);
      a.perUnitWaste
          .update(unit, (v) => v + wasted, ifAbsent: () => wasted);
      a.harvestCount++;
    });
  }

  // Sales (completed only)
  for (final doc in results[1].docs) {
    final d = doc.data();
    if (d['status'] != 'completed') continue;
    final date = (d['saleDate'] as Timestamp?)?.toDate();
    if (!allTime && !range.contains(date)) continue;
    visit(d['location'] as String?, (gh, a) {
      a.revenue += (d['totalAmount'] ?? 0).toDouble();
      a.saleCount++;
    });
  }

  // Expenses (labour-category excluded to avoid double-counting)
  for (final doc in results[2].docs) {
    final d = doc.data();
    if (d['category'] == 'labour') continue;
    final date = (d['date'] as Timestamp?)?.toDate();
    if (!allTime && !range.contains(date)) continue;
    visit(d['location'] as String?, (gh, a) {
      a.expenses += (d['amount'] ?? 0).toDouble();
      a.expenseCount++;
    });
  }

  // Labour
  for (final doc in results[3].docs) {
    final d = doc.data();
    final date = (d['date'] as Timestamp?)?.toDate();
    if (!allTime && !range.contains(date)) continue;
    visit(d['location'] as String?, (gh, a) {
      a.labour += (d['totalAmount'] ?? 0).toDouble();
      a.labourCount++;
    });
  }

  return acc.values.map((a) => a.toFinancials()).toList()
    ..sort((x, y) {
      // Greenhouses with profit first, then largest profit per m².
      final a = x.profitPerSqm ?? -1;
      final b = y.profitPerSqm ?? -1;
      return b.compareTo(a);
    });
});

/// Internal accumulator. Kept private to this file.
class _GhAccumulator {
  _GhAccumulator(this.gh);
  final Greenhouse gh;

  double revenue = 0;
  double expenses = 0;
  double labour = 0;
  int harvestCount = 0;
  int saleCount = 0;
  int expenseCount = 0;
  int labourCount = 0;

  final Map<String, int> unitCounts = {};
  final Map<String, double> perUnitGross = {};
  final Map<String, double> perUnitWaste = {};

  String get dominantUnit {
    if (unitCounts.isEmpty) return 'kg';
    return unitCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  GreenhouseFinancials toFinancials() {
    final unit = dominantUnit;
    final gross = perUnitGross[unit] ?? 0;
    final wasted = perUnitWaste[unit] ?? 0;
    final net = (gross - wasted).clamp(0, double.infinity).toDouble();

    return GreenhouseFinancials(
      greenhouseId: gh.id,
      name: gh.name,
      size: gh.size,
      currentCrop: gh.currentCrop,
      plantCount: gh.plantCount,
      revenue: revenue,
      expenses: expenses,
      labour: labour,
      grossYield: gross,
      netYield: net,
      wasted: wasted,
      yieldUnit: unit,
      dominantUnit: unit,
      hasMixedUnits: unitCounts.length > 1,
      harvestCount: harvestCount,
      saleCount: saleCount,
      expenseCount: expenseCount,
      labourCount: labourCount,
    );
  }
}