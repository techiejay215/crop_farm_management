import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
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

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(BuildContext context, String farmId) {
    final harvestsAsync = ref.watch(harvestsStreamProvider);
    final summary = ref.watch(harvestSummaryProvider);
    final timeFilter = ref.watch(harvestFilterProvider);
    final gradeFilter = ref.watch(harvestGradeFilterProvider);
    final filtered = ref.watch(filteredHarvestsProvider);
    final counts = ref.watch(harvestTimeCountsProvider);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: harvestsAsync.when(
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
                    const SizedBox(height: 24),
                    _TimeFilterRow(
                      current: timeFilter,
                      counts: counts,
                      isDesktop: true,
                      onChange: (v) => ref
                          .read(harvestFilterProvider.notifier)
                          .state = v,
                    ),
                    const SizedBox(height: 12),
                    _GradeFilterRow(
                      current: gradeFilter,
                      isDesktop: true,
                      onChange: (v) => ref
                          .read(harvestGradeFilterProvider.notifier)
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
                'Harvests',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track yield, grades and wastage across your crops.',
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
              hintText: 'Search harvests...',
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
                ref.read(harvestSearchProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(
            Icons.insights_outlined,
            color: DPalette.inkMuted,
          ),
          tooltip: 'Harvest report',
          onPressed: () => context.push('/reports/harvest'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/harvests/add'),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Record Harvest',
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
    List<Harvest> records,
    String farmId, {
    bool isDesktop = false,
  }) {
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

      if (isDesktop) {
        widgets.addAll(
          items.map((h) => _DesktopHarvestTile(harvest: h, farmId: farmId)),
        );
      } else {
        widgets.addAll(
          items.map((h) => _HarvestTile(harvest: h, farmId: farmId)),
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
  final HarvestSummary summary;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final wasteRatio = summary.wasteRatio;
    final wasteColor = HarvestStyle.wasteColor(wasteRatio);
    final wasteLabel = HarvestStyle.wasteLabel(wasteRatio);
    final hasWaste = summary.hasWaste;

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
                  fontSize: isDesktop ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.agriculture,
                size: isDesktop ? 22 : 18,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 8 : 6),
          Text(
            formatQuantity(summary.netYield, summary.dominantUnit),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: headlineSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (hasWaste) ...[
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
          SizedBox(height: isDesktop ? 22 : 18),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          SizedBox(height: isDesktop ? 18 : 14),
          Row(
            children: [
              _stat('Harvests', '${summary.count}', statLabelSize, statValueSize),
              _divider(dividerHeight),
              _stat(
                'This month',
                '${summary.thisMonthCount}',
                statLabelSize,
                statValueSize,
              ),
              _divider(dividerHeight),
              _stat(
                'Wasted',
                hasWaste
                    ? formatQuantity(
                        summary.wasted,
                        summary.dominantUnit,
                      )
                    : '—',
                statLabelSize,
                statValueSize,
              ),
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
// Time filter chips (adaptive)
// ===========================================================================
class _TimeFilterRow extends StatelessWidget {
  const _TimeFilterRow({
    required this.current,
    required this.counts,
    required this.onChange,
    this.isDesktop = false,
  });

  final String current;
  final ({int all, int today, int week, int month}) counts;
  final ValueChanged<String> onChange;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('All', 'all', counts.all),
      _chip('Today', 'today', counts.today),
      _chip('Week', 'week', counts.week),
      _chip('Month', 'month', counts.month),
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
// Grade filter chips (adaptive)
// ===========================================================================
class _GradeFilterRow extends StatelessWidget {
  const _GradeFilterRow({
    required this.current,
    required this.onChange,
    this.isDesktop = false,
  });

  final String? current;
  final ValueChanged<String?> onChange;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final gradeWidgets = HarvestStyle.grades.map((g) {
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
    }).toList();

    final clearBtn = current != null
        ? TextButton(
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
          )
        : const SizedBox.shrink();

    if (isDesktop) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              'Grade',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          ...gradeWidgets,
          if (current != null) clearBtn,
        ],
      );
    }

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
        ...gradeWidgets,
        if (current != null) ...[
          const SizedBox(width: 2),
          clearBtn,
        ],
      ],
    );
  }
}

// ===========================================================================
// MOBILE harvest tile (unchanged — swipe to delete)
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
// DESKTOP harvest tile (popup menu instead of swipe)
// ===========================================================================
class _DesktopHarvestTile extends ConsumerWidget {
  const _DesktopHarvestTile({required this.harvest, required this.farmId});

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
          onTap: () => context.push('/harvests/${harvest.id}'),
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
                        color: gradeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            harvest.grade.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
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
                    const SizedBox(width: 14),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: DPalette.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            harvest.location.isEmpty
                                ? 'No location'
                                : harvest.location,
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
                          formatQuantity(net, harvest.unit),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: HarvestStyle.primaryDeep,
                          ),
                        ),
                        if (hasWaste) ...[
                          const SizedBox(height: 3),
                          Text(
                            '−${formatQuantity(wasted, harvest.unit)} waste',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: HarvestStyle.wasteColor(wasteRatio),
                            ),
                          ),
                        ],
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
                          context.push('/harvests/${harvest.id}');
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
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete harvest?'),
        content: Text(
          '"${harvest.cropName.isEmpty ? 'Harvest' : harvest.cropName}" will be removed permanently.',
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
    await ref.read(harvestRepositoryProvider).deleteHarvest(farmId, harvest.id);
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