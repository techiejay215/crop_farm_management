import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_format.dart';
import '../../expenses/widgets/expense_category_style.dart';
import '../data/report_models.dart';

// ===========================================================================
// Section shell — every report block sits inside one of these.
// ===========================================================================
class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ===========================================================================
// Period chip bar
// ===========================================================================
class ReportPeriodBar extends StatelessWidget {
  const ReportPeriodBar({
    super.key,
    required this.current,
    required this.onChanged,
    this.onCustomTap,
  });

  final ReportRange current;
  final ValueChanged<ReportRange> onChanged;
  final VoidCallback? onCustomTap;

  static const _presets = <ReportPreset>[
    ReportPreset.last30Days,
    ReportPreset.last3Months,
    ReportPreset.last6Months,
    ReportPreset.last12Months,
    ReportPreset.yearToDate,
    ReportPreset.allTime,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final p in _presets) ...[
            _chip(
              label: p.shortLabel,
              selected: current.preset == p,
              onTap: () => onChanged(ReportRange.fromPreset(p)),
            ),
            const SizedBox(width: 8),
          ],
          _chip(
            label: current.preset == ReportPreset.custom
                ? _customLabel(current)
                : 'Custom',
            selected: current.preset == ReportPreset.custom,
            icon: Icons.calendar_month_outlined,
            onTap: onCustomTap,
          ),
        ],
      ),
    );
  }

  String _customLabel(ReportRange r) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${r.start.day} ${months[r.start.month - 1]} – '
        '${r.end.day} ${months[r.end.month - 1]}';
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: icon == null ? 14 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryGreen
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : Colors.black54,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Range info line under the bar
// ===========================================================================
class ReportRangeInfo extends StatelessWidget {
  const ReportRangeInfo({super.key, required this.range, this.trailing});

  final ReportRange range;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.event_outlined, size: 15, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${fullDate(range.start)} — ${fullDate(range.end)} · ${range.days} days',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// KPI grid
// ===========================================================================
@immutable
class KpiData {
  final IconData icon;
  final String label;
  final String value;
  final String? delta;
  final bool? deltaIsUp;        // arrow direction
  final bool? deltaIsPositive;  // colour signal — "is this good news?"
  final Color color;

  const KpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.delta,
    this.deltaIsUp,
    this.deltaIsPositive,
  });
}

