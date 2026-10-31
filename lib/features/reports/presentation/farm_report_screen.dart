import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../expenses/expense_format.dart';
import '../../farms/data/farm_style.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

const Color _profitGreen = Color(0xFF2E7D32);
const Color _lossRed = Color(0xFFC62828);

class FarmReportScreen extends ConsumerWidget {
  const FarmReportScreen({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(farmReportProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(farmReportProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: _buildContent(context, ref, isDesktop: false),
        ),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: Column(
        children: [
          _buildDesktopHeader(context, ref),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(farmReportProvider),
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
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, WidgetRef ref) {
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FarmStyle.primaryDeep, FarmStyle.primary],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: FarmStyle.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.agriculture_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Report',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Production, costs and revenue per farm.',
                  style: TextStyle(fontSize: 13, color: DPalette.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: DPalette.ink),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(farmReportProvider),
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
    final range = ref.watch(farmReportRangeProvider);
    final reportAsync = ref.watch(farmReportProvider);

    return [
      const SizedBox(height: 8),
      ReportPeriodBar(
        current: range,
        onChanged: (r) =>
            ref.read(farmReportRangeProvider.notifier).state = r,
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
        data: (farms) {
          final active = farms.where((f) => f.hasActivity).toList();
          if (active.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: ReportEmptyState(
                icon: Icons.agriculture_outlined,
                title: 'Nothing to report yet',
                message:
                    'Record sales, expenses or harvests on a farm to see '
                    'it here.',
              ),
            );
          }

          final totals = _Totals.fromFarms(active);

          final rankedSection = ReportSection(
            title: 'Ranked by profit',
            subtitle:
                '${active.length} ${active.length == 1 ? 'farm' : 'farms'}',
            child: _FarmRanking(farms: active),
          );

          final costSection = ReportSection(
            title: 'Cost composition',
            subtitle: 'Where money goes per farm',
            child: _CostComposition(farms: active),
          );

          final yieldSection = ReportSection(
            title: 'Yield by farm',
            subtitle: 'Net yield, dominant unit per farm',
            child: _YieldList(farms: active),
          );

          final hasYield = active.any((f) => f.harvestCount > 0);

          if (isDesktop) {
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
                  child: KpiGrid(items: _kpiItems(totals), columns: 4),
                ),
                const SizedBox(height: 16),

                // Ranked — full width
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: rankedSection,
                ),
                const SizedBox(height: 16),

                // Cost composition | Yield (side-by-side when yield exists)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: hasYield
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: costSection),
                              const SizedBox(width: 16),
                              Expanded(child: yieldSection),
                            ],
                          ),
                        )
                      : costSection,
                ),
                const SizedBox(height: 32),
              ],
            );
          }

          // Mobile — original stacking order preserved
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: rankedSection,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: costSection,
              ),
              if (hasYield) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: yieldSection,
                ),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    ];
  }

  List<KpiData> _kpiItems(_Totals t) {
    final profit = t.profit;
    final positive = profit >= 0;
    final profitableFarms = t.ranked.where((f) => f.profit > 0).length;

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
        icon: Icons.check_circle_outline,
        label: 'Profitable',
        value: '$profitableFarms / ${t.ranked.length}',
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

    ref.read(farmReportRangeProvider.notifier).state = ReportRange(
      preset: ReportPreset.custom,
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }
}

// ===========================================================================
// Totals helper
// ===========================================================================
class _Totals {
  final double revenue;
  final double expenses;
  final double labour;
  final double acreage;
  final List<FarmFinancials> ranked;

  _Totals({
    required this.revenue,
    required this.expenses,
    required this.labour,
    required this.acreage,
    required this.ranked,
  });

  factory _Totals.fromFarms(List<FarmFinancials> farms) {
    var revenue = 0.0;
    var expenses = 0.0;
    var labour = 0.0;
    var acreage = 0.0;
    for (final f in farms) {
      revenue += f.revenue;
      expenses += f.expenses;
      labour += f.labour;
      acreage += f.acreage;
    }
    return _Totals(
      revenue: revenue,
      expenses: expenses,
      labour: labour,
      acreage: acreage,
      ranked: farms,
    );
  }

