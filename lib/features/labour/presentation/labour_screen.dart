import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/expense_format.dart';
import '../data/labour_model.dart';
import '../data/labour_style.dart';
import '../providers/labour_provider.dart';

class LabourScreen extends ConsumerStatefulWidget {
  const LabourScreen({super.key});

  @override
  ConsumerState<LabourScreen> createState() => _LabourScreenState();
}

class _LabourScreenState extends ConsumerState<LabourScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchCtrl.clear();
      ref.read(labourSearchProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);

    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Labour')),
        body: const Center(
          child: Text('Select a farm first from the Farms tab.'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) return _buildDesktopLayout(context, farmId);
        return _buildMobileLayout(context, farmId);
      },
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT (unchanged)
  // ===========================================================================
  Widget _buildMobileLayout(BuildContext context, String farmId) {
    final labourAsync = ref.watch(labourStreamProvider);
    final summary = ref.watch(labourSummaryProvider);
    final filter = ref.watch(labourFilterProvider);
    final filtered = ref.watch(filteredLabourProvider);
    final counts = ref.watch(labourCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search worker, task, location…',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(labourSearchProvider.notifier).state = v,
              )
            : const Text('Labour'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Labour report',
            onPressed: () => context.push('/reports/labour'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add record',
            onPressed: () => context.push('/labour/add'),
          ),
        ],
      ),
      body: labourAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _SummaryCard(summary: summary),
              if (summary.hasPending) ...[
                const SizedBox(height: 12),
                _PendingBanner(
                  amount: summary.pendingAmount,
                  count: summary.pendingRecords,
                  onTap: () =>
                      ref.read(labourFilterProvider.notifier).state = 'pending',
                ),
              ],
              const SizedBox(height: 16),
              _FilterRow(
                current: filter,
                counts: counts,
                onChange: (v) =>
                    ref.read(labourFilterProvider.notifier).state = v,
              ),
              const SizedBox(height: 4),
              ..._groupedList(filtered, farmId),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/labour/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Worker Record'),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(BuildContext context, String farmId) {
    final labourAsync = ref.watch(labourStreamProvider);
    final summary = ref.watch(labourSummaryProvider);
    final filter = ref.watch(labourFilterProvider);
    final filtered = ref.watch(filteredLabourProvider);
    final counts = ref.watch(labourCountsProvider);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: labourAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDesktopHeader(context),
                      const SizedBox(height: 64),
                      const SizedBox(height: 420, child: _EmptyState()),
                    ],
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopHeader(context),
                    const SizedBox(height: 24),
                    _SummaryCard(summary: summary, isDesktop: true),
                    if (summary.hasPending) ...[
                      const SizedBox(height: 16),
                      _PendingBanner(
                        amount: summary.pendingAmount,
                        count: summary.pendingRecords,
                        onTap: () => ref
                            .read(labourFilterProvider.notifier)
                            .state = 'pending',
                      ),
                    ],
                    const SizedBox(height: 24),
                    _FilterRow(
                      current: filter,
                      counts: counts,
                      isDesktop: true,
                      onChange: (v) => ref
                          .read(labourFilterProvider.notifier)
                          .state = v,
                    ),
                    const SizedBox(height: 20),
                    ..._groupedList(
                      filtered,
                      farmId,
                      isDesktop: true,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Labour',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track worker wages, tasks and payments.',
                style: TextStyle(fontSize: 14, color: DPalette.inkMuted),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, minWidth: 220),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search labour...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: DPalette.inkMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: DPalette.inkMuted,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              filled: true,
              fillColor: DPalette.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DPalette.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DPalette.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: DPalette.brand,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (v) =>
                ref.read(labourSearchProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(
            Icons.insights_outlined,
            color: DPalette.inkMuted,
          ),
          tooltip: 'Labour report',
          onPressed: () => context.push('/reports/labour'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/labour/add'),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Add Record',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: DPalette.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Grouped list (adaptive)
  // -------------------------------------------------------------------------
  List<Widget> _groupedList(
    List<Labour> records,
    String farmId, {
    bool isDesktop = false,
  }) {
    if (records.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              'No records match your filters.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
      ];
    }

    final sorted = [...records]..sort((a, b) =>
        (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));

    final groups = <DateTime, List<Labour>>{};
    for (final l in sorted) {
      final d = l.date ?? DateTime.now();
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(l);
    }

    final widgets = <Widget>[];
    groups.forEach((day, items) {
      final dayCost = items.fold<double>(0, (s, l) => s + l.totalAmount);
      final dayPending =
          items.fold<double>(0, (s, l) => s + l.pendingAmount);

      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            top: isDesktop ? 20 : 16,
            bottom: 10,
          ),
          child: Row(
            children: [
              Text(
                dayLabel(day),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dayPending > 0
                    ? '${formatKsh(dayPending)} pending'
                    : formatKsh(dayCost),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dayPending > 0
                      ? LabourStyle.partial
                      : LabourStyle.paid.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      );

      if (isDesktop) {
        widgets.addAll(
          items.map((l) => _DesktopLabourTile(record: l, farmId: farmId)),
        );
      } else {
        widgets.addAll(
          items.map((l) => _LabourTile(record: l, farmId: farmId)),
        );
      }
    });

    return widgets;
  }
}

// ===========================================================================
// Summary hero (adaptive)
// ===========================================================================
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, this.isDesktop = false});
  final LabourSummary summary;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final change = summary.monthChangePct;
    final up = (change ?? 0) >= 0;

    final padding = isDesktop
        ? const EdgeInsets.all(28)
        : const EdgeInsets.all(20);
    final headlineSize = isDesktop ? 48.0 : 34.0;
    final statLabelSize = isDesktop ? 11.5 : 11.0;
    final statValueSize = isDesktop ? 18.0 : 13.5;
    final dividerHeight = isDesktop ? 42.0 : 28.0;
    final radius = isDesktop ? 24.0 : 20.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LabourStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: LabourStyle.primary.withValues(alpha: 0.28),
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
                'Total labour cost',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.groups_outlined,
                size: isDesktop ? 22 : 18,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 8 : 6),
          Text(
            formatKsh(summary.totalCost),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: headlineSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (change != null) ...[
            SizedBox(height: isDesktop ? 16 : 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    up ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: up
                        ? const Color(0xFFFFCC80)
                        : const Color(0xFFA5D6A7),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${up ? '+' : ''}${change.toStringAsFixed(1)}% vs last month',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isDesktop ? 22 : 18),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          SizedBox(height: isDesktop ? 18 : 14),
          Row(
            children: [
              _stat('Paid', formatShortKsh(summary.paidAmount), statLabelSize,
                  statValueSize),
              _divider(dividerHeight),
              _stat('Pending', formatShortKsh(summary.pendingAmount),
                  statLabelSize, statValueSize),
              _divider(dividerHeight),
              _stat('Workers', '${summary.workerCount}', statLabelSize,
                  statValueSize),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    String value,
    double labelSize,
    double valueSize,
  ) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _divider(double height) => Container(
        width: 1,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

// ===========================================================================
// Pending banner (unchanged)
// ===========================================================================
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.amount,
    required this.count,
    required this.onTap,
  });

  final double amount;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: LabourStyle.partial.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: LabourStyle.partial.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: LabourStyle.partial.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.hourglass_bottom,
                    size: 17, color: LabourStyle.partial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatKsh(amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB26A00),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$count ${count == 1 ? 'worker' : 'workers'} awaiting payment',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: LabourStyle.partial.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Filter chips (adaptive)
// ===========================================================================
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.counts,
    required this.onChange,
    this.isDesktop = false,
  });

  final String current;
  final ({int all, int paid, int pending}) counts;
  final ValueChanged<String> onChange;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('All', 'all', counts.all, LabourStyle.primary),
      _chip('Paid', 'paid', counts.paid, LabourStyle.paid),
      _chip('Pending', 'pending', counts.pending, LabourStyle.partial),
    ];

    if (isDesktop) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(String label, String value, int count, Color color) {
    final selected = current == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0 : 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : color,
                  ),
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
// MOBILE labour tile (unchanged — swipe to delete)
// ===========================================================================
class _LabourTile extends ConsumerWidget {
  const _LabourTile({required this.record, required this.farmId});

