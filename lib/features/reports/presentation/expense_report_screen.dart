import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_format.dart';
import '../../expenses/widgets/expense_category_style.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

class ExpenseReportScreen extends ConsumerWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(expenseReportRangeProvider);
    final kpis = ref.watch(expenseKpisProvider);
    final delta = ref.watch(expenseDeltaProvider);
    final breakdown = ref.watch(expenseCategoryBreakdownProvider);
    final trend = ref.watch(expenseMonthlyTrendProvider);
    final top = ref.watch(topExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Report'),
        actions: [
          if (!kpis.isEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Copy summary',
              onPressed: () =>
                  _copySummary(context, range, kpis, delta, breakdown),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),
          ReportPeriodBar(
            current: range,
            onChanged: (r) =>
                ref.read(expenseReportRangeProvider.notifier).state = r,
            onCustomTap: () => _pickCustom(context, ref, range),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ReportRangeInfo(
              range: range,
              trailing: kpis.isEmpty ? null : formatKsh(kpis.total),
            ),
          ),
          if (kpis.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: ReportEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses in this period',
                message:
                    'Try a wider range, or record some expenses first.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: KpiGrid(items: _kpiItems(kpis, delta)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _secondaryRow(kpis),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _comparisonSection(range, delta),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Spending by category',
                subtitle:
                    '${breakdown.length} ${breakdown.length == 1 ? 'category' : 'categories'}',
                child: BreakdownTable(
                  rows: breakdown,
                  colorFor: (k) => ExpenseCategories.of(k).color,
                  iconFor: (k) => ExpenseCategories.of(k).icon,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Monthly trend',
                subtitle: _trendSubtitle(trend),
                child: TrendBars(points: trend),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Biggest expenses',
                subtitle: 'Top ${top.length} of ${kpis.count}',
                child: RankedExpenseList(expenses: top),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Builders
  // -------------------------------------------------------------------------

  List<KpiData> _kpiItems(ExpenseKpis k, PeriodDelta d) {
    final pct = d.pct;
    return [
      KpiData(
        icon: Icons.payments_outlined,
        label: 'Total spent',
        value: formatKsh(k.total),
        delta: pct == null
            ? null
            : '${d.isUp ? '+' : ''}${pct.toStringAsFixed(1)}% vs prev',
        deltaIsUp: pct == null ? null : d.isUp,
        deltaIsPositive: pct == null ? null : !d.isUp, // up = bad for expenses
        color: AppTheme.expenseOrange,
      ),
      KpiData(
        icon: Icons.receipt_long_outlined,
        label: 'Entries',
        value: '${k.count}',
        color: AppTheme.primaryGreen,
      ),
      KpiData(
        icon: Icons.trending_up,
        label: 'Average',
        value: formatKsh(k.average),
        color: const Color(0xFF1E88E5),
      ),
      KpiData(
        icon: Icons.arrow_upward,
        label: 'Highest',
        value: formatKsh(k.highest),
        color: const Color(0xFF7E57C2),
      ),
    ];
  }

  Widget _secondaryRow(ExpenseKpis k) {
    return Row(
      children: [
        Expanded(child: _stat('Median', formatKsh(k.median))),
        const SizedBox(width: 8),
        Expanded(child: _stat('Active days', '${k.activeDays}')),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonSection(ReportRange range, PeriodDelta d) {
    if (!range.hasPrevious) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.black45),
            const SizedBox(width: 8),
            const Text(
              'All-time view — no previous period to compare.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return PeriodDeltaStrip(
      currentLabel: formatKsh(d.current),
      previousLabel: 'Previous period: ${formatKsh(d.previous)}',
      delta: d,
      positiveWhenUp: false, // up = bad for expenses
    );
  }

  String _trendSubtitle(List<TrendPoint> points) {
    if (points.isEmpty) return '';
    final total = points.fold<double>(0, (s, p) => s + p.value);
    final avg = total / points.length;
    return 'Avg ${formatKsh(avg)} / month';
  }

  // -------------------------------------------------------------------------
  // Custom range
  // -------------------------------------------------------------------------
  Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    ReportRange current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          DateTimeRange(start: current.start, end: current.end),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select report range',
    );
    if (picked == null) return;

    ref.read(expenseReportRangeProvider.notifier).state = ReportRange(
      preset: ReportPreset.custom,
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }

  // -------------------------------------------------------------------------
  // Share
  // -------------------------------------------------------------------------
  void _copySummary(
    BuildContext context,
    ReportRange range,
    ExpenseKpis k,
    PeriodDelta d,
    List<BreakdownRow> breakdown,
  ) {
    final b = StringBuffer()
      ..writeln('EXPENSE REPORT')
      ..writeln('${fullDate(range.start)} — ${fullDate(range.end)}')
      ..writeln('=' * 34)
      ..writeln()
      ..writeln('Total:       ${formatKsh(k.total)}')
      ..writeln('Entries:     ${k.count}')
      ..writeln('Average:     ${formatKsh(k.average)}')
      ..writeln('Median:      ${formatKsh(k.median)}')
      ..writeln('Highest:     ${formatKsh(k.highest)}')
      ..writeln('Active days: ${k.activeDays}');

    if (d.pct != null) {
      b.writeln(
        'Change:      ${d.isUp ? '+' : ''}${d.pct!.toStringAsFixed(1)}% '
        'vs previous period',
      );
    }

    b
      ..writeln()
      ..writeln('BY CATEGORY')
      ..writeln('-' * 34);

    for (final r in breakdown) {
      b.writeln(
        '${r.label.padRight(24)} ${formatKsh(r.total).padLeft(12)}  '
        '${(r.share * 100).toStringAsFixed(1)}%',
      );
    }

    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense report copied to clipboard')),
    );
  }
}