import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/expense_format.dart';
import '../../greenhouses/data/greenhouse_style.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

const Color _profitGreen = Color(0xFF2E7D32);
const Color _lossRed = Color(0xFFC62828);

class GreenhouseReportScreen extends ConsumerWidget {
  const GreenhouseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(greenhouseReportRangeProvider);
    final reportAsync = ref.watch(greenhouseReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reports');
            }
          },
        ),
        title: const Text('Greenhouse Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(greenhouseReportProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(greenhouseReportProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 8),
            ReportPeriodBar(
              current: range,
              onChanged: (r) =>
                  ref.read(greenhouseReportRangeProvider.notifier).state = r,
              onCustomTap: () => _pickCustom(context, ref, range),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ReportRangeInfo(range: range),
            ),
            reportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e'),
              ),
              data: (greenhouses) {
                if (greenhouses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: ReportEmptyState(
                      icon: Icons.warehouse_outlined,
                      title: 'No greenhouses',
                      message:
                          'Add a greenhouse and record harvests, sales or '
                          'expenses against its location name to see it here.',
                    ),
                  );
                }

                final active =
                    greenhouses.where((g) => g.hasActivity).toList();
                if (active.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: ReportEmptyState(
                      icon: Icons.warehouse_outlined,
                      title: 'No activity yet',
                      message:
                          'Attribute harvests, sales or expenses to a '
                          'greenhouse\'s location to see its performance here.',
                    ),
                  );
                }

                final totals = _Totals.from(active);

                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ProfitHero(totals: totals),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: KpiGrid(items: _kpiItems(totals)),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _IntensityRow(totals: totals),
                    ),
                    const SizedBox(height: 20),

                    // ---- Ranked greenhouses (tappable) ----
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ReportSection(
                        title: 'Ranked by profit / m²',
                        subtitle:
                            '${active.length} ${active.length == 1 ? 'greenhouse' : 'greenhouses'} · tap to open',
                        child: _RankingList(greenhouses: active),
                      ),
                    ),

                    if (active.any((g) => g.netYield > 0)) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Yield intensity',
                          subtitle: 'Net units per m²',
                          child: _YieldIntensityList(greenhouses: active),
                        ),
                      ),
                    ],

                    if (active.any((g) => g.density != null)) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Plant density',
                          subtitle: 'Plants per m²',
                          child: _DensityList(greenhouses: active),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ReportSection(
                        title: 'Cost composition',
                        subtitle: 'Where money goes per greenhouse',
                        child: _CostComposition(greenhouses: active),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<KpiData> _kpiItems(_Totals t) {
    final profit = t.profit;
    final positive = profit >= 0;

    return [
      KpiData(
        icon: Icons.payments_outlined,
        label: 'Revenue',
        value: formatShortKsh(t.revenue),
        color: _profitGreen,
      ),
      KpiData(
        icon: Icons.trending_down,
        label: 'Total cost',
        value: formatShortKsh(t.totalCost),
        color: AppTheme.expenseOrange,
      ),
      KpiData(
        icon: positive ? Icons.trending_up : Icons.trending_down,
        label: positive ? 'Net profit' : 'Net loss',
        value: formatShortKsh(profit.abs()),
        color: positive ? _profitGreen : _lossRed,
      ),
      KpiData(
        icon: Icons.square_foot_outlined,
        label: 'Profit / m²',
        value: t.profitPerSqm == null ? '—' : formatKsh(t.profitPerSqm!),
        color: const Color(0xFF1E88E5),
      ),
    ];
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

    ref.read(greenhouseReportRangeProvider.notifier).state = ReportRange(
      preset: ReportPreset.custom,
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }
}

// ===========================================================================
// Totals
// ===========================================================================
class _Totals {
  final double revenue;
  final double expenses;
  final double labour;
  final double area;
  final int plants;
  final double netYield;
  final List<GreenhouseFinancials> ranked;

  _Totals({
    required this.revenue,
    required this.expenses,
    required this.labour,
    required this.area,
    required this.plants,
    required this.netYield,
    required this.ranked,
  });

  factory _Totals.from(List<GreenhouseFinancials> list) {
    var r = 0.0, e = 0.0, l = 0.0, a = 0.0, y = 0.0;
    var p = 0;
    for (final g in list) {
      r += g.revenue;
      e += g.expenses;
      l += g.labour;
      a += g.size;
      p += g.plantCount;
      y += g.netYield;
    }
    return _Totals(
      revenue: r,
      expenses: e,
      labour: l,
      area: a,
      plants: p,
      netYield: y,
      ranked: list,
    );
  }

  double get totalCost => expenses + labour;
  double get profit => revenue - totalCost;
  double? get margin => revenue <= 0 ? null : profit / revenue;
  double? get profitPerSqm => area <= 0 ? null : profit / area;
  double? get revenuePerSqm => area <= 0 ? null : revenue / area;
  double? get costPerSqm => area <= 0 ? null : totalCost / area;
  double? get density => area <= 0 || plants <= 0 ? null : plants / area;
}

// ===========================================================================
// Profit hero
// ===========================================================================
class _ProfitHero extends StatelessWidget {
  const _ProfitHero({required this.totals});
  final _Totals totals;

  @override
  Widget build(BuildContext context) {
    final profit = totals.profit;
    final positive = profit >= 0;
    final accent = positive ? _profitGreen : _lossRed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? GreenhouseStyle.heroGradient.colors
              : [const Color(0xFF8E0000), _lossRed],
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
                positive ? 'Net profit under glass' : 'Net loss under glass',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Icon(Icons.warehouse_outlined,
                  size: 18, color: Colors.white.withValues(alpha: 0.85)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${positive ? '' : '−'}${formatKsh(profit.abs())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          if (totals.profitPerSqm != null) ...[
            const SizedBox(height: 6),
            Text(
              '${formatKsh(totals.profitPerSqm!)} per m² across ${totals.area.toStringAsFixed(0)} m²',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Area', '${totals.area.toStringAsFixed(0)} m²'),
              _divider(),
              _stat('Plants', _fmtCount(totals.plants)),
              _divider(),
              _stat(
                'Margin',
                totals.margin == null
                    ? '—'
                    : '${(totals.margin! * 100).toStringAsFixed(0)}%',
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
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.2),
      );

  static String _fmtCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ===========================================================================
// Intensity strip
// ===========================================================================
class _IntensityRow extends StatelessWidget {
  const _IntensityRow({required this.totals});
  final _Totals totals;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _tile(
            'Density',
            totals.density == null
                ? '—'
                : '${totals.density!.toStringAsFixed(totals.density! < 10 ? 1 : 0)}/m²',
            Icons.density_medium_outlined,
            GreenhouseStyle.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _tile(
            'Revenue / m²',
            totals.revenuePerSqm == null
                ? '—'
                : formatShortKsh(totals.revenuePerSqm!),
            Icons.payments_outlined,
            const Color(0xFF1E88E5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _tile(
            'Cost / m²',
            totals.costPerSqm == null
                ? '—'
                : formatShortKsh(totals.costPerSqm!),
            Icons.trending_down,
            AppTheme.expenseOrange,
          ),
        ),
      ],
    );
  }

  Widget _tile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Ranking list — TAPPABLE, drills into the greenhouse detail screen
// ===========================================================================
class _RankingList extends StatelessWidget {
  const _RankingList({required this.greenhouses});
  final List<GreenhouseFinancials> greenhouses;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < greenhouses.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(context, greenhouses[i], i + 1),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, GreenhouseFinancials g, int rank) {
    final profit = g.profit;
    final positive = profit >= 0;
    final profitColor = positive ? _profitGreen : _lossRed;
    final rankColor = GreenhouseStyle.paletteAt(rank - 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/greenhouses/${g.greenhouseId}/detail'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name.isEmpty ? '(unnamed)' : g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (g.currentCrop.isNotEmpty) g.currentCrop,
                        '${g.size.toStringAsFixed(0)} m²',
                        if (g.profitPerSqm != null)
                          '${formatKsh(g.profitPerSqm!)}/m²',
                      ].join('  ·  '),
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
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${positive ? '' : '−'}${formatKsh(profit.abs())}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: profitColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (g.margin != null)
                    Text(
                      '${(g.margin! * 100).toStringAsFixed(0)}% margin',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Density list — tappable
// ===========================================================================
class _DensityList extends StatelessWidget {
  const _DensityList({required this.greenhouses});
  final List<GreenhouseFinancials> greenhouses;

  @override
  Widget build(BuildContext context) {
    final withDensity = greenhouses.where((g) => g.density != null).toList()
      ..sort((a, b) => b.density!.compareTo(a.density!));

    if (withDensity.isEmpty) {
      return Text(
        'Add plant counts and greenhouse sizes to see density.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withValues(alpha: 0.5),
        ),
      );
    }

    final maxDensity = withDensity.first.density!;

    return Column(
      children: [
        for (var i = 0; i < withDensity.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _row(context, withDensity[i], maxDensity),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    GreenhouseFinancials g,
    double maxDensity,
  ) {
    final density = g.density!;
    final fill = maxDensity <= 0 ? 0.0 : density / maxDensity;
    final color = GreenhouseStyle.densityColor(density);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/greenhouses/${g.greenhouseId}/detail'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.name.isEmpty ? '(unnamed)' : g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    GreenhouseStyle.densityLabel(density),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fill.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: color.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(color),
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
// Yield intensity list — tappable
// ===========================================================================
class _YieldIntensityList extends StatelessWidget {
  const _YieldIntensityList({required this.greenhouses});
  final List<GreenhouseFinancials> greenhouses;

  @override
  Widget build(BuildContext context) {
    final withYield = greenhouses
        .where((g) => g.yieldPerSqm != null && g.netYield > 0)
        .toList()
      ..sort((a, b) => b.yieldPerSqm!.compareTo(a.yieldPerSqm!));

    if (withYield.isEmpty) return const SizedBox.shrink();

    final maxY = withYield.first.yieldPerSqm!;

    return Column(
      children: [
        for (var i = 0; i < withYield.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _row(context, withYield[i], maxY),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    GreenhouseFinancials g,
    double maxY,
  ) {
    final perSqm = g.yieldPerSqm!;
    final fill = maxY <= 0 ? 0.0 : perSqm / maxY;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/greenhouses/${g.greenhouseId}/detail'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.name.isEmpty ? '(unnamed)' : g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${perSqm.toStringAsFixed(perSqm < 10 ? 2 : 1)} ${g.yieldUnit}/m²',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: GreenhouseStyle.primaryDeep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fill.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor:
                      GreenhouseStyle.primary.withValues(alpha: 0.08),
                  valueColor:
                      const AlwaysStoppedAnimation(GreenhouseStyle.primary),
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
// Cost composition — tappable
// ===========================================================================
class _CostComposition extends StatelessWidget {
  const _CostComposition({required this.greenhouses});
  final List<GreenhouseFinancials> greenhouses;

  @override
  Widget build(BuildContext context) {
    final withCost = greenhouses.where((g) => g.totalCost > 0).toList();
    if (withCost.isEmpty) {
      return Text(
        'No costs recorded in this period.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withValues(alpha: 0.5),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < withCost.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _row(context, withCost[i]),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, GreenhouseFinancials g) {
    final total = g.totalCost;
    if (total <= 0) return const SizedBox.shrink();

    final expFlex = ((g.expenses / total) * 1000).round().clamp(0, 1000);
    final labFlex = ((g.labour / total) * 1000).round().clamp(0, 1000);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/greenhouses/${g.greenhouseId}/detail'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.name.isEmpty ? '(unnamed)' : g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatKsh(total),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.expenseOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      if (expFlex > 0)
                        Expanded(
                          flex: expFlex,
                          child: Container(color: AppTheme.expenseOrange),
                        ),
                      if (labFlex > 0)
                        Expanded(
                          flex: labFlex,
                          child: Container(color: const Color(0xFF7E57C2)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _miniLegend(AppTheme.expenseOrange,
                      'Expenses ${formatShortKsh(g.expenses)}'),
                  const SizedBox(width: 12),
                  _miniLegend(const Color(0xFF7E57C2),
                      'Labour ${formatShortKsh(g.labour)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}