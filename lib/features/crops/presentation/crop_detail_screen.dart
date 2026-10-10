import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../farms/providers/farm_provider.dart';
import '../data/crop_activity_model.dart';
import '../data/crop_model.dart';
import '../data/crop_style.dart';
import '../providers/crop_activity_provider.dart';
import '../providers/crop_provider.dart';
import '../widgets/activity_tile.dart';

class CropDetailScreen extends ConsumerWidget {
  final String cropId;
  const CropDetailScreen({super.key, required this.cropId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('Select a farm first')));
    }

    final cropsAsync = ref.watch(cropsStreamProvider);
    final activitiesAsync = ref.watch(
      cropActivitiesStreamProvider((farmId: farmId, cropId: cropId)),
    );
    final typeFilter = ref.watch(activityTypeFilterProvider);

    // Log any stream errors so they appear in the console, but never crash.
    ref.listen(
      cropActivitiesStreamProvider((farmId: farmId, cropId: cropId)),
      (_, next) {
        next.whenOrNull(error: (e, _) {
          debugPrint('Activities stream error: $e');
        });
      },
    );

    return cropsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (crops) {
        final crop = crops.where((c) => c.id == cropId).firstOrNull;
        if (crop == null) {
          return const Scaffold(
            body: Center(child: Text('Crop not found.')),
          );
        }

        // If the activities stream is still loading or errored,
        // fall back to an empty list rather than blocking the screen.
        final activities = activitiesAsync.value ?? const <CropActivity>[];
        final filtered = typeFilter == null
            ? activities
            : activities.where((a) => a.type == typeFilter).toList();

        final totals = _Totals.from(activities);

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              _heroAppBar(context, crop),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _statsRow(context, crop),
                    const SizedBox(height: 16),
                    _financialCard(totals, activities.length),
                    const SizedBox(height: 20),
                    _quickActions(context),
                    const SizedBox(height: 20),
                    if (activities.isNotEmpty) ...[
                      _sectionHeader(
                        'Activity History',
                        '${activities.length} '
                            '${activities.length == 1 ? 'record' : 'records'}',
                      ),
                      const SizedBox(height: 10),
                      _filterRow(ref, activities, typeFilter),
                      const SizedBox(height: 12),
                    ],
                    if (filtered.isEmpty)
                      _emptyActivities(context)
                    else
                      ...filtered.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ActivityTile(
                            activity: a,
                            onEdit: () => context.push(
                              '/crops/$cropId/activities/${a.id}/edit',
                            ),
                            onDelete: () => _confirmDelete(context, ref, a),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/crops/$cropId/activities/add'),
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Record Activity'),
          ),
        );
      },
    );
  }

  // =========================================================================
  // HERO APP BAR
  // =========================================================================
  Widget _heroAppBar(BuildContext context, Crop crop) {
    final stageColor = CropStyle.stageColor(crop.stage);

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/crops');
          }
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit crop',
          onPressed: () => context.push('/crops/${crop.id}'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.symmetric(
          horizontal: 56,
          vertical: 16,
        ),
        title: Text(
          crop.cropName.isEmpty ? '(unnamed)' : crop.cropName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/hero_crop.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(
                'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: stageColor),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CropStyle.stageIcon(crop.stage),
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      CropStyle.stageLabel(crop.stage).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 56,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _heroChip(
                    Icons.place_outlined,
                    crop.location.isEmpty ? 'No location' : crop.location,
                  ),
                  if (crop.variety.isNotEmpty)
                    _heroChip(
                      Icons.local_florist_outlined,
                      crop.variety,
                    ),
                  if (crop.acreage > 0)
                    _heroChip(
                      Icons.square_foot_outlined,
                      '${_fmtAcreage(crop.acreage)} ac',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STATS ROW
  // =========================================================================
  Widget _statsRow(BuildContext context, Crop crop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _stat('Plants', '${crop.plantCount}', Icons.eco_outlined),
          _vDivider(),
          _stat(
            'Acreage',
            crop.acreage == crop.acreage.roundToDouble()
                ? '${crop.acreage.toStringAsFixed(0)}'
                : crop.acreage.toStringAsFixed(1),
            Icons.square_foot_outlined,
          ),
          _vDivider(),
          _stat(
            'Planted',
            crop.plantingDate != null
                ? '${crop.plantingDate!.day}/${crop.plantingDate!.month}'
                : '—',
            Icons.calendar_today_outlined,
          ),
          _vDivider(),
          _stat(
            'Harvest',
            crop.expectedHarvest != null
                ? '${crop.expectedHarvest!.day}/${crop.expectedHarvest!.month}'
                : '—',
            Icons.event_available_outlined,
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.black.withValues(alpha: 0.4)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.5),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 40,
        color: Colors.black.withValues(alpha: 0.06),
      );

  // =========================================================================
  // FINANCIAL HERO
  // =========================================================================
  Widget _financialCard(_Totals t, int activityCount) {
    final profit = t.income - t.cost;
    final positive = profit >= 0;
    final accent =
        positive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFF8E0000), const Color(0xFFC62828)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 20,
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
                positive ? 'Net profit' : 'Net loss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$activityCount activities',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${positive ? '' : '−'}KSh ${_compact(profit.abs())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Divider(
            color: Colors.white.withValues(alpha: 0.18),
            height: 1,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _finStat('Cost', t.cost, Icons.trending_down),
              _finDivider(),
              _finStat('Income', t.income, Icons.trending_up),
              _finDivider(),
              _finStat(
                'Margin',
                null,
                Icons.percent,
                customLabel: t.income <= 0
                    ? '—'
                    : '${(profit / t.income * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finStat(
    String label,
    double? value,
    IconData icon, {
    String? customLabel,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              customLabel ?? 'KSh ${_compact(value ?? 0)}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finDivider() => Container(
        width: 1,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.18),
      );

  // =========================================================================
  // QUICK ACTIONS
  // =========================================================================
  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            context,
            icon: Icons.insights_outlined,
            label: 'View Report',
            color: const Color(0xFF1E88E5),
            onTap: () => context.push('/reports/crop'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionBtn(
            context,
            icon: Icons.edit_outlined,
            label: 'Edit Crop',
            color: AppTheme.primaryGreen,
            onTap: () => context.push('/crops/$cropId'),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION HEADER
  // =========================================================================
  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // FILTER CHIPS
  // =========================================================================
  Widget _filterRow(
    WidgetRef ref,
    List<CropActivity> activities,
    String? current,
  ) {
    final counts = <String, int>{};
    for (final a in activities) {
      counts[a.type] = (counts[a.type] ?? 0) + 1;
    }

    final present =
        ActivityTypes.all.where((t) => (counts[t] ?? 0) > 0).toList();

    if (present.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', null, activities.length, current, ref),
          for (final t in present) ...[
            const SizedBox(width: 8),
            _chip(
              ActivityTypes.label(t),
              t,
              counts[t]!,
              current,
              ref,
              color: ActivityTypes.color(t),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    String? value,
    int count,
    String? current,
    WidgetRef ref, {
    Color color = AppTheme.primaryGreen,
  }) {
    final selected = current == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            ref.read(activityTypeFilterProvider.notifier).state = value,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
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

  // =========================================================================
  // EMPTY STATE
  // =========================================================================
  Widget _emptyActivities(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_edu_outlined,
              size: 28,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No activity recorded yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Record irrigation, fertilization, spraying and more to '
            'build this crop\'s history and see its profitability.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DELETE CONFIRMATION
  // =========================================================================
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CropActivity activity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete activity?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will also remove any linked expense or income record.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
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
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(cropActivityRepositoryProvider).deleteActivity(
          farmId: activity.farmId,
          cropId: activity.cropId,
          activityId: activity.id,
          linkedExpenseId: activity.linkedExpenseId,
          linkedSaleId: activity.linkedSaleId,
        );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================
  static String _compact(double n) {
    if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  static String _fmtAcreage(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// Totals
// ===========================================================================
class _Totals {
  final double cost;
  final double income;
  _Totals({required this.cost, required this.income});

  factory _Totals.from(List<CropActivity> activities) {
    var cost = 0.0;
    var income = 0.0;
    for (final a in activities) {
      cost += a.cost ?? 0;
      income += a.income ?? 0;
    }
    return _Totals(cost: cost, income: income);
  }
}