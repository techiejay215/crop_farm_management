import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../expenses/expense_format.dart';
import '../../farms/providers/farm_provider.dart';
import '../data/crop_activity_model.dart';
import '../data/crop_model.dart';
import '../data/crop_style.dart';
import '../providers/crop_activity_provider.dart';
import '../providers/crop_provider.dart';
import '../widgets/activity_tile.dart';

const _maxContent = 640.0;

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

    ref.listen(
      cropActivitiesStreamProvider((farmId: farmId, cropId: cropId)),
      (_, next) {
        next.whenOrNull(error: (e, _) {
          debugPrint('Activities stream error: $e');
        });
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) {
          return _buildDesktop(
            context,
            ref,
            cropsAsync,
            activitiesAsync,
            typeFilter,
          );
        }
        return _buildMobile(
          context,
          ref,
          cropsAsync,
          activitiesAsync,
          typeFilter,
        );
      },
    );
  }

  // ===========================================================================
  // MOBILE (unchanged)
  // ===========================================================================
  Widget _buildMobile(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Crop>> cropsAsync,
    AsyncValue<List<CropActivity>> activitiesAsync,
    String? typeFilter,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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

        final activities = activitiesAsync.value ?? const <CropActivity>[];
        final filtered = typeFilter == null
            ? activities
            : activities.where((a) => a.type == typeFilter).toList();
        final totals = _Totals.from(activities);

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContent),
              child: CustomScrollView(
                slivers: [
                  _heroAppBar(context, crop),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      120 + bottomInset,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _statsRow(context, crop),
                        const SizedBox(height: 18),
                        _financialCard(totals, activities.length),
                        const SizedBox(height: 22),
                        _quickActions(context),
                        const SizedBox(height: 22),
                        if (activities.isNotEmpty) ...[
                          _sectionHeader(
                            'Activity History',
                            '${activities.length} '
                                '${activities.length == 1 ? 'record' : 'records'}',
                          ),
                          const SizedBox(height: 12),
                          _filterRow(ref, activities, typeFilter),
                          const SizedBox(height: 14),
                        ],
                        if (filtered.isEmpty)
                          _emptyActivities(context)
                        else
                          ...filtered.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ActivityTile(
                                activity: a,
                                onEdit: () => context.push(
                                  '/crops/$cropId/activities/${a.id}/edit',
                                ),
                                onDelete: () =>
                                    _confirmDelete(context, ref, a),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/crops/$cropId/activities/add'),
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Record Activity',
              style:
                  TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Crop>> cropsAsync,
    AsyncValue<List<CropActivity>> activitiesAsync,
    String? typeFilter,
  ) {
    return cropsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: DPalette.canvas,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: DPalette.canvas,
        body: Center(child: Text('Error: $e')),
      ),
      data: (crops) {
        final crop = crops.where((c) => c.id == cropId).firstOrNull;
        if (crop == null) {
          return Scaffold(
            backgroundColor: DPalette.canvas,
            body: const Center(child: Text('Crop not found.')),
          );
        }

        final activities = activitiesAsync.value ?? const <CropActivity>[];
        final filtered = typeFilter == null
            ? activities
            : activities.where((a) => a.type == typeFilter).toList();
        final totals = _Totals.from(activities);

        return Scaffold(
          backgroundColor: DPalette.canvas,
          body: Column(
            children: [
              _buildDesktopHeader(context, crop),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _statsRow(context, crop),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main column
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _financialCard(totals, activities.length),
                                    const SizedBox(height: 20),
                                    _buildActivitiesSection(
                                      context,
                                      ref,
                                      activities,
                                      filtered,
                                      typeFilter,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Sidebar
                              Expanded(
                                flex: 4,
                                child: _buildDesktopSidebar(context, crop),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopHeader(BuildContext context, Crop crop) {
    final stageColor = CropStyle.stageColor(crop.stage);

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 18, 32, 18),
      decoration: const BoxDecoration(
        color: DPalette.surface,
        border: Border(bottom: BorderSide(color: DPalette.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: DPalette.ink),
            tooltip: 'Back to crops',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/crops');
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        crop.cropName.isEmpty
                            ? '(unnamed crop)'
                            : crop.cropName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: DPalette.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: stageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CropStyle.stageIcon(crop.stage),
                              size: 11, color: stageColor),
                          const SizedBox(width: 4),
                          Text(
                            CropStyle.stageLabel(crop.stage).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: stageColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (crop.location.isNotEmpty) ...[
                      Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: DPalette.inkMuted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        crop.location,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: DPalette.inkMuted,
                        ),
                      ),
                    ],
                    if (crop.location.isNotEmpty && crop.variety.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: DPalette.inkMuted.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (crop.variety.isNotEmpty)
                      Text(
                        crop.variety,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: DPalette.inkMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/crops/$cropId'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DPalette.ink,
              side: const BorderSide(color: DPalette.hairline),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () =>
                context.push('/crops/$cropId/activities/add'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Record Activity',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DPalette.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DESKTOP SIDEBAR
  // ===========================================================================
  Widget _buildDesktopSidebar(BuildContext context, Crop crop) {
    final now = DateTime.now();

    String? sincePlanted;
    String? toHarvest;
    if (crop.plantingDate != null) {
      final d = now.difference(crop.plantingDate!).inDays;
      sincePlanted = d < 0
          ? 'in ${-d} days'
          : d == 0
              ? 'today'
              : '$d days ago';
    }
    if (crop.expectedHarvest != null) {
      final d = crop.expectedHarvest!.difference(now).inDays;
      toHarvest = d < 0
          ? '${-d} days overdue'
          : d == 0
              ? 'today'
              : 'in $d days';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Key dates card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DPalette.hairline),
            boxShadow: DPalette.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'KEY DATES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: DPalette.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: DPalette.inkMuted),
                ],
              ),
              const SizedBox(height: 16),
              _insightRow(
                'Planted',
                crop.plantingDate == null
                    ? '—'
                    : fullDate(crop.plantingDate!),
                sincePlanted,
              ),
              const SizedBox(height: 12),
              const Divider(color: DPalette.hairline, height: 1),
              const SizedBox(height: 12),
              _insightRow(
                'Expected harvest',
                crop.expectedHarvest == null
                    ? '—'
                    : fullDate(crop.expectedHarvest!),
                toHarvest,
                highlight: toHarvest != null &&
                    crop.expectedHarvest != null &&
                    crop.expectedHarvest!.isBefore(now.add(
                          const Duration(days: 14),
                        )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick actions card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DPalette.hairline),
            boxShadow: DPalette.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: DPalette.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              _actionTile(
                context,
                icon: Icons.add_rounded,
                label: 'Record activity',
                subtitle: 'Log irrigation, spraying, harvests…',
                color: DPalette.brand,
                onTap: () =>
                    context.push('/crops/$cropId/activities/add'),
                filled: true,
              ),
              const SizedBox(height: 10),
              _actionTile(
                context,
                icon: Icons.insights_outlined,
                label: 'View crop report',
                subtitle: 'Full profitability, yield and price',
                color: const Color(0xFF1E88E5),
                onTap: () => context.push('/reports/crop'),
              ),
              const SizedBox(height: 10),
              _actionTile(
                context,
                icon: Icons.edit_outlined,
                label: 'Edit crop',
                subtitle: 'Name, variety, dates and stage',
                color: DPalette.inkMuted,
                onTap: () => context.push('/crops/$cropId'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _insightRow(
    String label,
    String value,
    String? hint, {
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: DPalette.inkMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: DPalette.ink,
                ),
              ),
            ],
          ),
        ),
        if (hint != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (highlight
                      ? const Color(0xFFEF6C00)
                      : DPalette.brand)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: highlight
                    ? const Color(0xFFEF6C00)
                    : DPalette.brand,
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: filled
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled
                  ? color.withValues(alpha: 0.25)
                  : DPalette.hairline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: filled ? color : DPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: DPalette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: DPalette.inkMuted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP ACTIVITIES SECTION
  // ===========================================================================
  Widget _buildActivitiesSection(
    BuildContext context,
    WidgetRef ref,
    List<CropActivity> activities,
    List<CropActivity> filtered,
    String? typeFilter,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Activity History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${activities.length} '
                  '${activities.length == 1 ? 'record' : 'records'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DPalette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isNotEmpty) ...[
            _filterRow(ref, activities, typeFilter),
            const SizedBox(height: 16),
          ],
          if (filtered.isEmpty)
            _emptyActivities(context)
          else
            ...filtered.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ActivityTile(
                  activity: a,
                  onEdit: () => context.push(
                    '/crops/$cropId/activities/${a.id}/edit',
                  ),
                  onDelete: () => _confirmDelete(context, ref, a),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HERO APP BAR (mobile only — unchanged)
  // ===========================================================================
  Widget _heroAppBar(BuildContext context, Crop crop) {
    final stageColor = CropStyle.stageColor(crop.stage);
    final h = MediaQuery.sizeOf(context).height;
    final expanded = (h * 0.40).clamp(240.0, 300.0);

    return SliverAppBar(
      expandedHeight: expanded,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
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
            fontWeight: FontWeight.w800,
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
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.88),
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
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: stageColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CropStyle.stageIcon(crop.stage),
                      size: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATS ROW (unchanged, works on both)
  // ===========================================================================
  Widget _statsRow(BuildContext context, Crop crop) {
    final statItems = <Widget>[
      _stat('Plants', '${crop.plantCount}', Icons.eco_outlined),
      _stat(
        'Acreage',
        crop.acreage == crop.acreage.roundToDouble()
            ? '${crop.acreage.toStringAsFixed(0)}'
            : crop.acreage.toStringAsFixed(1),
        Icons.square_foot_outlined,
      ),
      _stat(
        'Planted',
        crop.plantingDate != null
            ? '${crop.plantingDate!.day}/${crop.plantingDate!.month}'
            : '—',
        Icons.calendar_today_outlined,
      ),
      _stat(
        'Harvest',
        crop.expectedHarvest != null
            ? '${crop.expectedHarvest!.day}/${crop.expectedHarvest!.month}'
            : '—',
        Icons.event_available_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 320) {
            return Column(
              children: [
                Row(children: [
                  statItems[0],
                  _vDivider(),
                  statItems[1],
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  statItems[2],
                  _vDivider(),
                  statItems[3],
                ]),
              ],
            );
          }
          return Row(
            children: [
              statItems[0],
              _vDivider(),
              statItems[1],
              _vDivider(),
              statItems[2],
              _vDivider(),
              statItems[3],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 16,
              color: DPalette.inkMuted.withValues(alpha: 0.7)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DPalette.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: DPalette.inkMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 44,
        color: DPalette.hairline,
      );

  // ===========================================================================
  // FINANCIAL HERO (unchanged)
  // ===========================================================================
  Widget _financialCard(_Totals t, int activityCount) {
    final profit = t.income - t.cost;
    final positive = profit >= 0;
    final accent =
        positive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFF8E0000), const Color(0xFFC62828)],
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
              Flexible(
                child: Text(
                  positive ? 'Net profit' : 'Net loss',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$activityCount activities',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${positive ? '' : '−'}KSh ${_compact(profit.abs())}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(
            color: Colors.white.withValues(alpha: 0.18),
            height: 1,
          ),
          const SizedBox(height: 16),
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
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              customLabel ?? 'KSh ${_compact(value ?? 0)}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finDivider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.18),
      );

  // ===========================================================================
  // QUICK ACTIONS (mobile only)
  // ===========================================================================
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DPalette.hairline),
            boxShadow: DPalette.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

  // ===========================================================================
  // SECTION HEADER (mobile only)
  // ===========================================================================
  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // FILTER CHIPS (unchanged)
  // ===========================================================================
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
        borderRadius: BorderRadius.circular(30),
        onTap: () =>
            ref.read(activityTypeFilterProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color:
                  selected ? color : Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

  // ===========================================================================
  // EMPTY STATE (unchanged)
  // ===========================================================================
  Widget _emptyActivities(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_edu_outlined,
              size: 30,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No activity recorded yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record irrigation, fertilization, spraying and more to '
            'build this crop\'s history and see its profitability.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DELETE (unchanged)
  // ===========================================================================
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CropActivity activity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
            height: 1.5,
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

  // ===========================================================================
  // HELPERS (unchanged)
  // ===========================================================================
  static String _compact(double n) {
    if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  static String _fmtAcreage(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// Totals (unchanged)
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