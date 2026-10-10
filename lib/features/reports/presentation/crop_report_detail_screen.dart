import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/data/crop_activity_model.dart';
import '../../crops/data/crop_style.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_format.dart';
import '../data/crop_report_detail_models.dart';
import '../data/report_models.dart';
import '../providers/crop_report_detail_provider.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

const Color _profitGreen = Color(0xFF2E7D32);
const Color _lossRed = Color(0xFFC62828);
const Color _incomeBlue = Color(0xFF1E88E5);
const Color _expenseOrange = Color(0xFFEF6C00);

class CropReportDetailScreen extends ConsumerWidget {
  final String cropName;
  const CropReportDetailScreen({super.key, required this.cropName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(cropReportRangeProvider);
    final detailAsync = ref.watch(cropReportDetailProvider(cropName));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(cropName.isEmpty ? 'Crop Report' : cropName),
        actions: [
          detailAsync.maybeWhen(
            data: (d) => d.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Copy summary',
                    onPressed: () => _copySummary(context, range, d),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(cropReportDetailProvider(cropName)),
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
            detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e'),
              ),
              data: (d) {
                if (d.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: ReportEmptyState(
                      icon: Icons.grass_outlined,
                      title: 'No data for this crop',
                      message:
                          'Record crops, activities, harvests or sales for '
                          'this crop to see its report.',
                    ),
                  );
                }
                return Column(
                  children: [
                    const SizedBox(height: 16),

                    // ---- 1. Overview hero ----
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _Hero(detail: d),
                    ),

                    // ---- 2. Financial KPIs ----
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: KpiGrid(items: _kpiItems(d)),
                    ),

                    // ---- 3. Instances ----
                    if (d.instances.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Where it\'s grown',
                          subtitle:
                              '${d.instances.length} ${d.instances.length == 1 ? 'plot' : 'plots'} · '
                              '${d.totalPlants} plants · '
                              '${d.totalAcreage.toStringAsFixed(d.totalAcreage == d.totalAcreage.roundToDouble() ? 0 : 1)} ac',
                          child: _Instances(instances: d.instances),
                        ),
                      ),
                    ],

                    // ---- 4. Activities grouped by type ----
                    if (d.activities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Activities',
                          subtitle:
                              '${d.activities.length} recorded · grouped by type',
                          child: _ActivitiesGrouped(detail: d),
                        ),
                      ),
                    ],

                    // ---- 5. Expenses grouped by category ----
                    if (d.expenses.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Expenses',
                          subtitle:
                              '${d.expenses.length} entries · total ${formatKsh(d.totalExpenses)}',
                          child: _ExpensesGrouped(detail: d),
                        ),
                      ),
                    ],

                    // ---- 6. Income ----
                    if (d.income.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Income',
                          subtitle:
                              '${d.income.length} sales · total ${formatKsh(d.totalIncome)}'
                              '${d.totalPending > 0 ? ' (+${formatShortKsh(d.totalPending)} pending)' : ''}',
                          child: _IncomeList(rows: d.income),
                        ),
                      ),
                    ],

                    // ---- 7. Harvest / production ----
                    if (d.harvests.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReportSection(
                          title: 'Production',
                          subtitle:
                              '${d.harvests.length} harvests · net ${formatQuantity(d.netYield, d.dominantUnit)}',
                          child: _HarvestList(detail: d),
                        ),
                      ),
                    ],

                    // ---- 8. Profitability ----
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ReportSection(
                        title: 'Profitability',
                        subtitle: 'Income minus expenses',
                        child: _Profitability(detail: d),
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

  // -------------------------------------------------------------------------
  // KPI items
  // -------------------------------------------------------------------------
  List<KpiData> _kpiItems(CropReportDetail d) {
    final profit = d.netProfit;
    final positive = profit >= 0;
    return [
      KpiData(
        icon: Icons.payments_outlined,
        label: 'Income',
        value: formatShortKsh(d.totalIncome),
        color: _incomeBlue,
      ),
      KpiData(
        icon: Icons.trending_down,
        label: 'Expenses',
        value: formatShortKsh(d.totalExpenses),
        color: _expenseOrange,
      ),
      KpiData(
        icon: positive ? Icons.trending_up : Icons.trending_down,
        label: positive ? 'Net profit' : 'Net loss',
        value: formatShortKsh(profit.abs()),
        color: positive ? _profitGreen : _lossRed,
      ),
      KpiData(
        icon: Icons.scale_outlined,
        label: 'Net yield',
        value: formatQuantity(d.netYield, d.dominantUnit),
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
      initialDateRange:
          DateTimeRange(start: current.start, end: current.end),
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

  void _copySummary(
      BuildContext context, ReportRange range, CropReportDetail d) {
    final b = StringBuffer()
      ..writeln('CROP REPORT — ${d.cropName}')
      ..writeln('${fullDate(range.start)} — ${fullDate(range.end)}')
      ..writeln('=' * 34)
      ..writeln()
      ..writeln('Plots:        ${d.instances.length}')
      ..writeln('Total plants: ${d.totalPlants}')
      ..writeln('Acreage:      ${d.totalAcreage.toStringAsFixed(1)}')
      ..writeln()
      ..writeln('Income:       ${formatKsh(d.totalIncome)}')
      ..writeln('Expenses:     ${formatKsh(d.totalExpenses)}')
      ..writeln('${d.netProfit >= 0 ? 'Net profit' : 'Net loss  '}:  '
          ' ${formatKsh(d.netProfit.abs())}');

    if (d.margin != null) {
      b.writeln('Margin:       ${(d.margin! * 100).toStringAsFixed(1)}%');
    }
    b
      ..writeln()
      ..writeln('ACTIVITIES BY TYPE')
      ..writeln('-' * 34);

    for (final e in d.activitiesByType.entries) {
      b.writeln(
          '${ActivityTypes.label(e.key).padRight(20)} ${e.value.length}');
    }

    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crop report copied to clipboard')),
    );
  }
}

// ===========================================================================
// HERO
// ===========================================================================
class _Hero extends StatelessWidget {
  final CropReportDetail detail;
  const _Hero({required this.detail});

  @override
  Widget build(BuildContext context) {
    final profit = detail.netProfit;
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  detail.cropName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              if (detail.hasMixedUnits)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 11, color: Color(0xFFFFE082)),
                      SizedBox(width: 4),
                      Text(
                        'MIXED UNITS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFE082),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            positive ? 'Net profit' : 'Net loss',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${positive ? '' : '−'}${formatKsh(profit.abs())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Plots', '${detail.instances.length}'),
              _divider(),
              _stat('Plants', '${detail.totalPlants}'),
              _divider(),
              _stat(
                'Acreage',
                detail.totalAcreage == detail.totalAcreage.roundToDouble()
                    ? detail.totalAcreage.toStringAsFixed(0)
                    : detail.totalAcreage.toStringAsFixed(1),
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
        color: Colors.white.withValues(alpha: 0.18),
      );
}

// ===========================================================================
// INSTANCES
// ===========================================================================
class _Instances extends StatelessWidget {
  final List<CropInstance> instances;
  const _Instances({required this.instances});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < instances.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(instances[i]),
        ],
      ],
    );
  }

  Widget _row(CropInstance i) {
    final stageColor = CropStyle.stageColor(i.stage);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: stageColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(CropStyle.stageIcon(i.stage),
              size: 16, color: stageColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i.location.isEmpty ? 'No location' : i.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${i.farmName} · ${CropStyle.stageLabel(i.stage)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${i.plantCount} plants',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            if (i.acreage > 0)
              Text(
                '${i.acreage == i.acreage.roundToDouble() ? i.acreage.toStringAsFixed(0) : i.acreage.toStringAsFixed(1)} ac',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// ACTIVITIES — grouped by type
// ===========================================================================
class _ActivitiesGrouped extends StatelessWidget {
  final CropReportDetail detail;
  const _ActivitiesGrouped({required this.detail});

  @override
  Widget build(BuildContext context) {
    final grouped = detail.activitiesByType;

    // Order by count desc.
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _GroupSection(
            type: sorted[i].key,
            rows: sorted[i].value,
            totalCost: detail.costForType(sorted[i].key),
          ),
        ],
      ],
    );
  }
}

class _GroupSection extends StatefulWidget {
  final String type;
  final List<CropActivityRow> rows;
  final double totalCost;

  const _GroupSection({
    required this.type,
    required this.rows,
    required this.totalCost,
  });

  @override
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = ActivityTypes.color(widget.type);
    final icon = ActivityTypes.icon(widget.type);
    final label = ActivityTypes.label(widget.type);

    // Show up to 3 by default; expand to all.
    final visible =
        _expanded ? widget.rows : widget.rows.take(3).toList();
    final hasMore = widget.rows.length > 3;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Group header ----
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.rows.length} ${widget.rows.length == 1 ? 'entry' : 'entries'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.totalCost > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF6C00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      formatKsh(widget.totalCost),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF6C00),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: color.withValues(alpha: 0.12)),
          // ---- Rows ----
          for (var i = 0; i < visible.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: _ActivityLine(row: visible[i]),
            ),
            if (i < visible.length - 1)
              Divider(
                height: 1,
                color: color.withValues(alpha: 0.08),
                indent: 12,
                endIndent: 12,
              ),
          ],
          // ---- Show more / less ----
          if (hasMore)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded
                          ? 'Show less'
                          : 'Show ${widget.rows.length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityLine extends StatelessWidget {
  final CropActivityRow row;
  const _ActivityLine({required this.row});

  @override
  Widget build(BuildContext context) {
    final dateStr = row.date != null ? _shortDate(row.date!) : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.description.isEmpty
                    ? ActivityTypes.label(row.type)
                    : row.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 3,
                children: [
                  if (dateStr.isNotEmpty)
                    _miniText(Icons.calendar_today_outlined, dateStr),
                  if (row.location.isNotEmpty)
                    _miniText(Icons.place_outlined, row.location),
                  if (row.person != null && row.person!.isNotEmpty)
                    _miniText(Icons.person_outline, row.person!),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Right column: quantity + cost / income
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if ((row.quantity ?? 0) > 0)
              Text(
                '${_fmtNum(row.quantity!)} ${row.unit ?? ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E88E5),
                ),
              ),
            if ((row.cost ?? 0) > 0) ...[
              const SizedBox(height: 3),
              Text(
                formatKsh(row.cost!),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF6C00),
                ),
              ),
            ],
            if ((row.income ?? 0) > 0) ...[
              const SizedBox(height: 3),
              Text(
                formatKsh(row.income!),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _miniText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.black.withValues(alpha: 0.4)),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    final y = d.subtract(const Duration(days: 1));
    if (y.year == now.year && y.month == now.month && y.day == now.day) {
      return 'Yesterday';
    }
    return '${d.day}/${d.month}';
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// EXPENSES — grouped by category
// ===========================================================================
class _ExpensesGrouped extends StatelessWidget {
  final CropReportDetail detail;
  const _ExpensesGrouped({required this.detail});

  @override
  Widget build(BuildContext context) {
    final byCat = detail.expensesByCategory;
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = detail.totalExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category bars
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _CategoryBar(
            category: sorted[i].key,
            amount: sorted[i].value,
            share: total <= 0 ? 0 : sorted[i].value / total,
          ),
        ],
        const SizedBox(height: 16),
        Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
        const SizedBox(height: 12),
        // Total row
        Row(
          children: [
            const Text(
              'Total expenses',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              formatKsh(total),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _expenseOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String category;
  final double amount;
  final double share;

  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final label = ExpenseCategory.labelFor(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${formatKsh(amount)}  (${(share * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: _expenseOrange.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(_expenseOrange),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// INCOME
// ===========================================================================
class _IncomeList extends StatelessWidget {
  final List<CropIncomeRow> rows;
  const _IncomeList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(rows[i]),
        ],
      ],
    );
  }

  Widget _row(CropIncomeRow r) {
    final pending = r.status != 'completed';
    final dateStr = r.date != null ? _shortDate(r.date!) : '';

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (pending ? _expenseOrange : _incomeBlue)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            pending ? Icons.hourglass_bottom : Icons.check_circle_outline,
            size: 16,
            color: pending ? _expenseOrange : _incomeBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.buyer.isEmpty ? 'Unknown buyer' : r.buyer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_fmtNum(r.quantity)} ${r.unit} × ${formatKsh(r.pricePerUnit)}'
                '${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
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
              formatKsh(r.total),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: pending ? _expenseOrange : _incomeBlue,
              ),
            ),
            const SizedBox(height: 2),
            if (pending)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _expenseOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: _expenseOrange,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _shortDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    return '${d.day}/${d.month}';
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// HARVEST / PRODUCTION
// ===========================================================================
class _HarvestList extends StatelessWidget {
  final CropReportDetail detail;
  const _HarvestList({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < detail.harvests.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(detail.harvests[i], detail.dominantUnit),
        ],
        const SizedBox(height: 14),
        Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
        const SizedBox(height: 12),
        _summaryRow('Gross', detail.grossYield, detail.dominantUnit,
            const Color(0xFF546E7A)),
        const SizedBox(height: 6),
        _summaryRow('Wasted', detail.wasted, detail.dominantUnit,
            const Color(0xFFC62828)),
        const SizedBox(height: 6),
        _summaryRow('Net', detail.netYield, detail.dominantUnit,
            _profitGreen, bold: true),
      ],
    );
  }

  Widget _row(CropHarvestRow r, String unit) {
    final dateStr = r.date != null ? _shortDate(r.date!) : '';
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.agriculture_outlined,
              size: 16, color: Color(0xFF6A1B9A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade ${r.grade}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${r.farmName}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatQuantity(r.quantity, r.unit),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (r.wasted > 0) ...[
              const SizedBox(height: 2),
              Text(
                '−${_fmtNum(r.wasted)} ${r.unit}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC62828),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    double value,
    String unit,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13.5 : 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Text(
          formatQuantity(value, unit),
          style: TextStyle(
            fontSize: bold ? 14 : 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    return '${d.day}/${d.month}';
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// PROFITABILITY
// ===========================================================================
class _Profitability extends StatelessWidget {
  final CropReportDetail detail;
  const _Profitability({required this.detail});

  @override
  Widget build(BuildContext context) {
    final profit = detail.netProfit;
    final positive = profit >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (positive ? _profitGreen : _lossRed).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (positive ? _profitGreen : _lossRed)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _row('Total income', detail.totalIncome, _incomeBlue),
          const SizedBox(height: 8),
          _row('Total expenses', detail.totalExpenses, _expenseOrange),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 10),
          _row(
            positive ? 'Net profit' : 'Net loss',
            profit.abs(),
            positive ? _profitGreen : _lossRed,
            bold: true,
          ),
          if (detail.margin != null) ...[
            const SizedBox(height: 6),
            _row(
              'Profit margin',
              detail.margin! * 100,
              positive ? _profitGreen : _lossRed,
              isPercent: true,
            ),
          ],
          if (detail.costPerUnit != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
            const SizedBox(height: 12),
            _row2(
              'Cost per ${detail.dominantUnit}',
              formatKsh(detail.costPerUnit!),
              _expenseOrange,
            ),
            const SizedBox(height: 6),
            _row2(
              'Revenue per ${detail.dominantUnit}',
              formatKsh(detail.revenuePerUnit ?? 0),
              _incomeBlue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, double value, Color color,
      {bool bold = false, bool isPercent = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.75),
          ),
        ),
        const Spacer(),
        Text(
          isPercent
              ? '${value.toStringAsFixed(1)}%'
              : formatKsh(value),
          style: TextStyle(
            fontSize: bold ? 16 : 13.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _row2(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}