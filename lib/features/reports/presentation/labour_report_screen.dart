import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/expense_format.dart';
import '../../labour/data/labour_model.dart';
import '../../labour/data/labour_style.dart';
import '../data/report_models.dart';
import '../providers/report_providers.dart';
import '../widgets/report_widgets.dart';

class LabourReportScreen extends ConsumerWidget {
  const LabourReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(labourReportRangeProvider);
    final kpis = ref.watch(labourKpisProvider);
    final delta = ref.watch(labourDeltaProvider);
    final byWorker = ref.watch(labourByWorkerProvider);
    final byTask = ref.watch(labourByTaskProvider);
    final trend = ref.watch(labourMonthlyTrendProvider);
    final top = ref.watch(topLabourProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Labour Report'),
        actions: [
          if (!kpis.isEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Copy summary',
              onPressed: () => _copySummary(
                  context, range, kpis, delta, byWorker, byTask),
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
                ref.read(labourReportRangeProvider.notifier).state = r,
            onCustomTap: () => _pickCustom(context, ref, range),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ReportRangeInfo(
              range: range,
              trailing: kpis.isEmpty ? null : formatShortKsh(kpis.totalCost),
            ),
          ),
          if (kpis.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: ReportEmptyState(
                icon: Icons.groups_outlined,
                title: 'No labour in this period',
                message:
                    'Try a wider range, or record some worker wages first.',
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
                title: 'Cost by worker',
                subtitle: byWorker.length > 5
                    ? 'Top 5 of ${byWorker.length}'
                    : '${byWorker.length} ${byWorker.length == 1 ? 'worker' : 'workers'}',
                child: _breakdown(
                  byWorker.take(5).toList(),
                  Icons.person_outline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Cost by task',
                subtitle: '${byTask.length} ${byTask.length == 1 ? 'task' : 'tasks'}',
                child: _breakdown(byTask.take(6).toList(), Icons.task_alt_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Monthly labour cost',
                subtitle: _trendSubtitle(trend),
                child: TrendBars(
                  points: trend,
                  barColor: LabourStyle.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportSection(
                title: 'Biggest wage records',
                subtitle: 'Top ${top.length} of ${kpis.totalRecords}',
                child: _topList(top),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  List<KpiData> _kpiItems(LabourKpis k, PeriodDelta d) {
    final pct = d.pct;
    return [
      KpiData(
        icon: Icons.payments_outlined,
        label: 'Total cost',
        value: formatKsh(k.totalCost),
        delta: pct == null
            ? null
            : '${d.isUp ? '+' : ''}${pct.toStringAsFixed(1)}% vs prev',
        deltaIsUp: pct == null ? null : d.isUp,
        deltaIsPositive: pct == null ? null : !d.isUp, // up = bad for cost
        color: LabourStyle.primary,
      ),
      KpiData(
        icon: Icons.check_circle_outline,
        label: 'Paid',
        value: formatKsh(k.paid),
        color: LabourStyle.paid,
      ),
      KpiData(
        icon: Icons.hourglass_bottom,
        label: 'Pending',
        value: formatKsh(k.pending),
        color: LabourStyle.partial,
      ),
      KpiData(
        icon: Icons.people_outline,
        label: 'Workers',
        value: '${k.workerCount}',
        color: const Color(0xFF1E88E5),
      ),
    ];
  }

  Widget _secondaryRow(LabourKpis k) {
    return Row(
      children: [
        Expanded(
          child: _stat(
            'Total days',
            formatQuantity(k.totalDays, k.totalDays == 1 ? 'day' : 'days'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat('Avg / day', formatKsh(k.averageDailyRate)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stat('Avg / record', formatKsh(k.averagePerRecord)),
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
      positiveWhenUp: false, // up = bad (labour cost)
    );
  }

  Widget _breakdown(List<BreakdownRow> rows, IconData icon) {
    final colorMap = <String, Color>{};
    for (var i = 0; i < rows.length; i++) {
      colorMap[rows[i].key] = LabourStyle.paletteAt(i);
    }
    return BreakdownTable(
      rows: rows,
      colorFor: (k) => colorMap[k] ?? LabourStyle.paletteAt(0),
      iconFor: (_) => icon,
    );
  }

  String _trendSubtitle(List<TrendPoint> points) {
    if (points.isEmpty) return '';
    final total = points.fold<double>(0, (s, p) => s + p.value);
    final avg = total / points.length;
    return 'Avg ${formatKsh(avg)} / month';
  }

  Widget _topList(List<Labour> records) {
    return Column(
      children: [
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0)
            Divider(height: 18, color: Colors.black.withValues(alpha: 0.05)),
          _topRow(records[i], i + 1),
        ],
      ],
    );
  }

  Widget _topRow(Labour l, int rank) {
    final color = LabourStyle.paletteAt(rank - 1);
    final dateStr = l.date != null ? dayLabel(l.date!) : '';
    final state = LabourStyle.state(
      total: l.totalAmount,
      paid: l.amountPaid,
    );
    final statusColor = LabourStyle.colorFor(state);

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
                l.workerName.isEmpty ? '(no name)' : l.workerName,
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
                  Text(
                    [
                      l.task,
                      if (dateStr.isNotEmpty) dateStr,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      LabourStyle.labelFor(state).toUpperCase(),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          formatKsh(l.totalAmount),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: LabourStyle.primaryDeep,
          ),
        ),
      ],
    );
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

    ref.read(labourReportRangeProvider.notifier).state = ReportRange(
      preset: ReportPreset.custom,
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }

  void _copySummary(
    BuildContext context,
    ReportRange range,
    LabourKpis k,
    PeriodDelta d,
    List<BreakdownRow> byWorker,
    List<BreakdownRow> byTask,
  ) {
    final b = StringBuffer()
      ..writeln('LABOUR REPORT')
      ..writeln('${fullDate(range.start)} — ${fullDate(range.end)}')
      ..writeln('=' * 34)
      ..writeln()
      ..writeln('Total cost:   ${formatKsh(k.totalCost)}')
      ..writeln('Paid:         ${formatKsh(k.paid)}')
      ..writeln('Pending:      ${formatKsh(k.pending)}')
      ..writeln('Workers:      ${k.workerCount}')
      ..writeln('Records:      ${k.totalRecords}')
      ..writeln('Total days:   ${k.totalDays.toStringAsFixed(1)}')
      ..writeln('Avg / day:    ${formatKsh(k.averageDailyRate)}');

    if (d.pct != null) {
      b.writeln(
        'Change:       ${d.isUp ? '+' : ''}${d.pct!.toStringAsFixed(1)}% '
        'vs previous period',
      );
    }

    b
      ..writeln()
      ..writeln('BY WORKER')
      ..writeln('-' * 34);
    for (final r in byWorker) {
      b.writeln(
        '${r.label.padRight(24)} ${formatKsh(r.total).padLeft(12)}  '
        '${(r.share * 100).toStringAsFixed(1)}%',
      );
    }

    if (byTask.isNotEmpty) {
      b
        ..writeln()
        ..writeln('BY TASK')
        ..writeln('-' * 34);
      for (final r in byTask) {
        b.writeln(
          '${r.label.padRight(24)} ${formatKsh(r.total).padLeft(12)}',
        );
      }
    }

    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Labour report copied to clipboard')),
    );
  }
}