class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items, this.columns = 2});

  final List<KpiData> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((d) => _KpiTile(d)).toList(),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(this.data);
  final KpiData data;

  @override
  Widget build(BuildContext context) {
    // For expenses, an upward delta is bad. Callers set deltaIsPositive
    // explicitly so sales (up = good) and expenses (up = bad) share this tile.
    final positive = data.deltaIsPositive ?? data.deltaIsUp ?? false;
    final deltaColor =
        positive ? AppTheme.profitGreen : AppTheme.expenseOrange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(data.icon, size: 16, color: data.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (data.delta != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  data.deltaIsUp == true
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 11,
                  color: deltaColor,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    data.delta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: deltaColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Comparison strip
// ===========================================================================
class PeriodDeltaStrip extends StatelessWidget {
  const PeriodDeltaStrip({
    super.key,
    required this.currentLabel,
    required this.previousLabel,
    required this.delta,
    this.positiveWhenUp = true, // sales: up = good. Expenses pass false.
  });

  final String currentLabel;
  final String previousLabel;
  final PeriodDelta delta;
  final bool positiveWhenUp;

  @override
  Widget build(BuildContext context) {
    final pct = delta.pct;
    final up = delta.isUp;
    final isPositive = up == positiveWhenUp;
    final accent = isPositive ? AppTheme.profitGreen : AppTheme.expenseOrange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previousLabel,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 3),
                Text(
                  currentLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (pct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    up ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'No previous data',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Breakdown table — one row per category / crop / month / method
// ===========================================================================
class BreakdownTable extends StatelessWidget {
  const BreakdownTable({
    super.key,
    required this.rows,
    required this.colorFor,
    required this.iconFor,
  });

  final List<BreakdownRow> rows;
  final Color Function(String key) colorFor;
  final IconData Function(String key) iconFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(height: 20, color: Colors.black.withValues(alpha: 0.05)),
          _Row(
            row: rows[i],
            color: colorFor(rows[i].key),
            icon: iconFor(rows[i].key),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.color, required this.icon});
  final BreakdownRow row;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${row.count} ${row.count == 1 ? 'entry' : 'entries'} · '
                    'avg ${formatKsh(row.average)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatKsh(row.total),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(row.share * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: row.share.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Trend bars
// ===========================================================================
class TrendBars extends StatelessWidget {
  const TrendBars({
    super.key,
    required this.points,
    this.height = 140,
    this.barColor = AppTheme.primaryGreen,
  });

  final List<TrendPoint> points;
  final double height;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue =
        points.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    if (maxValue <= 0) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No activity in this period',
            style: TextStyle(fontSize: 12.5, color: Colors.black45),
          ),
        ),
      );
    }

    final now = DateTime.now();

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final isCurrent =
              p.bucket.year == now.year && p.bucket.month == now.month;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final h = (p.value / maxValue) * c.maxHeight;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: h),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => Container(
                              height: v,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? barColor
                                    : barColor.withValues(alpha: 0.28),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    monthShort(p.bucket),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? barColor : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ===========================================================================
// Dual-series monthly bars — revenue (green) vs cost (orange)
// ===========================================================================
class DualTrendBars extends StatelessWidget {
  const DualTrendBars({
    super.key,
    required this.points,
    this.height = 160,
    this.positiveColor = AppTheme.profitGreen,
    this.negativeColor = AppTheme.expenseOrange,
  });

  final List<DualTrendPoint> points;
  final double height;
  final Color positiveColor;
  final Color negativeColor;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = points.fold<double>(
      0,
      (m, p) => [m, p.revenue, p.cost].reduce((a, b) => a > b ? a : b),
    );
    if (maxValue <= 0) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No activity in this period',
            style: TextStyle(fontSize: 12.5, color: Colors.black45),
          ),
        ),
      );
    }

    final now = DateTime.now();

    return Column(
      children: [
        Row(
          children: [
            _legend(positiveColor, 'Revenue'),
            const SizedBox(width: 14),
            _legend(negativeColor, 'Cost'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((p) {
              final isCurrent = p.bucket.year == now.year &&
                  p.bucket.month == now.month;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final revenueH =
                                (p.revenue / maxValue) * c.maxHeight;
                            final costH = (p.cost / maxValue) * c.maxHeight;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: revenueH),
                                    duration:
                                        const Duration(milliseconds: 600),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, __) => Container(
                                      height: v,
                                      decoration: BoxDecoration(
                                        color: positiveColor,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: costH),
                                    duration:
                                        const Duration(milliseconds: 600),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, __) => Container(
                                      height: v,
                                      decoration: BoxDecoration(
                                        color: negativeColor
                                            .withValues(alpha: 0.85),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        monthShort(p.bucket),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent
                              ? AppTheme.primaryGreen
                              : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Ranked expense list
// ===========================================================================
class RankedExpenseList extends StatelessWidget {
  const RankedExpenseList({super.key, required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < expenses.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(expenses[i], i + 1),
        ],
      ],
    );
  }

  Widget _row(Expense e, int rank) {
    final style = ExpenseCategories.of(e.category);
    final dateStr = e.date != null ? dayLabel(e.date!) : '';

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: style.color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${style.shortLabel}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Text(
          formatKsh(e.amount),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.expenseOrange,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Empty state
// ===========================================================================
class ReportEmptyState extends StatelessWidget {
  const ReportEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.expenseOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppTheme.expenseOrange),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}