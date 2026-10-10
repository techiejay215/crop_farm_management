import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/expense_format.dart';
import '../../harvests/data/harvest_model.dart';
import '../../harvests/data/harvest_style.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

const Color _netGreen = Color(0xFF2E7D32);
const Color _wasteRed = Color(0xFFC62828);

class HarvestReportScreen extends ConsumerWidget {
  const HarvestReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(harvestReportRangeProvider);
    final kpis = ref.watch(harvestKpisProvider);
    final delta = ref.watch(harvestDeltaProvider);
    final byCrop = ref.watch(harvestByCropProvider);
    final byGrade = ref.watch(harvestByGradeProvider);
    final cropUnits = ref.watch(harvestCropUnitsProvider);
    final trend = ref.watch(harvestTrendProvider);
    final top = ref.watch(topHarvestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harvest Report'),
        actions: [
          if (!kpis.isEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Copy summary',
              onPressed: () =>
                  _copySummary(context, range, kpis, delta, byCrop, byGrade),
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
                ref.read(harvestReportRangeProvider.notifier).state = r,
            onCustomTap: () => _pickCustom(context, ref, range),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ReportRangeInfo(
              range: range,
              trailing: kpis.isEmpty
                  ? null
                  : formatQuantity(kpis.netYield, kpis.dominantUnit),
            ),
          ),
          if (kpis.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: ReportEmptyState(
                icon: Icons.agriculture,
                title: 'No harvests in this period',
                message:
                    'Try a wider range, or record some harvests to see trends.',
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
            if (kpis.hasWaste) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WasteBanner(kpis: kpis),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _comparisonSection(range, delta, kpis.dominantUnit),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Yield by crop',
                subtitle: _cropSubtitle(byCrop.length),
                child: _cropBreakdown(byCrop, cropUnits),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Grade distribution',
                subtitle: _gradeSubtitle(byGrade),
                child: _GradeDistribution(rows: byGrade),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Net yield vs waste',
                subtitle: 'Monthly · ${kpis.dominantUnit}',
                child: DualTrendBars(
                  points: trend,
                  positiveColor: _netGreen,
                  negativeColor: _wasteRed,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Biggest harvests',
                subtitle: 'Top ${top.length} of ${kpis.count}',
                child: _TopHarvests(harvests: top),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // KPIs
  // -------------------------------------------------------------------------
  List<KpiData> _kpiItems(HarvestKpis k, PeriodDelta delta) {
    final pct = delta.pct;
    return [
      KpiData(
        icon: Icons.agriculture,
        label: 'Net yield',
        value: formatQuantity(k.netYield, k.dominantUnit),
        delta: pct == null
            ? null
            : '${delta.isUp ? '+' : ''}${pct.toStringAsFixed(1)}% vs prev',
        deltaIsUp: pct == null ? null : delta.isUp,
        deltaIsPositive: pct == null ? null : delta.isUp, // more yield = good
        color: _netGreen,
      ),
      KpiData(
        icon: Icons.inventory_2_outlined,
        label: 'Gross yield',
        value: formatQuantity(k.grossYield, k.dominantUnit),
        color: HarvestStyle.primary,
      ),
      KpiData(
        icon: Icons.delete_sweep_outlined,
        label: 'Wasted',
        value: k.hasWaste
            ? formatQuantity(k.wasted, k.dominantUnit)
            : '—',
        color: _wasteRed,
      ),
      KpiData(
        icon: Icons.event_available_outlined,
        label: 'Harvests',
        value: '${k.count}',
        color: const Color(0xFF1E88E5),
      ),
    ];
  }

  Widget _secondaryRow(HarvestKpis k) {
    return Row(
      children: [
        Expanded(
          child: _stat('Active days', '${k.activeDays}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat(
            'Avg net',
            formatQuantity(k.averageNet, k.dominantUnit),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat(
            'Waste ratio',
            k.hasWaste ? '${(k.wasteRatio * 100).toStringAsFixed(1)}%' : '0%',
            valueColor: k.hasWaste
                ? HarvestStyle.wasteColor(k.wasteRatio)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, {Color? valueColor}) {
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
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.black87,
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
  Widget _comparisonSection(
    ReportRange range,
    PeriodDelta d,
    String unit,
  ) {
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
      currentLabel: formatQuantity(d.current, unit),
      previousLabel:
          'Previous: ${formatQuantity(d.previous, unit)}',
      delta: d,
      positiveWhenUp: true, // more yield = good
    );
  }

  // -------------------------------------------------------------------------
  // Breakdowns
  // -------------------------------------------------------------------------
  Widget _cropBreakdown(
    List<BreakdownRow> rows,
    Map<String, String> cropUnits,
  ) {
    // Palette by rank position.
    final colorMap = <String, Color>{};
    for (var i = 0; i < rows.length; i++) {
      colorMap[rows[i].key] = HarvestStyle.primary;
    }
    // Use a subtle variation so multiple crops aren't identical.
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(height: 20, color: Colors.black.withValues(alpha: 0.05)),
          _cropRow(rows[i], cropUnits[rows[i].key] ?? 'kg', i),
        ],
      ],
    );
  }

  Widget _cropRow(BreakdownRow row, String unit, int index) {
    final color = HarvestStyle.primary.withValues(
      alpha: (1.0 - index * 0.08).clamp(0.55, 1.0),
    );
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
              child: Icon(Icons.grass, size: 16, color: color),
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
                    '${row.count} ${row.count == 1 ? 'harvest' : 'harvests'}',
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
                  formatQuantity(row.total, unit),
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

  // -------------------------------------------------------------------------
  // Copy
  // -------------------------------------------------------------------------
  String _cropSubtitle(int count) =>
      '$count ${count == 1 ? 'crop' : 'crops'}';

  String _gradeSubtitle(List<BreakdownRow> rows) {
    if (rows.isEmpty) return '';
    final total = rows.fold<int>(0, (s, r) => s + r.count);
    return '$total graded';
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

    ref.read(harvestReportRangeProvider.notifier).state = ReportRange(
      preset: ReportPreset.custom,
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }

  void _copySummary(
    BuildContext context,
    ReportRange range,
    HarvestKpis k,
    PeriodDelta d,
    List<BreakdownRow> byCrop,
    List<BreakdownRow> byGrade,
  ) {
    final b = StringBuffer()
      ..writeln('HARVEST REPORT')
      ..writeln('${fullDate(range.start)} — ${fullDate(range.end)}')
      ..writeln('=' * 34)
      ..writeln()
      ..writeln('Net yield:   ${formatQuantity(k.netYield, k.dominantUnit)}')
      ..writeln('Gross yield: ${formatQuantity(k.grossYield, k.dominantUnit)}')
      ..writeln('Wasted:      ${formatQuantity(k.wasted, k.dominantUnit)} '
          '(${(k.wasteRatio * 100).toStringAsFixed(1)}%)')
      ..writeln('Harvests:    ${k.count}')
      ..writeln('Active days: ${k.activeDays}');

    if (d.pct != null) {
      b.writeln(
        'Change:      ${d.isUp ? '+' : ''}${d.pct!.toStringAsFixed(1)}% '
        'vs previous period',
      );
    }

    if (byCrop.isNotEmpty) {
      b
        ..writeln()
        ..writeln('BY CROP')
        ..writeln('-' * 34);
      for (final r in byCrop) {
        final unit = k.dominantUnit;
        b.writeln(
          '${r.label.padRight(20)} '
          '${formatQuantity(r.total, unit).padLeft(14)}  '
          '${(r.share * 100).toStringAsFixed(1)}%',
        );
      }
    }

    if (byGrade.isNotEmpty) {
      b
        ..writeln()
        ..writeln('BY GRADE')
        ..writeln('-' * 34);
      for (final r in byGrade) {
        b.writeln(
          '${r.label.padRight(20)} '
          '${formatQuantity(r.total, k.dominantUnit).padLeft(14)}  '
          '${(r.share * 100).toStringAsFixed(1)}%',
        );
      }
    }

    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Harvest report copied to clipboard')),
    );
  }
}

// ===========================================================================
// Waste banner — only shown when there's actual wastage
// ===========================================================================
class _WasteBanner extends StatelessWidget {
  const _WasteBanner({required this.kpis});
  final HarvestKpis kpis;

  @override
  Widget build(BuildContext context) {
    final color = HarvestStyle.wasteColor(kpis.wasteRatio);
    final label = HarvestStyle.wasteLabel(kpis.wasteRatio);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              kpis.wasteRatio > 0.10
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label wastage · ${(kpis.wasteRatio * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${formatQuantity(kpis.wasted, kpis.dominantUnit)} lost out '
                  'of ${formatQuantity(kpis.grossYield, kpis.dominantUnit)} harvested',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Grade distribution — stacked horizontal bar + legend
// ===========================================================================
class _GradeDistribution extends StatelessWidget {
  const _GradeDistribution({required this.rows});
  final List<BreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 16,
            child: Row(
              children: rows.map((r) {
                final flex = (r.share * 1000).round().clamp(1, 1000);
                final color = HarvestStyle.gradeColor(r.key);
                return Expanded(
                  flex: flex,
                  child: Container(color: color),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _legendRow(rows[i]),
            ],
          ],
        ),
      ],
    );
  }

  Widget _legendRow(BreakdownRow r) {
    final color = HarvestStyle.gradeColor(r.key);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${r.count} ${r.count == 1 ? 'harvest' : 'harvests'}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${(r.share * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Top harvests list
// ===========================================================================
class _TopHarvests extends StatelessWidget {
  const _TopHarvests({required this.harvests});
  final List<Harvest> harvests;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < harvests.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _row(harvests[i], i + 1),
        ],
      ],
    );
  }

  Widget _row(Harvest h, int rank) {
    final gradeColor = HarvestStyle.gradeColor(h.grade);
    final dateStr = h.harvestDate != null ? dayLabel(h.harvestDate!) : '';
    final net = (h.quantity - h.wastedQuantity.clamp(0.0, h.quantity))
        .clamp(0, double.infinity)
        .toDouble();

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gradeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: gradeColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                h.cropName.isEmpty ? '(unnamed crop)' : h.cropName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GRADE ${h.grade.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: gradeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (h.location.isNotEmpty) h.location,
                        if (dateStr.isNotEmpty) dateStr,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatQuantity(net, h.unit),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: HarvestStyle.primaryDeep,
          ),
        ),
      ],
    );
  }
}