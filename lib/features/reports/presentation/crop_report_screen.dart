import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
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
      backgroundColor: AppTheme.background,
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
              onRefresh: () async => ref.invalidate(cropReportProvider),
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
                colors: CropStyle.heroGradient.colors,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: CropStyle.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.grass_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crop Report',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Profitability, yield and price per crop.',
                  style: TextStyle(fontSize: 13, color: DPalette.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: DPalette.ink),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(cropReportProvider),
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
    final range = ref.watch(cropReportRangeProvider);
    final reportAsync = ref.watch(cropReportProvider);

    return [
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
          final active = crops.where((c) => c.hasActivity).toList();
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

          // Secondary sections — yield, price, waste
          final secondary = <Widget>[];
          if (active.any((c) => c.harvestCount > 0)) {
            secondary.add(ReportSection(
              title: 'Yield by crop',
              subtitle: 'Net yield, dominant unit per crop',
              child: _YieldList(crops: active),
            ));
          }
          if (active.any((c) => c.saleCount > 0)) {
            secondary.add(ReportSection(
              title: 'Average sale price',
              subtitle: 'Revenue ÷ quantity sold, per crop',
              child: _PriceList(crops: active),
            ));
          }
          if (active.any((c) => c.wasted > 0)) {
            secondary.add(ReportSection(
              title: 'Waste by crop',
              subtitle: 'Highest waste first',
              child: _WasteList(crops: active),
            ));
          }

          return Column(
            children: [
              const SizedBox(height: 20),

              // Hero
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProfitHero(totals: totals),
              ),
              const SizedBox(height: 18),

              // KPIs — 4 columns on desktop, 2 on mobile
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KpiGrid(
                  items: _kpiItems(totals),
                  columns: isDesktop ? 4 : 2,
                ),
              ),
              const SizedBox(height: 18),

              // Ranked by profit — full width
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ReportSection(
                  title: 'Ranked by profit',
                  subtitle:
                      '${active.length} ${active.length == 1 ? 'crop' : 'crops'} · tap to open',
                  child: _CropRanking(crops: active),
                ),
              ),

              // Secondary sections — side-by-side on desktop, stacked on mobile
              if (secondary.isNotEmpty) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSecondaryLayout(secondary, isDesktop),
                ),
              ],

              const SizedBox(height: 36),
            ],
          );
        },
      ),
    ];
  }

  /// Lays out the yield / price / waste sections. On desktop, puts them
  /// side-by-side when there's more than one; otherwise stacks them.
  Widget _buildSecondaryLayout(
    List<Widget> sections,
    bool isDesktop,
  ) {
    if (isDesktop && sections.length >= 2) {
      final rowChildren = <Widget>[];
      for (var i = 0; i < sections.length; i++) {
        if (i > 0) rowChildren.add(const SizedBox(width: 16));
        rowChildren.add(Expanded(child: sections[i]));
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rowChildren,
        ),
      );
    }

    final columnChildren = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      if (i > 0) columnChildren.add(const SizedBox(height: 18));
      columnChildren.add(sections[i]);
    }
    return Column(children: columnChildren);
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? CropStyle.heroGradient.colors
              : [const Color(0xFF8E0000), _lossRed],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grass_outlined,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      positive ? 'Net profit from crops' : 'Net loss',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.eco_outlined,
                  size: 20, color: Colors.white.withValues(alpha: 0.85)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${positive ? '' : '−'}${formatKsh(profit.abs())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 16),
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
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

// ===========================================================================
// Ranked crops — tappable
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
            Divider(height: 20, color: Colors.black.withValues(alpha: 0.05)),
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/reports/crop/${Uri.encodeComponent(c.cropName)}/detail',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            c.dominantUnit.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                      fontWeight: FontWeight.w800,
                      color: profitColor,
                      letterSpacing: -0.2,
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
                Icons.chevron_right_rounded,
                size: 20,
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

    final maxNet =
        withYield.map((c) => c.netYield).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < withYield.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (c.wasted > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: wasteColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(c.wasteRatio * 100).toStringAsFixed(0)}% waste',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w800,
                color: CropStyle.primaryDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fill.clamp(0.0, 1.0),
            minHeight: 6,
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
    final withPrice = crops
        .where((c) => c.saleCount > 0 && c.averagePricePerUnit > 0)
        .toList()
      ..sort(
          (a, b) => b.averagePricePerUnit.compareTo(a.averagePricePerUnit));
    if (withPrice.isEmpty) return const SizedBox.shrink();

    final maxPrice = withPrice
        .map((c) => c.averagePricePerUnit)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < withPrice.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${formatKsh(c.averagePricePerUnit)} / ${c.dominantUnit}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E88E5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fill.clamp(0.0, 1.0),
            minHeight: 6,
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
    final withWaste = crops.where((c) => c.wasted > 0).toList()
      ..sort((a, b) => b.wasteRatio.compareTo(a.wasteRatio));
    if (withWaste.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < withWaste.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              formatQuantity(c.wasted, c.dominantUnit),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(c.wasteRatio * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: c.wasteRatio.clamp(0.0, 1.0),
            minHeight: 6,
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