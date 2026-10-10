import 'package:flutter/material.dart';

/// Colour + semantic system for anything harvest-related.
class HarvestStyle {
  HarvestStyle._();

  // Primary — deep moss green, distinct from the app's primary but still
  // agricultural. Feels like a fresh crop, not a generic green.
  static const Color primary = Color(0xFF558B2F);
  static const Color primaryDeep = Color(0xFF33691E);

  // Grade colours (A = premium → C = low).
  static const Color gradeA = Color(0xFF2E7D32);
  static const Color gradeB = Color(0xFFF9A825);
  static const Color gradeC = Color(0xFFC62828);

  // Waste indicator colours — switch by severity.
  static const Color wasteLow = Color(0xFF2E7D32);
  static const Color wasteMid = Color(0xFFF9A825);
  static const Color wasteHigh = Color(0xFFC62828);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );

  static const List<String> units = ['kg', 'crates', 'bags', 'pieces', 'tons'];
  static const List<String> grades = ['A', 'B', 'C'];

  static Color gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return gradeA;
      case 'B':
        return gradeB;
      case 'C':
        return gradeC;
      default:
        return Colors.grey;
    }
  }

  static String gradeLabel(String grade) {
    final g = grade.toUpperCase();
    switch (g) {
      case 'A':
        return 'Premium';
      case 'B':
        return 'Standard';
      case 'C':
        return 'Low grade';
      default:
        return 'Unrated';
    }
  }

  /// 0..1 → colour.
  static Color wasteColor(double ratio) {
    if (ratio <= 0.03) return wasteLow;
    if (ratio <= 0.10) return wasteMid;
    return wasteHigh;
  }

  /// Human label for a waste ratio.
  static String wasteLabel(double ratio) {
    if (ratio <= 0.03) return 'Minimal';
    if (ratio <= 0.10) return 'Moderate';
    return 'High';
  }
}