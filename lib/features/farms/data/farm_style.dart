import 'package:flutter/material.dart';

class FarmStyle {
  FarmStyle._();

  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDeep = Color(0xFF1B5E20);

  /// Type colours — main farm vs rented.
  static const Color main = Color(0xFF1565C0);
  static const Color rented = Color(0xFFEF6C00);

  /// Accent for acreage / land.
  static const Color acreage = Color(0xFF00897B);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );

  static Color typeColor(String type) =>
      type == 'rented' ? rented : main;

  static IconData typeIcon(String type) =>
      type == 'rented' ? Icons.key : Icons.home_work;

  static String typeLabel(String type) =>
      type == 'rented' ? 'Rented' : 'Main';

  static String rentalPeriodLabel(String period) {
    switch (period) {
      case 'yearly':
        return 'yr';
      case 'quarterly':
        return 'qtr';
      case 'monthly':
      default:
        return 'mo';
    }
  }
}