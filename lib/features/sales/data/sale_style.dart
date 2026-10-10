import 'package:flutter/material.dart';

/// Colour system for anything sale-related.
/// Kept here so the sales screen, the sale form and the sales report all
/// draw from the same palette.
class SaleStyle {
  SaleStyle._();

  // Status
  static const Color completed = Color(0xFF2E7D32);
  static const Color pending = Color(0xFFEF6C00);

  // Primary accent for revenue visuals
  static const Color revenue = Color(0xFF1E88E5);
  static const Color revenueDeep = Color(0xFF0D47A1);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
  );

  /// Palette used when colouring rows that have no intrinsic colour
  /// (crops, buyers). Ranks are stable because the list is sorted.
  static const List<Color> palette = [
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

  static Color paletteAt(int index) => palette[index % palette.length];

  static Color statusColor(String status) =>
      status == 'pending' ? pending : completed;

  static IconData statusIcon(String status) =>
      status == 'pending' ? Icons.schedule : Icons.check_circle;

  static String statusLabel(String status) =>
      status == 'pending' ? 'Pending' : 'Completed';
}