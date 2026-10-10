import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/expense_format.dart';
import '../data/harvest_model.dart';
import '../data/harvest_style.dart';
import '../providers/harvest_provider.dart';

class HarvestsScreen extends ConsumerStatefulWidget {
  const HarvestsScreen({super.key});

  @override
  ConsumerState<HarvestsScreen> createState() => _HarvestsScreenState();
}

class _HarvestsScreenState extends ConsumerState<HarvestsScreen> {
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
      ref.read(harvestSearchProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);

    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Harvests')),
        body: const Center(
          child: Text('Select a farm first from the Farms tab.'),
        ),
      );
    }

    final harvestsAsync = ref.watch(harvestsStreamProvider);
    final summary = ref.watch(harvestSummaryProvider);
    final timeFilter = ref.watch(harvestFilterProvider);
    final gradeFilter = ref.watch(harvestGradeFilterProvider);
    final filtered = ref.watch(filteredHarvestsProvider);
    final counts = ref.watch(harvestTimeCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search crop, location, notes…',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(harvestSearchProvider.notifier).state = v,
              )
            : const Text('Harvests'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Harvest report',
            onPressed: () => context.push('/reports/harvest'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add harvest',
            onPressed: () => context.push('/harvests/add'),
          ),
        ],
      ),
      body: harvestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 16),
              _TimeFilterRow(
                current: timeFilter,
                counts: counts,
                onChange: (v) =>
                    ref.read(harvestFilterProvider.notifier).state = v,
              ),
              const SizedBox(height: 8),
              _GradeFilterRow(
                current: gradeFilter,
                onChange: (v) => ref
                    .read(harvestGradeFilterProvider.notifier)
                    .state = v,
              ),
              const SizedBox(height: 4),
              ..._groupedList(filtered, farmId),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/harvests/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record Harvest'),
      ),
    );
  }

  List<Widget> _groupedList(List<Harvest> records, String farmId) {
    if (records.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              'No harvests match your filters.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
      ];
    }

    final sorted = [...records]..sort((a, b) => (b.harvestDate ?? DateTime(2000))
        .compareTo(a.harvestDate ?? DateTime(2000)));

    final groups = <DateTime, List<Harvest>>{};
    for (final h in sorted) {
      final d = h.harvestDate ?? DateTime.now();
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(h);
    }

    final widgets = <Widget>[];
    groups.forEach((day, items) {
      // Net of dominant unit in this day.
      final unit = items.first.unit;
      final sameUnit = items.where((h) => h.unit == unit).toList();
      final dayNet = sameUnit.fold<double>(
        0,
        (s, h) => s +
            (h.quantity - h.wastedQuantity)
                .clamp(0, double.infinity)
                .toDouble(),
      );

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
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
                formatQuantity(dayNet, unit),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HarvestStyle.primaryDeep,
                ),
              ),
            ],
          ),
        ),
      );

      widgets.addAll(
        items.map((h) => _HarvestTile(harvest: h, farmId: farmId)),
      );
    });

    return widgets;
  }
}

