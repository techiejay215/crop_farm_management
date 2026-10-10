import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/data/crop_style.dart';
import '../../expenses/expense_format.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

const Color _profitGreen = Color(0xFF2E7D32);
const Color _lossRed = Color(0xFFC62828);

class CropReportScreen extends ConsumerWidget {
  const CropReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(cropReportRangeProvider);
    final reportAsync = ref.watch(cropReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(cropReportProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cropReportProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 8),
            ReportPeriodBar(
              current: range,
              onChanged: (r) =>
                  ref.read(cropReportRangeProvider.notifier).state = r,
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
              data: (crops) {
                final active =
                    crops.where((c) => c.hasActivity).toList();
                if (active.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: ReportEmptyState(
                      icon: Icons.grass_outlined,
                      title: 'Nothing to report yet',
                      message:
                          'Record crops, harvests or sales to see performance '
                          'per crop type.',
                    ),
                  );
                }

                final totals = _Totals.fromCrops(active);

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
                      child: ReportSection(
                        title: 'Ranked by profit',
                        subtitle:
                            '${active.length} ${active.length == 1 ? 'crop' : 'crops'} · tap to open',
                        child: _CropRanking(crops: active),
                      ),
                    ),
                    if (active.any((c) => c.harvestCount > 0)) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Yield by crop',
                          subtitle: 'Net yield, dominant unit per crop',
                          child: _YieldList(crops: active),
                        ),
                      ),
                    ],
                    if (active.any((c) => c.saleCount > 0)) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Average sale price',
                          subtitle: 'Revenue ÷ quantity sold, per crop',
                          child: _PriceList(crops: active),
                        ),
                      ),
                    ],
                    if (active.any((c) => c.wasted > 0)) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Waste by crop',
                          subtitle: 'Highest waste first',
                          child: _WasteList(crops: active),
                        ),
                      ),
                    ],
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
        label: 'Expenses',
        value: formatShortKsh(t.expenses),
        color: AppTheme.expenseOrange,
      ),
      KpiData(
        icon: positive ? Icons.trending_up : Icons.trending_down,
        label: positive ? 'Net profit' : 'Net loss',
        value: formatShortKsh(profit.abs()),
        color: positive ? _profitGreen : _lossRed,
      ),
      KpiData(
        icon: Icons.grass_outlined,
        label: 'Crops tracked',
        value: '${t.ranked.length}',
        color: CropStyle.primary,
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

    ref.read(cropReportRangeProvider.notifier).state = ReportRange(
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
  final double totalYield;
  final List<CropFinancials> ranked;

  _Totals({
    required this.revenue,
    required this.expenses,
    required this.totalYield,
    required this.ranked,
  });

  factory _Totals.fromCrops(List<CropFinancials> crops) {
    var revenue = 0.0;
    var expenses = 0.0;
    var yield_ = 0.0;
    for (final c in crops) {
      revenue += c.revenue;
      expenses += c.expenses;
      yield_ += c.netYield;
    }
    return _Totals(
      revenue: revenue,
      expenses: expenses,
      totalYield: yield_,
      ranked: crops,
    );
  }

  double get profit => revenue - expenses;
  double? get margin => revenue <= 0 ? null : profit / revenue;
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
              ? CropStyle.heroGradient.colors
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
                positive ? 'Net profit from crops' : 'Net loss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Icon(Icons.grass_outlined,
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
              _stat('Expenses', formatShortKsh(totals.expenses)),
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
// Ranked crops — now tappable
// ===========================================================================
class _CropRanking extends StatelessWidget {
  const _CropRanking({required this.crops});
  final List<CropFinancials> crops;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < crops.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(context, crops[i], i + 1),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, CropFinancials c, int rank) {
    final profit = c.profit;
    final positive = profit >= 0;
    final profitColor = positive ? _profitGreen : _lossRed;
    final color = CropStyle.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(
          '/reports/crop/${Uri.encodeComponent(c.cropName)}/detail',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.cropName,
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
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.dominantUnit.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (c.cropCount > 0) '${c.cropCount} planted',
                        if (c.saleCount > 0) '${c.saleCount} sales',
                        if (c.netYield > 0)
                          '${formatQuantity(c.netYield, c.dominantUnit)} net',
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
                  if (c.margin != null)
                    Text(
                      '${(c.margin! * 100).toStringAsFixed(0)}% margin',
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
// Yield list
// ===========================================================================
class _YieldList extends StatelessWidget {
  const _YieldList({required this.crops});
  final List<CropFinancials> crops;

  @override
  Widget build(BuildContext context) {
    final withYield = crops.where((c) => c.harvestCount > 0).toList()
      ..sort((a, b) => b.netYield.compareTo(a.netYield));
    if (withYield.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxNet = withYield
        .map((c) => c.netYield)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < withYield.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _row(withYield[i], maxNet),
        ],
      ],
    );
  }

  Widget _row(CropFinancials c, double maxNet) {
    final fill = maxNet <= 0 ? 0.0 : c.netYield / maxNet;
    final wasteColor = _wasteColor(c.wasteRatio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      c.cropName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (c.wasted > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: wasteColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(c.wasteRatio * 100).toStringAsFixed(0)}% waste',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: wasteColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              formatQuantity(c.netYield, c.dominantUnit),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: CropStyle.primaryDeep,
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
            backgroundColor: CropStyle.primary.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(CropStyle.primary),
          ),
        ),
      ],
    );
  }

  Color _wasteColor(double ratio) {
    if (ratio <= 0.03) return const Color(0xFF2E7D32);
    if (ratio <= 0.10) return const Color(0xFFF9A825);
    return const Color(0xFFC62828);
  }
}

// ===========================================================================
// Average price per unit
// ===========================================================================
class _PriceList extends StatelessWidget {
  const _PriceList({required this.crops});
  final List<CropFinancials> crops;

  @override
  Widget build(BuildContext context) {
    final withPrice =
        crops.where((c) => c.saleCount > 0 && c.averagePricePerUnit > 0).toList()
          ..sort((a, b) =>
              b.averagePricePerUnit.compareTo(a.averagePricePerUnit));
    if (withPrice.isEmpty) return const SizedBox.shrink();

    final maxPrice = withPrice
        .map((c) => c.averagePricePerUnit)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < withPrice.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _row(withPrice[i], maxPrice),
        ],
      ],
    );
  }

  Widget _row(CropFinancials c, double maxPrice) {
    final fill = maxPrice <= 0 ? 0.0 : c.averagePricePerUnit / maxPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.cropName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${formatKsh(c.averagePricePerUnit)} / ${c.dominantUnit}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E88E5),
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
            backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF1E88E5)),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Waste list
// ===========================================================================
class _WasteList extends StatelessWidget {
  const _WasteList({required this.crops});
  final List<CropFinancials> crops;

  @override
  Widget build(BuildContext context) {
    final withWaste =
        crops.where((c) => c.wasted > 0).toList()
          ..sort((a, b) => b.wasteRatio.compareTo(a.wasteRatio));
    if (withWaste.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < withWaste.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _row(withWaste[i]),
        ],
      ],
    );
  }

  Widget _row(CropFinancials c) {
    final color = _wasteColor(c.wasteRatio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.cropName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatQuantity(c.wasted, c.dominantUnit),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(c.wasteRatio * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: c.wasteRatio.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Color _wasteColor(double ratio) {
    if (ratio <= 0.03) return const Color(0xFF2E7D32);
    if (ratio <= 0.10) return const Color(0xFFF9A825);
    return const Color(0xFFC62828);
  }
}