import 'package:flutter/material.dart';
import '../data/dashboard_stats.dart';
import 'dashboard_palette.dart';

class BarChart extends StatelessWidget {
  final List<MonthlyProduction> data;
  const BarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final maxVal = data
        .expand((e) => [e.productionKg, e.salesKg])
        .fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((m) {
        final pRatio = m.productionKg / safeMax;
        final sRatio = m.salesKg / safeMax;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (m.productionKg > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      m.productionKg.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: DPalette.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _bar(pRatio, DPalette.leaf),
                      const SizedBox(width: 3),
                      _bar(sRatio, DPalette.leafSoft),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  m.monthLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: DPalette.inkMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _bar(double ratio, Color color) {
    return Container(
      width: 9,
      height: (ratio * 140).clamp(3, 140),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}