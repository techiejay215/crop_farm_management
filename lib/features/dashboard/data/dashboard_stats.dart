class DashboardStats {
  final int totalFarms;
  final int activeCrops;
  final double totalProductionKg;
  final double totalRevenue;
  final double totalExpenses;
  final double pendingWages;
  final List<FarmPerformance> farms;
  final List<MonthlyProduction> monthlyProduction;
  final List<RecentSale> recentSales;
  final Map<String, double> expenseByCategory;

  DashboardStats({
    required this.totalFarms,
    required this.activeCrops,
    required this.totalProductionKg,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.pendingWages,
    required this.farms,
    required this.monthlyProduction,
    required this.recentSales,
    required this.expenseByCategory,
  });

  double get netProfit => totalRevenue - totalExpenses;
  double get profitMargin =>
      totalRevenue == 0 ? 0 : (netProfit / totalRevenue) * 100;
  double get avgYieldPerFarm =>
      totalFarms == 0 ? 0 : totalProductionKg / totalFarms;
}

class FarmPerformance {
  final String farmId;
  final String farmName;
  final double acreage;
  final int cropCount;
  final double revenue;
  final double expenses;

  FarmPerformance({
    required this.farmId,
    required this.farmName,
    required this.acreage,
    required this.cropCount,
    required this.revenue,
    required this.expenses,
  });

  double get profit => revenue - expenses;
}

class MonthlyProduction {
  final String monthLabel; // 'Jan', 'Feb', ...
  final double productionKg;
  final double salesKg;

  MonthlyProduction({
    required this.monthLabel,
    required this.productionKg,
    required this.salesKg,
  });
}

class RecentSale {
  final String cropName;
  final String buyer;
  final double quantity;
  final String unit;
  final double totalAmount;
  final DateTime? date;

  RecentSale({
    required this.cropName,
    required this.buyer,
    required this.quantity,
    required this.unit,
    required this.totalAmount,
    this.date,
  });
}

class CropProfitability {
  final String cropName;
  final double productionKg;
  final double salesKg;
  final double revenue;
  final double expenses;
  double get profit => revenue - expenses;
  double get costPerKg => salesKg == 0 ? 0 : expenses / salesKg;
  double get pricePerKg => salesKg == 0 ? 0 : revenue / salesKg;

  CropProfitability({
    required this.cropName,
    required this.productionKg,
    required this.salesKg,
    required this.revenue,
    required this.expenses,
  });
}