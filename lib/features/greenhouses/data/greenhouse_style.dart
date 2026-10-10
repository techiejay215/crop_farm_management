import 'package:flutter/material.dart';

class GreenhouseStyle {
  GreenhouseStyle._();

  // Glassy cyan — distinct from farms (forest), crops (mid-green),
  // harvests (olive) and sales (blue). Reads as "controlled environment."
  static const Color primary = Color(0xFF00ACC1);
  static const Color primaryDeep = Color(0xFF00838F);

  // Density warnings
  static const Color densityLow = Color(0xFFF9A825);
  static const Color densityOk = Color(0xFF2E7D32);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );

  static const List<Color> palette = [
    Color(0xFF00ACC1),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF7E57C2),
    Color(0xFFF4511E),
    Color(0xFF8E24AA),
    Color(0xFFF9A825),
    Color(0xFF5E35B1),
    Color(0xFF6D4C41),
  ];

  static Color paletteAt(int index) => palette[index % palette.length];

  /// Density (plants per m²). Null when size <= 0.
  static double? density({required int plants, required double size}) {
    if (size <= 0 || plants <= 0) return null;
    return plants / size;
  }

  /// Very loose sanity thresholds — the app doesn't presume to know
  /// what's correct for every crop, just to flag the extremes.
  static Color densityColor(double? density) {
    if (density == null) return Colors.grey;
    if (density < 1) return densityLow; // might be under-planted
    return densityOk;
  }

  static String densityLabel(double? density) {
    if (density == null) return '—';
    return '${density.toStringAsFixed(density < 10 ? 1 : 0)}/m²';
  }
}