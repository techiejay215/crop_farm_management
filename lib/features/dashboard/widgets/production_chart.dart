import 'package:flutter/material.dart';
import '../data/dashboard_stats.dart';
import 'dashboard_palette.dart';

enum ChartRange { week, month, year }

class ProductionChart extends StatelessWidget {
  final List<MonthlyProduction> data;
  final ChartRange range;
  final ValueChanged<ChartRange> onRangeChanged;

  const ProductionChart({
    super.key,
    required this.data,
    required this.range,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((e) => e.productionKg > 0 || e.salesKg > 0);
    final totalProd = data.fold<double>(0, (s, e) => s + e.productionKg);
    final totalSales = data.fold<double>(0, (s, e) => s + e.salesKg);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Production Overview',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DPalette.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmt(totalProd)} kg produced  ·  ${_fmt(totalSales)} kg sold',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: DPalette.inkMuted,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _rangeToggle(),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasData)
            _emptyState()
          else ...[
            _legend(),
            const SizedBox(height: 16),
            SizedBox(height: 178, child: _chart()),
          ],
        ],
      ),
    );
  }

  Widget _rangeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DPalette.sageSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DPalette.hairline),
      ),
      child: Row(
        children: ChartRange.values.map((r) {
          final selected = r == range;
          final label = r == ChartRange.week
              ? '7D'
              : r == ChartRange.month
                  ? '30D'
                  : '12M';
          return GestureDetector(
            onTap: () => onRangeChanged(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? DPalette.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: DPalette.brand.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: selected ? Colors.white : DPalette.inkMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        _legendDot(DPalette.brand, 'Production'),
        const SizedBox(width: 18),
        _legendDot(DPalette.leafSoft, 'Sales'),
      ],
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: DPalette.inkSoft,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: DPalette.iconChip(
              DPalette.iconGreen,
              DPalette.iconGreenTint,
              radius: 26,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 24,
              color: DPalette.brand,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No production data yet',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: DPalette.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Start recording crop production to see\nyour farm performance here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: DPalette.inkMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chart() {
    final maxVal = data
        .expand((e) => [e.productionKg, e.salesKg])
        .fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;

    return Stack(
      children: [
        // Subtle horizontal grid lines behind the bars.
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (i) => Container(
                height: 1,
                color: DPalette.hairline.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        Row(
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
                    SizedBox(
                      height: 138,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _bar(pRatio, DPalette.brand),
                          const SizedBox(width: 3),
                          _bar(sRatio, DPalette.leafSoft),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      m.monthLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: DPalette.inkMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _bar(double ratio, Color color) {
    final deep = Color.lerp(color, DPalette.brandDeep, 0.28)!;
    return Container(
      width: 9,
      height: (ratio * 138).clamp(3, 138),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, deep],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}