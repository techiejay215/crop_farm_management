import 'package:flutter/foundation.dart';

// ===========================================================================
// Date ranges
// ===========================================================================

enum ReportPreset {
  last30Days,
  last3Months,
  last6Months,
  last12Months,
  yearToDate,
  allTime,
  custom,
}

extension ReportPresetX on ReportPreset {
  String get shortLabel {
    switch (this) {
      case ReportPreset.last30Days: return '30D';
      case ReportPreset.last3Months: return '3M';
      case ReportPreset.last6Months: return '6M';
      case ReportPreset.last12Months: return '1Y';
      case ReportPreset.yearToDate: return 'YTD';
      case ReportPreset.allTime: return 'All';
      case ReportPreset.custom: return 'Custom';
    }
  }
}

/// Inclusive calendar-day range. Everything time-based in reports goes
/// through this so "current vs previous period" stays consistent.
@immutable
class ReportRange {
  final ReportPreset preset;
  final DateTime start;
  final DateTime end;

  const ReportRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  factory ReportRange.fromPreset(
    ReportPreset preset, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case ReportPreset.last30Days:
        return ReportRange(
          preset: preset,
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case ReportPreset.last3Months:
        return ReportRange(
          preset: preset,
          start: _monthsBefore(today, 3),
          end: today,
        );
      case ReportPreset.last6Months:
        return ReportRange(
          preset: preset,
          start: _monthsBefore(today, 6),
          end: today,
        );
      case ReportPreset.last12Months:
        return ReportRange(
          preset: preset,
          start: _monthsBefore(today, 12),
          end: today,
        );
      case ReportPreset.yearToDate:
        return ReportRange(
          preset: preset,
          start: DateTime(today.year, 1, 1),
          end: today,
        );
      case ReportPreset.allTime:
        return ReportRange(
          preset: preset,
          start: DateTime(2000),
          end: today,
        );
      case ReportPreset.custom:
        return ReportRange(
          preset: preset,
          start: customStart ?? today,
          end: customEnd ?? today,
        );
    }
  }

  /// Accurate month subtraction that clamps to the last day of the target
  /// month (e.g. 31 May − 3 months = 28 Feb, not 3 Mar).
  static DateTime _monthsBefore(DateTime date, int months) {
    final total = date.year * 12 + (date.month - 1) - months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final d = date.day > lastDay ? lastDay : date.day;
    return DateTime(y, m, d);
  }

  int get days => end.difference(start).inDays + 1;

  bool contains(DateTime? d) {
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Same-length window ending the day before [start].
  ReportRange get previous {
    final prevEnd = start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: days - 1));
    return ReportRange(preset: preset, start: prevStart, end: prevEnd);
  }

  bool get hasPrevious => preset != ReportPreset.allTime;
}

// ===========================================================================
// Aggregation rows
// ===========================================================================

/// A single aggregated row — a category, a crop, a month, a payment method.
/// Deliberately generic so every report shares the same table widget.
@immutable
class BreakdownRow {
  final String key;
  final String label;
  final int count;
  final double total;
  final double share;   // 0..1
  final double average;
  const BreakdownRow({
    required this.key,
    required this.label,
    required this.count,
    required this.total,
    required this.share,
    required this.average,
  });
}

/// One bar in the trend chart.
@immutable
class TrendPoint {
  final DateTime bucket;
  final double value;
  final int count;
  const TrendPoint({
    required this.bucket,
    required this.value,
    required this.count,
  });
}

/// Current vs previous window — used for the "vs last period" strip.
@immutable
class PeriodDelta {
  final double current;
  final double previous;
  const PeriodDelta({required this.current, required this.previous});

  double get delta => current - previous;
  double? get pct => previous == 0 ? null : (delta / previous) * 100;
  bool get isUp => delta >= 0;
}

/// Top-of-screen numbers. Immutable so it plays nicely with Riverpod.
@immutable
class ExpenseKpis {
  final double total;
  final int count;
  final double average;
  final double median;
  final double highest;
  final int activeDays;
  final String? highestDescription;

  const ExpenseKpis({
    required this.total,
    required this.count,
    required this.average,
    required this.median,
    required this.highest,
    required this.activeDays,
    this.highestDescription,
  });

