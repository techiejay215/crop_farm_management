import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../sales/data/sale_model.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';
import '../../expenses/expense_format.dart';

const Color _salesBlue = Color(0xFF1E88E5);

class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

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
    final kpis = ref.watch(salesKpisProvider);
    final range = ref.watch(salesReportRangeProvider);
    final delta = ref.watch(salesDeltaProvider);
    final byCrop = ref.watch(salesByCropProvider);
    final byBuyer = ref.watch(salesByBuyerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          if (!kpis.isEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Copy summary',
              onPressed: () => _copySummary(
                  context, range, kpis, delta, byCrop, byBuyer),
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
    final kpis = ref.watch(salesKpisProvider);
    final range = ref.watch(salesReportRangeProvider);
    final delta = ref.watch(salesDeltaProvider);
    final byCrop = ref.watch(salesByCropProvider);
    final byBuyer = ref.watch(salesByBuyerProvider);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: Column(
        children: [
          _buildDesktopHeader(
            context,
            kpis,
            range,
            delta,
            byCrop,
            byBuyer,
          ),
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
    SalesKpis kpis,
    ReportRange range,
    PeriodDelta delta,
    List<BreakdownRow> byCrop,
    List<BreakdownRow> byBuyer,
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
                colors: [Color(0xFF0D47A1), _salesBlue],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _salesBlue.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.point_of_sale_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Report',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Revenue, best sellers and top buyers.',
                  style: TextStyle(fontSize: 13, color: DPalette.inkMuted),
                ),
              ],
            ),
          ),
          if (!kpis.isEmpty)
            OutlinedButton.icon(
              onPressed: () => _copySummary(
                  context, range, kpis, delta, byCrop, byBuyer),
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
    final range = ref.watch(salesReportRangeProvider);
    final kpis = ref.watch(salesKpisProvider);
    final delta = ref.watch(salesDeltaProvider);
    final byCrop = ref.watch(salesByCropProvider);
    final byBuyer = ref.watch(salesByBuyerProvider);
    final trend = ref.watch(salesMonthlyTrendProvider);
    final top = ref.watch(topSalesProvider);

    if (kpis.isEmpty) {
      return [
        const SizedBox(height: 8),
        ReportPeriodBar(
          current: range,
          onChanged: (r) =>
              ref.read(salesReportRangeProvider.notifier).state = r,
          onCustomTap: () => _pickCustom(context, ref, range),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ReportRangeInfo(range: range),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: ReportEmptyState(
            icon: Icons.point_of_sale_outlined,
            title: 'No sales in this period',
            message:
                'Try a wider range, or record some sales from the Sales tab.',
          ),
        ),
      ];
    }

    // Pre-built sections
    final cropSection = ReportSection(
      title: 'Revenue by crop',
      subtitle:
          '${byCrop.length} ${byCrop.length == 1 ? 'crop' : 'crops'}',
      child: _breakdown(byCrop, Icons.grass_outlined),
    );

    final buyerSection = ReportSection(
      title: 'Top buyers',
      subtitle: byBuyer.length > 5
          ? 'Top 5 of ${byBuyer.length}'
          : '${byBuyer.length} ${byBuyer.length == 1 ? 'buyer' : 'buyers'}',
      child: _breakdown(
        byBuyer.take(5).toList(),
        Icons.person_outline,
      ),
    );

    final trendSection = ReportSection(
      title: 'Monthly revenue',
      subtitle: _trendSubtitle(trend),
      child: TrendBars(
        points: trend,
        barColor: _salesBlue,
      ),
    );

    final topSection = ReportSection(
      title: 'Biggest sales',
      subtitle: 'Top ${top.length} of ${kpis.count}',
      child: _topSalesList(top),
    );

    final statusRow = _statusRow(kpis);
    final comparison = _comparisonSection(range, delta);

    if (isDesktop) {
      return [
        const SizedBox(height: 8),
        ReportPeriodBar(
          current: range,
          onChanged: (r) =>
              ref.read(salesReportRangeProvider.notifier).state = r,
          onCustomTap: () => _pickCustom(context, ref, range),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ReportRangeInfo(
            range: range,
            trailing: formatShortKsh(kpis.revenue),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: KpiGrid(items: _kpiItems(kpis, delta), columns: 4),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: statusRow,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: comparison,
        ),

        // Revenue by crop | Top buyers
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cropSection),
                const SizedBox(width: 16),
                Expanded(child: buyerSection),
              ],
            ),
          ),
        ),

        // Monthly revenue | Biggest sales
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: trendSection),
                const SizedBox(width: 16),
                Expanded(child: topSection),
              ],
            ),
          ),
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
            ref.read(salesReportRangeProvider.notifier).state = r,
        onCustomTap: () => _pickCustom(context, ref, range),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ReportRangeInfo(
          range: range,
          trailing: formatShortKsh(kpis.revenue),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: KpiGrid(items: _kpiItems(kpis, delta)),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: statusRow,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: comparison,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: cropSection,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: buyerSection,
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
      const SizedBox(height: 32),
    ];
  }

  // -------------------------------------------------------------------------
  // KPI construction
  // -------------------------------------------------------------------------
  List<KpiData> _kpiItems(SalesKpis k, PeriodDelta d) {
    final pct = d.pct;
    return [
      KpiData(
        icon: Icons.payments_outlined,
        label: 'Revenue',
        value: formatKsh(k.revenue),
        delta: pct == null
            ? null
            : '${d.isUp ? '+' : ''}${pct.toStringAsFixed(1)}% vs prev',
        deltaIsUp: pct == null ? null : d.isUp,
        deltaIsPositive: pct == null ? null : d.isUp,
        color: _salesBlue,
      ),
      KpiData(
        icon: Icons.receipt_long_outlined,
        label: 'Sales',
        value: '${k.count}',
        color: AppTheme.primaryGreen,
      ),
      KpiData(
        icon: Icons.trending_up,
        label: 'Average',
        value: formatKsh(k.average),
        color: const Color(0xFF7E57C2),
      ),
      KpiData(
        icon: Icons.scale_outlined,
        label: 'Quantity',
        value: formatQuantity(k.quantity, k.quantityUnit),
        color: const Color(0xFF00897B),
      ),
    ];
  }

  /// Small row under the KPIs: pending (if any) + top buyer.
  Widget _statusRow(SalesKpis k) {
    final children = <Widget>[];

    if (k.hasPending) {
      children.add(_stat(
        'Pending',
        formatKsh(k.pendingAmount),
        accent: AppTheme.expenseOrange,
        subtitle: '${k.pendingCount} unpaid',
      ));
    }
    if (k.topBuyer != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(_stat(
        'Top buyer',
        k.topBuyer!,
        subtitle: formatKsh(k.topBuyerRevenue),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();

    return Row(children: children.map((w) => Expanded(child: w)).toList());
  }

  Widget _stat(
    String label,
    String value, {
    String? subtitle,
    Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (accent ?? Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent ?? Colors.black45,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: accent ?? Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
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
      previousLabel: 'Previous period: ${formatKsh(d.previous)}',
      delta: d,
      positiveWhenUp: true,
    );
  }

  // -------------------------------------------------------------------------
  // Breakdown helpers — colour rotates by rank position
  // -------------------------------------------------------------------------
  Widget _breakdown(List<BreakdownRow> rows, IconData icon) {
    final colorMap = <String, Color>{};
    for (var i = 0; i < rows.length; i++) {
      colorMap[rows[i].key] = salesColorAt(i);
    }
    return BreakdownTable(
      rows: rows,
      colorFor: (k) => colorMap[k] ?? salesColorAt(0),
      iconFor: (_) => icon,
    );
  }

  String _trendSubtitle(List<TrendPoint> points) {
    if (points.isEmpty) return '';
    final total = points.fold<double>(0, (s, p) => s + p.value);
    final avg = total / points.length;
    return 'Avg ${formatKsh(avg)} / month';
  }

  // -------------------------------------------------------------------------
  // Ranked sales
  // -------------------------------------------------------------------------
  Widget _topSalesList(List<Sale> sales) {
    return Column(
      children: [
        for (var i = 0; i < sales.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _topRow(sales[i], i + 1),
        ],
      ],
    );
  }

  Widget _topRow(Sale s, int rank) {
    final color = salesColorAt(rank - 1);
    final dateStr = s.saleDate != null ? dayLabel(s.saleDate!) : '';
    final qtyStr = formatQuantity(s.quantity, s.unit);

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.buyer.isNotEmpty ? s.buyer : '(no buyer)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (s.cropName.isNotEmpty) s.cropName,
                  qtyStr,
                  if (dateStr.isNotEmpty) dateStr,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Text(
          formatKsh(s.totalAmount),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _salesBlue,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Custom range picker
  // -------------------------------------------------------------------------
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

    ref.read(salesReportRangeProvider.notifier).state = ReportRange(
      preset: ReportPreset.custom,
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }

  // -------------------------------------------------------------------------
  // Copy summary
  // -------------------------------------------------------------------------
  void _copySummary(
    BuildContext context,
    ReportRange range,
    SalesKpis k,
    PeriodDelta d,
    List<BreakdownRow> byCrop,
    List<BreakdownRow> byBuyer,
  ) {
    final b = StringBuffer()
      ..writeln('SALES REPORT')
      ..writeln('${fullDate(range.start)} — ${fullDate(range.end)}')
      ..writeln('=' * 34)
      ..writeln()
      ..writeln('Revenue:     ${formatKsh(k.revenue)}')
      ..writeln('Sales:       ${k.count}')
      ..writeln('Average:     ${formatKsh(k.average)}')
      ..writeln('Highest:     ${formatKsh(k.highest)}')
      ..writeln('Quantity:    ${formatQuantity(k.quantity, k.quantityUnit)}');

    if (k.hasPending) {
      b.writeln(
        'Pending:     ${formatKsh(k.pendingAmount)} '
        '(${k.pendingCount} unpaid)',
      );
    }
    if (d.pct != null) {
      b.writeln(
        'Change:      ${d.isUp ? '+' : ''}${d.pct!.toStringAsFixed(1)}% '
        'vs previous period',
      );
    }

    b
      ..writeln()
      ..writeln('BY CROP')
      ..writeln('-' * 34);
    for (final r in byCrop) {
      b.writeln(
        '${r.label.padRight(24)} ${formatKsh(r.total).padLeft(12)}  '
        '${(r.share * 100).toStringAsFixed(1)}%',
      );
    }

    if (byBuyer.isNotEmpty) {
      b
        ..writeln()
        ..writeln('TOP BUYERS')
        ..writeln('-' * 34);
      for (final r in byBuyer.take(5)) {
        b.writeln(
          '${r.label.padRight(24)} ${formatKsh(r.total).padLeft(12)}',
        );
      }
    }

    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sales report copied to clipboard')),
    );
  }
}