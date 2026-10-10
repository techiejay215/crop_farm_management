import 'package:flutter/foundation.dart';

@immutable
class CropInstance {
  final String farmName;
  final String location;
  final int plantCount;
  final double acreage;
  final String stage;
  final DateTime? plantingDate;

  const CropInstance({
    required this.farmName,
    required this.location,
    required this.plantCount,
    required this.acreage,
    required this.stage,
    this.plantingDate,
  });
}

@immutable
class CropActivityRow {
  final String farmName;
  final String location;
  final DateTime? date;
  final String type;
  final String description;
  final double? quantity;
  final String? unit;
  final double? cost;
  final double? income;
  final String? person;

  const CropActivityRow({
    required this.farmName,
    required this.location,
    this.date,
    required this.type,
    required this.description,
    this.quantity,
    this.unit,
    this.cost,
    this.income,
    this.person,
  });
}

@immutable
class CropExpenseRow {
  final String farmName;
  final DateTime? date;
  final String category;
  final String description;
  final double amount;
  final String? location;

  const CropExpenseRow({
    required this.farmName,
    this.date,
    required this.category,
    required this.description,
    required this.amount,
    this.location,
  });
}

@immutable
class CropIncomeRow {
  final String farmName;
  final DateTime? date;
  final String buyer;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double total;
  final String status;

  const CropIncomeRow({
    required this.farmName,
    this.date,
    required this.buyer,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.total,
    required this.status,
  });
}

@immutable
class CropHarvestRow {
  final String farmName;
  final DateTime? date;
  final double quantity;
  final String unit;
  final String grade;
  final double wasted;

  const CropHarvestRow({
    required this.farmName,
    this.date,
    required this.quantity,
    required this.unit,
    required this.grade,
    required this.wasted,
  });

  double get net => (quantity - wasted).clamp(0, double.infinity);
}

/// Full per-crop report. Built by aggregating:
///   * crops matching the crop name across farms in scope
///   * activities subcollection for each crop instance
///   * expenses collection filtered by cropName
///   * sales collection filtered by cropName
///   * harvests collection filtered by cropName
@immutable
class CropReportDetail {
  final String cropName;
  final String dominantUnit;
  final bool hasMixedUnits;

  final List<CropInstance> instances;
  final List<CropActivityRow> activities;
  final List<CropExpenseRow> expenses;
  final List<CropIncomeRow> income;
  final List<CropHarvestRow> harvests;

  const CropReportDetail({
    required this.cropName,
    required this.dominantUnit,
    required this.hasMixedUnits,
    required this.instances,
    required this.activities,
    required this.expenses,
    required this.income,
    required this.harvests,
  });

  // ---------------- Aggregates ----------------
  int get totalPlants =>
      instances.fold(0, (s, i) => s + i.plantCount);

  double get totalAcreage =>
      instances.fold(0.0, (s, i) => s + i.acreage);

  double get totalExpenses =>
      expenses.fold(0.0, (s, e) => s + e.amount);

  double get totalIncome =>
      income.where((i) => i.status == 'completed').fold(0.0, (s, i) => s + i.total);

  double get totalPending =>
      income.where((i) => i.status != 'completed').fold(0.0, (s, i) => s + i.total);

  double get grossYield => harvests.fold(0.0, (s, h) => s + h.quantity);
  double get netYield => harvests.fold(0.0, (s, h) => s + h.net);
  double get wasted => harvests.fold(0.0, (s, h) => s + h.wasted);

  double get netProfit => totalIncome - totalExpenses;
  double? get margin => totalIncome <= 0 ? null : netProfit / totalIncome;

  double? get costPerUnit =>
      netYield <= 0 ? null : totalExpenses / netYield;
  double? get revenuePerUnit =>
      netYield <= 0 ? null : totalIncome / netYield;

  bool get isEmpty =>
      instances.isEmpty &&
      activities.isEmpty &&
      expenses.isEmpty &&
      income.isEmpty &&
      harvests.isEmpty;

  // ---------------- Grouped views ----------------
  /// Activities grouped by type. Only types that appear are included.
  Map<String, List<CropActivityRow>> get activitiesByType {
    final map = <String, List<CropActivityRow>>{};
    for (final a in activities) {
      map.putIfAbsent(a.type, () => []).add(a);
    }
    return map;
  }

  /// Expenses grouped by category (raw category keys).
  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  /// Cost sum for activities of a given type.
  double costForType(String type) {
    return activities
        .where((a) => a.type == type)
        .fold(0.0, (s, a) => s + (a.cost ?? 0));
  }
}