// ===========================================================================
// Summary hero
// ===========================================================================
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final HarvestSummary summary;

  @override
  Widget build(BuildContext context) {
    final wasteRatio = summary.wasteRatio;
    final wasteColor = HarvestStyle.wasteColor(wasteRatio);
    final wasteLabel = HarvestStyle.wasteLabel(wasteRatio);
    final hasWaste = summary.hasWaste;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: HarvestStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: HarvestStyle.primary.withValues(alpha: 0.28),
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
                'Net yield${summary.hasMixedUnits ? ' (${summary.dominantUnit})' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(),
              Icon(Icons.agriculture,
                  size: 18, color: Colors.white.withValues(alpha: 0.78)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatQuantity(summary.netYield, summary.dominantUnit),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (hasWaste) ...[
            const SizedBox(height: 12),
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
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: wasteColor == HarvestStyle.wasteHigh
                        ? const Color(0xFFFFCDD2)
                        : const Color(0xFFFFE082),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${(wasteRatio * 100).toStringAsFixed(1)}% wasted · $wasteLabel',
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
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Harvests', '${summary.count}'),
              _divider(),
              _stat('This month', '${summary.thisMonthCount}'),
              _divider(),
              _stat(
                'Wasted',
                hasWaste
                    ? formatQuantity(
                        summary.wasted,
                        summary.dominantUnit,
                      )
                    : '—',
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
// Time filter chips
// ===========================================================================
class _TimeFilterRow extends StatelessWidget {
  const _TimeFilterRow({
    required this.current,
    required this.counts,
    required this.onChange,
  });

  final String current;
  final ({int all, int today, int week, int month}) counts;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', 'all', counts.all),
          const SizedBox(width: 8),
          _chip('Today', 'today', counts.today),
          const SizedBox(width: 8),
          _chip('Week', 'week', counts.week),
          const SizedBox(width: 8),
          _chip('Month', 'month', counts.month),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, int count) {
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
            color: selected
                ? HarvestStyle.primary
                : HarvestStyle.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: HarvestStyle.primary
                  .withValues(alpha: selected ? 0 : 0.25),
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
                  color: selected ? Colors.white : HarvestStyle.primaryDeep,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : HarvestStyle.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : HarvestStyle.primaryDeep,
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
// Grade filter chips (A / B / C toggle)
// ===========================================================================
class _GradeFilterRow extends StatelessWidget {
  const _GradeFilterRow({required this.current, required this.onChange});

  final String? current;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Grade',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(width: 10),
        ...HarvestStyle.grades.map((g) {
          final selected = current == g;
          final color = HarvestStyle.gradeColor(g);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onChange(selected ? null : g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: selected ? 0 : 0.25),
                    ),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        if (current != null) ...[
          const SizedBox(width: 2),
          TextButton(
            onPressed: () => onChange(null),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Clear',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// Harvest row
// ===========================================================================
class _HarvestTile extends ConsumerWidget {
  const _HarvestTile({required this.harvest, required this.farmId});

  final Harvest harvest;
  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradeColor = HarvestStyle.gradeColor(harvest.grade);
    final radius = BorderRadius.circular(14);

    final gross = harvest.quantity;
    final wasted = harvest.wastedQuantity;
    final net = (gross - wasted).clamp(0, double.infinity).toDouble();
    final wasteRatio = gross <= 0
        ? 0.0
        : (wasted / gross).clamp(0.0, 1.0).toDouble();
    final hasWaste = wasted > 0;

    return Dismissible(
      key: ValueKey(harvest.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete harvest?'),
          content: Text(
            '"${harvest.cropName.isEmpty ? 'Harvest' : harvest.cropName}" will be removed permanently.',
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
          ref.read(harvestRepositoryProvider).deleteHarvest(farmId, harvest.id),
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
            onTap: () => context.push('/harvests/${harvest.id}'),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Grade badge
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              harvest.grade.toUpperCase(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: gradeColor,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'GRADE',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: gradeColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              harvest.cropName.isEmpty
                                  ? '(unnamed crop)'
                                  : harvest.cropName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              harvest.location.isEmpty
                                  ? 'No location'
                                  : harvest.location,
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
                            formatQuantity(net, harvest.unit),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: HarvestStyle.primaryDeep,
                            ),
                          ),
                          if (hasWaste) ...[
                            const SizedBox(height: 3),
                            Text(
                              '−${formatQuantity(wasted, harvest.unit)} waste',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: HarvestStyle.wasteColor(wasteRatio),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (hasWaste) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: wasteRatio,
                              minHeight: 4,
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation(
                                HarvestStyle.wasteColor(wasteRatio),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(wasteRatio * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: HarvestStyle.wasteColor(wasteRatio),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                color: HarvestStyle.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.agriculture,
                  size: 32, color: HarvestStyle.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No harvests recorded yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Log your first harvest to start tracking yield and wastage.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}