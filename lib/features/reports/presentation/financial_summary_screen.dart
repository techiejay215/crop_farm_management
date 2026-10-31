import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../expenses/expense_format.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

const Color _revenueGreen = Color(0xFF2E7D32);
const Color _costOrange = Color(0xFFEF6C00);
const Color _labourViolet = Color(0xFF7E57C2);

class FinancialSummaryScreen extends ConsumerWidget {
  const FinancialSummaryScreen({super.key});

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
    final kpis = ref.watch(financialKpisProvider);
    final range = ref.watch(financialReportRangeProvider);
    final profitDelta = ref.watch(financialProfitDeltaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Summary'),
        actions: [
          if (!kpis.isEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Copy summary',
              onPressed: () => _copySummary(context, range, kpis, profitDelta),
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
    final kpis = ref.watch(financialKpisProvider);
    final range = ref.watch(financialReportRangeProvider);
    final profitDelta = ref.watch(financialProfitDeltaProvider);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: Column(
        children: [
          _buildDesktopHeader(context, kpis, range, profitDelta),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildContent(context, ref, isDesktop: true),
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
    FinancialKpis kpis,
    ReportRange range,
    PeriodDelta profitDelta,
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
                colors: [Color(0xFF1B5E20), _revenueGreen],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _revenueGreen.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.account_balance_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Summary',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Revenue, costs and net profit in one view.',
                  style: TextStyle(fontSize: 13, color: DPalette.inkMuted),
                ),
              ],
            ),
          ),
          if (!kpis.isEmpty)
            OutlinedButton.icon(
              onPressed: () => _copySummary(context, range, kpis, profitDelta),
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
    final range = ref.watch(financialReportRangeProvider);
    final kpis = ref.watch(financialKpisProvider);
    final profitDelta = ref.watch(financialProfitDeltaProvider);
    final trend = ref.watch(financialTrendProvider);

    if (kpis.isEmpty) {
      return [
        const SizedBox(height: 8),
        ReportPeriodBar(
          current: range,
          onChanged: (r) =>
              ref.read(financialReportRangeProvider.notifier).state = r,
          onCustomTap: () => _pickCustom(context, ref, range),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ReportRangeInfo(range: range),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: ReportEmptyState(
            icon: Icons.account_balance_outlined,
            title: 'Nothing to summarise yet',
            message:
                'Record sales, expenses or labour in this period to see profit.',
          ),
        ),
      ];
    }

    // Pre-built sections
    final compositionSection = ReportSection(
      title: 'Where the money went',
      subtitle: _compositionSubtitle(kpis),
      child: _Composition(kpis: kpis),
    );

    final revenueVsCostSection = ReportSection(
      title: 'Revenue vs cost',
      subtitle: _trendSubtitle(trend),
      child: DualTrendBars(
        points: trend,
        positiveColor: _revenueGreen,
        negativeColor: _costOrange,
      ),
    );

    final monthlyProfitSection = ReportSection(
      title: 'Monthly profit',
      subtitle: _profitTrendSubtitle(trend),
      child: _ProfitBars(points: trend),
    );

    final labourNote =
        kpis.hasLabourExclusion ? _LabourNote(kpis: kpis) : null;

    final comparison = _comparisonSection(range, profitDelta);

    if (isDesktop) {
      return [
        const SizedBox(height: 8),
        ReportPeriodBar(
          current: range,
          onChanged: (r) =>
              ref.read(financialReportRangeProvider.notifier).state = r,
          onCustomTap: () => _pickCustom(context, ref, range),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ReportRangeInfo(
            range: range,
            trailing: formatShortKsh(kpis.netProfit),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _ProfitHero(kpis: kpis),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: KpiGrid(
            items: _kpiItems(kpis, profitDelta),
            columns: 4,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _marginRow(kpis),
        ),
        if (labourNote != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: labourNote,
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: comparison,
        ),

        // Composition | Revenue vs cost — side by side
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: compositionSection),
                const SizedBox(width: 16),
                Expanded(child: revenueVsCostSection),
              ],
            ),
          ),
        ),

        // Monthly profit — full width
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: monthlyProfitSection,
        ),
        const SizedBox(height: 32),
      ];
    }

    // Mobile — original stacking order preserved
    return [
      const SizedBox(height: 8),
      ReportPeriodBar(
        current: range,
        onChanged: (r) =>
            ref.read(financialReportRangeProvider.notifier).state = r,
        onCustomTap: () => _pickCustom(context, ref, range),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ReportRangeInfo(
          range: range,
          trailing: formatShortKsh(kpis.netProfit),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: _ProfitHero(kpis: kpis),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: KpiGrid(items: _kpiItems(kpis, profitDelta)),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _marginRow(kpis),
      ),
      if (labourNote != null) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: labourNote,
        ),
      ],
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: comparison,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: compositionSection,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: revenueVsCostSection,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: monthlyProfitSection,
      ),
      const SizedBox(height: 32),
    ];
  }

  // -------------------------------------------------------------------------
  // KPIs
  // -------------------------------------------------------------------------
  List<KpiData> _kpiItems(FinancialKpis k, PeriodDelta delta) {
    final netProfit = k.netProfit;
    final profitPositive = netProfit >= 0;

    return [
      KpiData(
        icon: Icons.payments_outlined,
        label: 'Revenue',
        value: formatKsh(k.revenue),
        color: _revenueGreen,
      ),
      KpiData(
        icon: Icons.trending_down,
        label: 'Total cost',
        value: formatKsh(k.totalCost),
        color: _costOrange,
      ),
      KpiData(
        icon: profitPositive ? Icons.trending_up : Icons.trending_down,
        label: profitPositive ? 'Net profit' : 'Net loss',
        value: formatKsh(netProfit.abs()),
        color: profitPositive
            ? _revenueGreen
            : const Color(0xFFC62828),
      ),
      KpiData(
        icon: Icons.percent,
        label: 'Margin',
        value: _formatMargin(k.profitMargin),
        color: k.profitMargin == null
            ? Colors.black45
            : (k.profitMargin! >= 0
                ? _revenueGreen
                : const Color(0xFFC62828)),
      ),
    ];
  }

  String _formatMargin(double? margin) {
    if (margin == null) return '—';
    return '${(margin * 100).toStringAsFixed(1)}%';
  }

  Widget _marginRow(FinancialKpis k) {
    return Row(
      children: [
        Expanded(
          child: _stat(
            'Cost / revenue',
            k.costRatio == null
                ? '—'
                : '${k.costRatio!.toStringAsFixed(2)}×',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat('Direct expenses', formatShortKsh(k.expenses)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat('Labour', formatShortKsh(k.labour)),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Comparison
  // -------------------------------------------------------------------------
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
      previousLabel: 'Previous profit: ${formatKsh(d.previous)}',
      delta: d,
      positiveWhenUp: true,
    );
  }

  // -------------------------------------------------------------------------
  // Subtitles
  // -------------------------------------------------------------------------
  String _compositionSubtitle(FinancialKpis k) {
    if (k.revenue <= 0) return 'No revenue to break down';
    return 'Each slice is a share of revenue';
  }

  String _trendSubtitle(List<DualTrendPoint> points) {
    if (points.isEmpty) return '';
    final totalRevenue = points.fold<double>(0, (s, p) => s + p.revenue);
    final totalCost = points.fold<double>(0, (s, p) => s + p.cost);
    return '${formatShortKsh(totalRevenue)}  ·  ${formatShortKsh(totalCost)}';
  }

  String _profitTrendSubtitle(List<DualTrendPoint> points) {
    if (points.isEmpty) return '';
    final positive = points.where((p) => p.profit > 0).length;
    return '$positive of ${points.length} months profitable';
  }

  Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    ReportRange current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select report range',
    );
    if (picked == null) return;

    ref.read(financialReportRangeProvider.notifier).state = ReportRange(
      preset: ReportPreset.custom,
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }

  void _copySummary(
    BuildContext context,
    ReportRange range,
    FinancialKpis k,
    PeriodDelta d,
  ) {
    final b = StringBuffer()
      ..writeln('FINANCIAL SUMMARY')
      ..writeln('${fullDate(range.start)} — ${fullDate(range.end)}')
      ..writeln('=' * 34)
      ..writeln()
      ..writeln('Revenue:      ${formatKsh(k.revenue)}')
      ..writeln('Expenses:     ${formatKsh(k.expenses)}')
      ..writeln('Labour:       ${formatKsh(k.labour)}')
      ..writeln('Total cost:   ${formatKsh(k.totalCost)}')
      ..writeln('${k.netProfit >= 0 ? 'Net profit' : 'Net loss  '}:'
          '   ${formatKsh(k.netProfit.abs())}');

    final margin = k.profitMargin;
    if (margin != null) {
      b.writeln('Margin:       ${(margin * 100).toStringAsFixed(1)}%');
    }
    if (k.hasLabourExclusion) {
      b.writeln(
        'Excluded:     ${formatKsh(k.labourExcluded)} '
        '(labour-category expenses)',
      );
    }
    if (d.pct != null) {
      b.writeln(
        'Profit Δ:     ${d.isUp ? '+' : ''}${d.pct!.toStringAsFixed(1)}% '
        'vs previous period',
      );
    }

    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Financial summary copied to clipboard')),
    );
  }
}

// ===========================================================================
// Hero — the net-profit number
// ===========================================================================
class _ProfitHero extends StatelessWidget {
  const _ProfitHero({required this.kpis});
  final FinancialKpis kpis;

  @override
  Widget build(BuildContext context) {
    final profit = kpis.netProfit;
    final positive = profit >= 0;
    final accent = positive ? _revenueGreen : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? [const Color(0xFF1B5E20), _revenueGreen]
              : [const Color(0xFF8E0000), const Color(0xFFC62828)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                positive ? 'Net profit' : 'Net loss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Icon(
                positive ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${positive ? '' : '−'}${formatKsh(profit.abs())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Revenue', formatShortKsh(kpis.revenue)),
              _divider(),
              _stat('Total cost', formatShortKsh(kpis.totalCost)),
              _divider(),
              _stat(
                'Margin',
                kpis.profitMargin == null
                    ? '—'
                    : '${(kpis.profitMargin! * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

// ===========================================================================
// Composition — revenue split
// ===========================================================================
class _Composition extends StatelessWidget {
  const _Composition({required this.kpis});
  final FinancialKpis kpis;

  @override
  Widget build(BuildContext context) {
    final revenue = kpis.revenue;
    final expenses = kpis.expenses;
    final labour = kpis.labour;
    final profit = kpis.netProfit;

    final scaleBase = [revenue, kpis.totalCost].reduce((a, b) => a > b ? a : b);
    if (scaleBase <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(
          label: 'Revenue',
          value: revenue,
          amount: formatKsh(revenue),
          color: _revenueGreen,
          fillPct: revenue / scaleBase,
        ),
        const SizedBox(height: 14),
        Text(
          'Split of revenue',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        _stackedBar(revenue, expenses, labour, profit),
        const SizedBox(height: 10),
        _legendRow([
          (_costOrange, 'Expenses', expenses),
          (_labourViolet, 'Labour', labour),
          (
            profit >= 0 ? _revenueGreen : const Color(0xFFC62828),
            profit >= 0 ? 'Profit' : 'Loss',
            profit.abs(),
          ),
        ]),
      ],
    );
  }

  Widget _bar({
    required String label,
    required double value,
    required String amount,
    required Color color,
    required double fillPct,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: Colors.black.withValues(alpha: 0.05),
              ),
              FractionallySizedBox(
                widthFactor: fillPct.clamp(0.0, 1.0),
                child: Container(height: 8, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stackedBar(
    double revenue,
    double expenses,
    double labour,
    double profit,
  ) {
    final base = profit >= 0 ? revenue : expenses + labour;
    if (base <= 0) return const SizedBox.shrink();

    final expPct = (expenses / base).clamp(0.0, 1.0);
    final labPct = (labour / base).clamp(0.0, 1.0);
    final profPct = profit >= 0
        ? (profit / base).clamp(0.0, 1.0)
        : ((profit.abs()) / base).clamp(0.0, 1.0);

    final expFlex = (expPct * 1000).round();
    final labFlex = (labPct * 1000).round();
    final profFlex = (profPct * 1000).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 20,
        child: Row(
          children: [
            if (expFlex > 0)
              Expanded(
                flex: expFlex,
                child: Container(color: _costOrange),
              ),
            if (labFlex > 0)
              Expanded(
                flex: labFlex,
                child: Container(color: _labourViolet),
              ),
            if (profFlex > 0)
              Expanded(
                flex: profFlex,
                child: Container(
                  color: profit >= 0
                      ? _revenueGreen
                      : const Color(0xFFC62828),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(List<(Color, String, double)> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items
          .where((e) => e.$3 > 0)
          .map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: e.$1,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.$2}  ${formatShortKsh(e.$3)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }
}

// ===========================================================================
// Monthly profit bars — green when profitable, red when not
// ===========================================================================
class _ProfitBars extends StatelessWidget {
  const _ProfitBars({required this.points});
  final List<DualTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxAbs = points.fold<double>(0, (m, p) {
      final abs = p.profit.abs();
      return abs > m ? abs : m;
    });
    if (maxAbs <= 0) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'No profit activity in this period',
            style: TextStyle(fontSize: 12.5, color: Colors.black45),
          ),
        ),
      );
    }

    final now = DateTime.now();

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final isCurrent =
              p.bucket.year == now.year && p.bucket.month == now.month;
          final profitable = p.profit >= 0;
          final barColor = profitable
              ? _revenueGreen
              : const Color(0xFFC62828);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final h = (p.profit.abs() / maxAbs) * c.maxHeight;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: h),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => Container(
                              height: v,
                              decoration: BoxDecoration(
                                color: barColor.withValues(
                                    alpha: isCurrent ? 1 : 0.75),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
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
    );
  }
}

// ===========================================================================
// Labour note
// ===========================================================================
class _LabourNote extends StatelessWidget {
  const _LabourNote({required this.kpis});
  final FinancialKpis kpis;

  @override
  Widget build(BuildContext context) {
    final mismatch = kpis.hasLabourMismatch;
    final color = mismatch ? _costOrange : _labourViolet;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            mismatch ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mismatch
                  ? 'You have ${formatKsh(kpis.labourExcluded)} in labour-category '
                      'expenses but no labour records. Add them as labour entries, '
                      'or re-categorise those expenses, so the summary is accurate.'
                  : 'Labour-category expenses (${formatKsh(kpis.labourExcluded)}) '
                      'are excluded to avoid double-counting with labour records.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}