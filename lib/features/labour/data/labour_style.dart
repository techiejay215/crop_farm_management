import 'package:flutter/material.dart';

/// Colour + status system for anything labour-related.
class LabourStyle {
  LabourStyle._();

  // Payment states
  static const Color paid = Color(0xFF2E7D32);
  static const Color partial = Color(0xFFF9A825);
  static const Color unpaid = Color(0xFFC62828);

  // Primary accent — deep violet, used for the hero and report
  static const Color primary = Color(0xFF7E57C2);
  static const Color primaryDeep = Color(0xFF4527A0);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );

  static const List<Color> palette = [
    Color(0xFF7E57C2),
    Color(0xFF5E35B1),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFF4511E),
    Color(0xFF00897B),
    Color(0xFFFFA000),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFF6D4C41),
  ];

  static Color paletteAt(int index) => palette[index % palette.length];

  // --- Three-way payment state ---------------------------------------------
  static String state({required double total, required double paid}) {
    if (total <= 0) return 'paid';
    if (paid >= total) return 'paid';
    if (paid <= 0) return 'unpaid';
    return 'partial';
  }

  static Color colorFor(String state) {
    switch (state) {
      case 'paid':
        return paid;
      case 'unpaid':
        return unpaid;
      default:
        return partial;
    }
  }

  static String labelFor(String state) {
    switch (state) {
      case 'paid':
        return 'Paid';
      case 'unpaid':
        return 'Unpaid';
      default:
        return 'Partial';
    }
  }

  static IconData iconFor(String state) {
    switch (state) {
      case 'paid':
        return Icons.check_circle;
      case 'unpaid':
        return Icons.error_outline;
      default:
        return Icons.timelapse;
    }
  }
}