  final Labour record;
  final String farmId;

  String get _initial {
    final w = record.workerName.trim();
    if (w.isEmpty) return '?';
    return w.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = LabourStyle.state(
      total: record.totalAmount,
      paid: record.amountPaid,
    );
    final color = LabourStyle.colorFor(state);
    final radius = BorderRadius.circular(14);

    final progress = record.totalAmount <= 0
        ? 1.0
        : (record.amountPaid / record.totalAmount).clamp(0.0, 1.0);

    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete record?'),
          content: Text(
            '"${record.workerName.isEmpty ? 'Record' : record.workerName}" will be removed permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(labourRepositoryProvider).deleteLabour(farmId, record.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: radius,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: radius,
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: () => context.push('/labour/${record.id}'),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _initial,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.workerName.isEmpty
                                  ? '(no name)'
                                  : record.workerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                record.task,
                                if ((record.location ?? '').isNotEmpty)
                                  record.location!,
                              ].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
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
                            formatKsh(record.totalAmount),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: state == 'paid'
                                  ? LabourStyle.primaryDeep
                                  : color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              LabourStyle.labelFor(state).toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor:
                                color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        state == 'paid'
                            ? '${formatQuantity(record.daysWorked, 'day${record.daysWorked == 1 ? '' : 's'}')}'
                            : '${formatKsh(record.amountPaid)} / ${formatKsh(record.totalAmount)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DESKTOP labour tile (popup menu instead of swipe)
// ===========================================================================
class _DesktopLabourTile extends ConsumerWidget {
  const _DesktopLabourTile({required this.record, required this.farmId});

  final Labour record;
  final String farmId;

  String get _initial {
    final w = record.workerName.trim();
    if (w.isEmpty) return '?';
    return w.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = LabourStyle.state(
      total: record.totalAmount,
      paid: record.amountPaid,
    );
    final color = LabourStyle.colorFor(state);
    final radius = BorderRadius.circular(14);

    final progress = record.totalAmount <= 0
        ? 1.0
        : (record.amountPaid / record.totalAmount).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: radius,
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/labour/${record.id}'),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _initial,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.workerName.isEmpty
                                ? '(no name)'
                                : record.workerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: DPalette.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              record.task,
                              if ((record.location ?? '').isNotEmpty)
                                record.location!,
                            ].join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: DPalette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatKsh(record.totalAmount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: state == 'paid'
                                ? LabourStyle.primaryDeep
                                : color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            LabourStyle.labelFor(state).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: DPalette.inkMuted,
                        size: 20,
                      ),
                      tooltip: 'More options',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'open') {
                          context.push('/labour/${record.id}');
                        }
                        if (value == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new, size: 16),
                              SizedBox(width: 8),
                              Text('Open'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: color.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      state == 'paid'
                          ? '${formatQuantity(record.daysWorked, 'day${record.daysWorked == 1 ? '' : 's'}')}'
                          : '${formatKsh(record.amountPaid)} / ${formatKsh(record.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: DPalette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          '"${record.workerName.isEmpty ? 'Record' : record.workerName}" will be removed permanently.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(labourRepositoryProvider).deleteLabour(farmId, record.id);
  }
}

// ===========================================================================
// Empty state
// ===========================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: LabourStyle.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_outlined,
                  size: 32, color: LabourStyle.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No labour records yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track worker wages, tasks and payments in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}