  static const empty = ExpenseKpis(
    total: 0,
    count: 0,
    average: 0,
    median: 0,
    highest: 0,
    activeDays: 0,
  );

  bool get isEmpty => count == 0;
}

/// KPIs for the sales report. Revenue counts *completed* sales only;
/// pending sales are tracked separately so real money and owed money
/// never get mixed up.
@immutable
class SalesKpis {
  final double revenue;         // completed
  final int count;              // completed count
  final double average;         // per completed sale
  final double highest;         // biggest single sale
  final double quantity;        // total units sold (completed)
  final String quantityUnit;    // dominant unit, e.g. 'kg'

  final double pendingAmount;   // pending sales total
  final int pendingCount;

  final String? topBuyer;
  final double topBuyerRevenue;

  const SalesKpis({
    required this.revenue,
    required this.count,
    required this.average,
    required this.highest,
    required this.quantity,
    required this.quantityUnit,
    required this.pendingAmount,
    required this.pendingCount,
    this.topBuyer,
    this.topBuyerRevenue = 0,
  });

  static const empty = SalesKpis(
    revenue: 0,
    count: 0,
    average: 0,
    highest: 0,
    quantity: 0,
    quantityUnit: 'kg',
    pendingAmount: 0,
    pendingCount: 0,
  );

  bool get isEmpty => count == 0 && pendingCount == 0;
  bool get hasPending => pendingCount > 0;
}

/// KPIs for the labour report.
@immutable
class LabourKpis {
  final double totalCost;
  final double paid;
  final double pending;

  final int totalRecords;
  final int pendingRecords;
  final int workerCount;

  final double totalDays;
  final double averageDailyRate;
  final double averagePerRecord;

  final String? topWorker;
  final double topWorkerCost;

  const LabourKpis({
    required this.totalCost,
    required this.paid,
    required this.pending,
    required this.totalRecords,
    required this.pendingRecords,
    required this.workerCount,
    required this.totalDays,
    required this.averageDailyRate,
    required this.averagePerRecord,
    this.topWorker,
    this.topWorkerCost = 0,
  });

  static const empty = LabourKpis(
    totalCost: 0,
    paid: 0,
    pending: 0,
    totalRecords: 0,
    pendingRecords: 0,
    workerCount: 0,
    totalDays: 0,
    averageDailyRate: 0,
    averagePerRecord: 0,
  );

  bool get isEmpty => totalRecords == 0;
}

/// KPIs for the harvest report.
///
/// `dominantUnit` drives the numeric aggregates because summing kg + crates
/// is meaningless. `hasMixedUnits` is true when the source has >1 unit.
@immutable
class HarvestKpis {
  final double grossYield;
  final double netYield;
  final double wasted;
  final String dominantUnit;
  final bool hasMixedUnits;

  final int count;
  final int activeDays;

  final double averageNet;
  final double wasteRatio; // 0..1

  final String? topCrop;
  final double topCropYield;

  const HarvestKpis({
    required this.grossYield,
    required this.netYield,
    required this.wasted,
    required this.dominantUnit,
    required this.hasMixedUnits,
    required this.count,
    required this.activeDays,
    required this.averageNet,
    required this.wasteRatio,
    this.topCrop,
    this.topCropYield = 0,
  });

  static const empty = HarvestKpis(
    grossYield: 0,
    netYield: 0,
    wasted: 0,
    dominantUnit: 'kg',
    hasMixedUnits: false,
    count: 0,
    activeDays: 0,
    averageNet: 0,
    wasteRatio: 0,
  );

  bool get isEmpty => count == 0;
  bool get hasWaste => wasted > 0;
}

// ===========================================================================
// Financial (P&L)
// ===========================================================================

/// Combined P&L for a single range.
/// Expenses exclude the 'labour' category to avoid double-counting
/// with the labour collection. The excluded amount is preserved
/// so we can surface a warning if the user isn't tracking labour separately.
@immutable
class FinancialKpis {
  final double revenue;
  final double expenses;        // direct expenses, labour-category excluded
  final double labour;          // from the labour collection
  final double labourExcluded;  // labour-category expenses we skipped

  const FinancialKpis({
    required this.revenue,
    required this.expenses,
    required this.labour,
    this.labourExcluded = 0,
  });

  static const empty = FinancialKpis(revenue: 0, expenses: 0, labour: 0);

