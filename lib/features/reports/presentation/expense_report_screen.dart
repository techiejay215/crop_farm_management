import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) return _buildDesktop(context, ref);
        return _buildMobile(context, ref);
      },
    );
  }

  // ===========================================================================
  // MOBILE (unchanged)
  // ===========================================================================
  Widget _buildMobile(BuildContext context, WidgetRef ref) {
    final range = ref.watch(expenseReportRangeProvider);
    final kpis = ref.watch(expenseKpisProvider);
    final delta = ref.watch(expenseDeltaProvider);
    final breakdown = ref.watch(expenseCategoryBreakdownProvider);

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
        children: _buildContent(context, ref, isDesktop: false),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(BuildContext context, WidgetRef ref) {
    final range = ref.watch(expenseReportRangeProvider);
    final kpis = ref.watch(expenseKpisProvider);
    final delta = ref.watch(expenseDeltaProvider);
    final breakdown = ref.watch(expenseCategoryBreakdownProvider);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: Column(
        children: [
          _buildDesktopHeader(context, kpis, range, delta, breakdown),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children:
                        _buildContent(context, ref, isDesktop: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(
    BuildContext context,
    ExpenseKpis kpis,
    ReportRange range,
    PeriodDelta delta,
    List<BreakdownRow> breakdown,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 18, 32, 18),
      decoration: const BoxDecoration(
        color: DPalette.surface,
        border: Border(bottom: BorderSide(color: DPalette.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE65100), AppTheme.expenseOrange],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.expenseOrange.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense Report',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Spending breakdown, trends and top costs.',
                  style: TextStyle(fontSize: 13, color: DPalette.inkMuted),
                ),
              ],
            ),
          ),
          if (!kpis.isEmpty)
            OutlinedButton.icon(
              onPressed: () =>
                  _copySummary(context, range, kpis, delta, breakdown),
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('Copy summary'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DPalette.ink,
                side: const BorderSide(color: DPalette.hairline),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SHARED CONTENT
  // ===========================================================================
  List<Widget> _buildContent(
    BuildContext context,
    WidgetRef ref, {
    bool isDesktop = false,
  }) {
    final range = ref.watch(expenseReportRangeProvider);
    final kpis = ref.watch(expenseKpisProvider);
    final delta = ref.watch(expenseDeltaProvider);
    final breakdown = ref.watch(expenseCategoryBreakdownProvider);
    final trend = ref.watch(expenseMonthlyTrendProvider);
    final top = ref.watch(topExpensesProvider);

    if (kpis.isEmpty) {
      return [
        const SizedBox(height: 8),
        ReportPeriodBar(
          current: range,
          onChanged: (r) =>
              ref.read(expenseReportRangeProvider.notifier).state = r,
          onCustomTap: () => _pickCustom(context, ref, range),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ReportRangeInfo(range: range),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: ReportEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No expenses in this period',
            message: 'Try a wider range, or record some expenses first.',
          ),
        ),
      ];
    }

    final breakdownSection = ReportSection(
      title: 'Spending by category',
      subtitle:
          '${breakdown.length} ${breakdown.length == 1 ? 'category' : 'categories'}',
      child: BreakdownTable(
        rows: breakdown,
        colorFor: (k) => ExpenseCategories.of(k).color,
        iconFor: (k) => ExpenseCategories.of(k).icon,
      ),
    );

    final trendSection = ReportSection(
      title: 'Monthly trend',
      subtitle: _trendSubtitle(trend),
      child: TrendBars(points: trend),
    );

    final topSection = ReportSection(
      title: 'Biggest expenses',
      subtitle: 'Top ${top.length} of ${kpis.count}',
      child: RankedExpenseList(expenses: top),
    );

    // Secondary rows: mobile uses 2 expanded tiles; desktop widens
    // to 4 columns alongside comparison for a denser strip.
    final secondary = <Widget>[];
    if (isDesktop) {
      secondary.add(
        Row(
          children: [
            Expanded(child: _stat('Median', formatKsh(kpis.median))),
            const SizedBox(width: 12),
            Expanded(child: _stat('Active days', '${kpis.activeDays}')),
            const SizedBox(width: 12),
            Expanded(
              child: _stat(
                'Largest',
                formatKsh(kpis.highest),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _stat(
                'Average',
                formatKsh(kpis.average),
              ),
            ),
          ],
        ),
      );
    } else {
      secondary.add(_secondaryRow(kpis));
    }

    return [
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
          trailing: formatKsh(kpis.total),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: KpiGrid(
          items: _kpiItems(kpis, delta),
          columns: isDesktop ? 4 : 2,
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < secondary.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              secondary[i],
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _comparisonSection(range, delta),
      ),
      const SizedBox(height: 16),
      if (isDesktop) ...[
        // Side-by-side: category breakdown | monthly trend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: breakdownSection),
                const SizedBox(width: 16),
                Expanded(child: trendSection),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: topSection,
        ),
      ] else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: breakdownSection,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: trendSection,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: topSection,
        ),
      ],
      const SizedBox(height: 32),
    ];
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
        deltaIsPositive: pct == null ? null : !d.isUp,
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
      positiveWhenUp: false,
    );
  }

  String _trendSubtitle(List<TrendPoint> points) {
    if (points.isEmpty) return '';
    final total = points.fold<double>(0, (s, p) => s + p.value);
    final avg = total / points.length;
    return 'Avg ${formatKsh(avg)} / month';
  }

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