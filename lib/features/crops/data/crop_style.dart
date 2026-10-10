import 'package:flutter/material.dart';

class CropStyle {
  CropStyle._();

  // Primary crop accent — mid vibrant green, distinguishes it from
  // farms (darker forest) and harvests (olive).
  static const Color primary = Color(0xFF43A047);
  static const Color primaryDeep = Color(0xFF1B5E20);

  // Growth stage — semantic, not decorative.
  // Growing = alive → green. Ready = attention → amber. Harvested = done → slate.
  static const Color growing = Color(0xFF2E7D32);
  static const Color ready = Color(0xFFF9A825);
  static const Color harvested = Color(0xFF546E7A);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );

  static const List<String> stages = ['growing', 'harvest_ready', 'harvested'];

  static Color stageColor(String stage) {
    switch (stage) {
      case 'harvest_ready':
        return ready;
      case 'harvested':
        return harvested;
      case 'growing':
      default:
        return growing;
    }
  }

  static IconData stageIcon(String stage) {
    switch (stage) {
      case 'harvest_ready':
        return Icons.check_circle_outline;
      case 'harvested':
        return Icons.inventory_2_outlined;
      case 'growing':
      default:
        return Icons.eco_outlined;
    }
  }

  static String stageLabel(String stage) {
    switch (stage) {
      case 'harvest_ready':
        return 'Ready to harvest';
      case 'harvested':
        return 'Harvested';
      case 'growing':
      default:
        return 'Growing';
    }
  }

  static String stageShort(String stage) {
    switch (stage) {
      case 'harvest_ready':
        return 'READY';
      case 'harvested':
        return 'HARVESTED';
      case 'growing':
      default:
        return 'GROWING';
    }
  }

  /// Human label for a "days until" number.
  static String daysLabel(int days) {
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Ready today';
    if (days == 1) return 'Ready tomorrow';
    if (days <= 14) return 'Ready in $days days';
    if (days <= 60) return '~${(days / 7).round()} weeks';
    return '~${(days / 30).round()} months';
  }
}