  double get totalCost => expenses + labour;
  double get netProfit => revenue - totalCost;

  /// 0..1 — net profit as a share of revenue. Null when there's no revenue.
  double? get profitMargin => revenue <= 0 ? null : netProfit / revenue;

  /// Cost / revenue ratio. > 1 means loss.
  double? get costRatio => revenue <= 0 ? null : totalCost / revenue;

  bool get isEmpty =>
      revenue == 0 && expenses == 0 && labour == 0 && labourExcluded == 0;

  /// Labour is present in one source but not the other — likely double-tracked.
  bool get hasLabourMismatch =>
      labourExcluded > 0 && labour == 0;

  /// Both sources populated — the exclusion actually removed something.
  bool get hasLabourExclusion => labourExcluded > 0;
}

/// Two-series monthly bucket: revenue vs cost.
@immutable
class DualTrendPoint {
  final DateTime bucket;
  final double revenue;
  final double cost;
  const DualTrendPoint({
    required this.bucket,
    required this.revenue,
    required this.cost,
  });

  double get profit => revenue - cost;
}

// ===========================================================================
// Farm report
// ===========================================================================

/// Per-farm P&L for the farm report.
@immutable
class FarmFinancials {
  final String farmId;
  final String farmName;
  final String type;
  final String location;
  final double acreage;

  final double revenue;
  final double expenses; // excluding labour category
  final double labour;

  final double grossYield;
  final double netYield;
  final String yieldUnit;

  final int saleCount;
  final int expenseCount;
  final int labourCount;
  final int harvestCount;

  const FarmFinancials({
    required this.farmId,
    required this.farmName,
    required this.type,
    required this.location,
    required this.acreage,
    required this.revenue,
    required this.expenses,
    required this.labour,
    required this.grossYield,
    required this.netYield,
    required this.yieldUnit,
    required this.saleCount,
    required this.expenseCount,
    required this.labourCount,
    required this.harvestCount,
  });

  double get totalCost => expenses + labour;
  double get profit => revenue - totalCost;
  double? get margin => revenue <= 0 ? null : profit / revenue;
  double? get profitPerAcre => acreage <= 0 ? null : profit / acreage;

  bool get hasActivity =>
      revenue > 0 ||
      expenses > 0 ||
      labour > 0 ||
      harvestCount > 0;
}

// ===========================================================================
// Crop report
// ===========================================================================

/// Per-crop P&L for the crop report — aggregated across all farms.
@immutable
class CropFinancials {
  final String cropName;
  final String dominantUnit;

  final double revenue;      // completed sales
  final double expenses;     // direct expenses, labour-category excluded
  final double labour;

  final double grossYield;
  final double netYield;
  final double wasted;

  final int cropCount;       // number of crop entries across farms
  final int harvestCount;
  final int saleCount;

  /// Weighted average sale price per unit (revenue / quantity sold).
  final double averagePricePerUnit;

  /// Yield-weighted waste ratio.
  final double wasteRatio;

  const CropFinancials({
    required this.cropName,
    required this.dominantUnit,
    required this.revenue,
    required this.expenses,
    required this.labour,
    required this.grossYield,
    required this.netYield,
    required this.wasted,
    required this.cropCount,
    required this.harvestCount,
    required this.saleCount,
    required this.averagePricePerUnit,
    required this.wasteRatio,
  });

  double get totalCost => expenses + labour;
  double get profit => revenue - totalCost;
  double? get margin => revenue <= 0 ? null : profit / revenue;

  /// Cost per net unit produced. Null when no yield to divide by.
  double? get costPerUnit => netYield <= 0 ? null : totalCost / netYield;

  /// Profit per net unit produced.
  double? get profitPerUnit => netYield <= 0 ? null : profit / netYield;

  bool get hasActivity =>
      revenue > 0 || totalCost > 0 || harvestCount > 0 || cropCount > 0;
}

// ===========================================================================
// Greenhouse report
// ===========================================================================

/// Per-greenhouse P&L and intensity metrics.
///
/// All subcollection records (harvests, sales, expenses, labour) are
/// attributed by matching their `location` field against the greenhouse
/// `name`. Records with no matching location are attributed elsewhere
/// (or nowhere), which is why this report can't claim to cover the whole farm.
@immutable
class GreenhouseFinancials {
  final String greenhouseId;
  final String name;
  final double size;       // m²
  final String currentCrop;
  final int plantCount;