  double get totalCost => expenses + labour;
  double get profit => revenue - totalCost;
  double? get margin => revenue <= 0 ? null : profit / revenue;
  double? get profitPerAcre => acreage <= 0 ? null : profit / acreage;
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
              ? [FarmStyle.primaryDeep, FarmStyle.primary]
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
                positive ? 'Net profit across farms' : 'Net loss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Icon(Icons.agriculture_outlined,
                  size: 18, color: Colors.white.withValues(alpha: 0.8)),
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
              _stat('Revenue', formatShortKsh(totals.revenue)),
              _divider(),
              _stat('Total cost', formatShortKsh(totals.totalCost)),
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
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

// ===========================================================================
// Ranked farm list
// ===========================================================================
class _FarmRanking extends StatelessWidget {
  const _FarmRanking({required this.farms});
  final List<FarmFinancials> farms;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < farms.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(farms[i], i + 1),
        ],
      ],
    );
  }

  Widget _row(FarmFinancials f, int rank) {
    final profit = f.profit;
    final positive = profit >= 0;
    final profitColor = positive ? _profitGreen : _lossRed;
    final typeColor = FarmStyle.typeColor(f.type);

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: typeColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      f.farmName.isEmpty ? '(unnamed farm)' : f.farmName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      FarmStyle.typeLabel(f.type).toUpperCase(),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: typeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                [
                  if (f.location.isNotEmpty) f.location,
                  '${f.acreage.toStringAsFixed(f.acreage == f.acreage.roundToDouble() ? 0 : 1)} ac',
                  '${f.saleCount} sales',
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
            if (f.margin != null)
              Text(
                '${(f.margin! * 100).toStringAsFixed(0)}% margin',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// Cost composition — mini stacked bars per farm
// ===========================================================================
class _CostComposition extends StatelessWidget {
  const _CostComposition({required this.farms});
  final List<FarmFinancials> farms;

  @override
  Widget build(BuildContext context) {
    final withCost = farms.where((f) => f.totalCost > 0).toList();
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
          _row(withCost[i]),
        ],
      ],
    );
  }

  Widget _row(FarmFinancials f) {
    final total = f.totalCost;
    if (total <= 0) return const SizedBox.shrink();

    final expShare = f.expenses / total;
    final labShare = f.labour / total;
    final expFlex = (expShare * 1000).round().clamp(0, 1000);
    final labFlex = (labShare * 1000).round().clamp(0, 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                f.farmName.isEmpty ? '(unnamed farm)' : f.farmName,
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
            _miniLegend(
              AppTheme.expenseOrange,
              'Expenses ${formatShortKsh(f.expenses)}',
            ),
            const SizedBox(width: 12),
            _miniLegend(
              const Color(0xFF7E57C2),
              'Labour ${formatShortKsh(f.labour)}',
            ),
          ],
        ),
      ],
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

// ===========================================================================
// Yield by farm
// ===========================================================================
class _YieldList extends StatelessWidget {
  const _YieldList({required this.farms});
  final List<FarmFinancials> farms;

  @override
  Widget build(BuildContext context) {
    final withYield =
        farms.where((f) => f.harvestCount > 0).toList()
          ..sort((a, b) => b.netYield.compareTo(a.netYield));

    if (withYield.isEmpty) {
      return Text(
        'No harvests in this period.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withValues(alpha: 0.5),
        ),
      );
    }

    final maxNet =
        withYield.map((f) => f.netYield).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < withYield.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _row(withYield[i], maxNet),
        ],
      ],
    );
  }

  Widget _row(FarmFinancials f, double maxNet) {
    final fill = maxNet <= 0 ? 0.0 : (f.netYield / maxNet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                f.farmName.isEmpty ? '(unnamed farm)' : f.farmName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatQuantity(f.netYield, f.yieldUnit),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: FarmStyle.primaryDeep,
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
            backgroundColor: FarmStyle.primary.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(FarmStyle.primary),
          ),
        ),
      ],
    );
  }
}