  final double revenue;
  final double expenses;   // labour-category excluded
  final double labour;

  final double grossYield;
  final double netYield;
  final double wasted;

  /// Configured / display yield unit for this greenhouse's crop
  /// (e.g. 'kg', 'crates', 'pieces'). Drives labels in the UI.
  ///
  /// Distinct from [dominantUnit], which is *observed* from the underlying
  /// harvest / sale records. In practice they should match — if they don't,
  /// it means the greenhouse's actual records disagree with its configured
  /// unit and the UI should surface that.
  final String yieldUnit;

  /// Dominant unit across harvest/sale records — drives every numeric
  /// aggregate below, because summing kg + crates is meaningless.
  final String dominantUnit;

  /// True when the underlying records carry more than one unit.
  /// Surface a warning in the UI rather than silently mixing them.
  final bool hasMixedUnits;

  /// Weighted average sale price per unit (revenue / quantity sold).
  /// Zero when no sales have been recorded.
  final double averagePricePerUnit;

  final int harvestCount;
  final int saleCount;
  final int expenseCount;
  final int labourCount;

  const GreenhouseFinancials({
    required this.greenhouseId,
    required this.name,
    required this.size,
    required this.currentCrop,
    required this.plantCount,
    required this.revenue,
    required this.expenses,
    required this.labour,
    required this.grossYield,
    required this.netYield,
    required this.wasted,
    required this.yieldUnit,
    required this.dominantUnit,
    this.hasMixedUnits = false,
    this.averagePricePerUnit = 0,
    required this.harvestCount,
    required this.saleCount,
    required this.expenseCount,
    required this.labourCount,
  });

  // ---------------------------------------------------------------------------
  // P&L
  // ---------------------------------------------------------------------------

  double get totalCost => expenses + labour;
  double get profit => revenue - totalCost;

  /// 0..1 — net profit as a share of revenue. Null when there's no revenue.
  double? get margin => revenue <= 0 ? null : profit / revenue;

  /// Cost / revenue ratio. > 1 means loss. Null when there's no revenue.
  double? get costRatio => revenue <= 0 ? null : totalCost / revenue;

  // ---------------------------------------------------------------------------
  // Unit economics
  // ---------------------------------------------------------------------------

  /// Cost per net unit produced. Null when there's no yield to divide by.
  double? get costPerUnit => netYield <= 0 ? null : totalCost / netYield;

  /// Profit per net unit produced. Null when there's no yield to divide by.
  double? get profitPerUnit => netYield <= 0 ? null : profit / netYield;

  /// Yield-weighted waste ratio, 0..1. Matches HarvestKpis.wasteRatio so
  /// the two can be compared directly on the same chart.
  double get wasteRatio => grossYield <= 0 ? 0 : wasted / grossYield;

  // ---------------------------------------------------------------------------
  // Intensity metrics — the whole reason greenhouses get their own report.
  // ---------------------------------------------------------------------------

  /// Plants per m².
  double? get density =>
      size <= 0 || plantCount <= 0 ? null : plantCount / size;

  /// Net kilos produced per m².
  double? get yieldPerSqm => size <= 0 ? null : netYield / size;

  /// KSh revenue per m².
  double? get revenuePerSqm => size <= 0 ? null : revenue / size;

  /// KSh total cost per m².
  double? get costPerSqm => size <= 0 ? null : totalCost / size;

  /// KSh net profit per m² — the single most comparable metric.
  double? get profitPerSqm => size <= 0 ? null : profit / size;

  /// KSh revenue per plant.
  double? get revenuePerPlant =>
      plantCount <= 0 ? null : revenue / plantCount;

  /// KSh profit per plant — pairs with revenuePerPlant for the "which
  /// greenhouse earns its space?" question.
  double? get profitPerPlant =>
      plantCount <= 0 ? null : profit / plantCount;

  // ---------------------------------------------------------------------------
  // Reporting helpers
  // ---------------------------------------------------------------------------

  bool get hasActivity =>
      revenue > 0 ||
      totalCost > 0 ||
      harvestCount > 0 ||
      saleCount > 0 ||
      expenseCount > 0 ||
      labourCount > 0 ||
      plantCount > 0;
}