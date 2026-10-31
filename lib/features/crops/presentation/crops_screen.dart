import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../data/crop_model.dart';
import '../data/crop_style.dart';
import '../providers/crop_provider.dart';

const _rXl = 24.0;
const _rMd = 16.0;
const _maxContent = 560.0;

List<BoxShadow> _soft(Color c, {double a = 0.05}) => [
      BoxShadow(
        color: c.withValues(alpha: a),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];

class CropsScreen extends ConsumerStatefulWidget {
  const CropsScreen({super.key});

  @override
  ConsumerState<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends ConsumerState<CropsScreen> {
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
      ref.read(cropSearchProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);

    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crops')),
        body: const Center(
          child: Text('Select a farm first from the Farms tab.'),
        ),
      );
    }

    final cropsAsync = ref.watch(cropsStreamProvider);
    final summary = ref.watch(cropSummaryProvider);
    final filter = ref.watch(cropFilterProvider);
    final filtered = ref.watch(filteredCropsProvider);
    final counts = ref.watch(cropCountsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) {
          return _buildDesktopLayout(
            context,
            cropsAsync,
            filtered,
            summary,
            counts,
            filter,
          );
        }
        return _buildMobileLayout(
          context,
          cropsAsync,
          filtered,
          summary,
          counts,
          filter,
        );
      },
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(
    BuildContext context,
    AsyncValue<List<Crop>> cropsAsync,
    List<Crop> filtered,
    CropSummary summary,
    ({int all, int growing, int ready, int harvested}) counts,
    String filter,
  ) {
    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: cropsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDesktopHeader(context),
                const SizedBox(height: 24),
                _HeroBanner(summary: summary, isDesktop: true),
                const SizedBox(height: 24),
                _FilterRow(
                  current: filter,
                  counts: counts,
                  onChange: (v) =>
                      ref.read(cropFilterProvider.notifier).state = v,
                ),
                const SizedBox(height: 24),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    child: Center(
                      child: Text(
                        'No crops match your filters.',
                        style: TextStyle(
                          fontSize: 14,
                          color: DPalette.inkMuted,
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      mainAxisExtent: 268,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _DesktopCropCard(crop: filtered[index]);
                    },
                  ),
              ],
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
                'Crops Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your fields, growth stages and harvests.',
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
              hintText: 'Search crops...',
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                borderSide:
                    const BorderSide(color: DPalette.brand, width: 1.5),
              ),
            ),
            onChanged: (v) =>
                ref.read(cropSearchProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => context.push('/crops/add'),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Add Crop',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: DPalette.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT (unchanged structure)
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    AsyncValue<List<Crop>> cropsAsync,
    List<Crop> filtered,
    CropSummary summary,
    ({int all, int growing, int ready, int harvested}) counts,
    String filter,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search crop, variety, location…',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(cropSearchProvider.notifier).state = v,
              )
            : const Text('Crops'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Crop report',
            onPressed: () => context.push('/reports/crop'),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add crop',
            onPressed: () => context.push('/crops/add'),
          ),
        ],
      ),
      body: cropsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContent),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  120 + bottomInset,
                ),
                children: [
                  _HeroBanner(summary: summary),
                  const SizedBox(height: 18),
                  _FilterRow(
                    current: filter,
                    counts: counts,
                    onChange: (v) =>
                        ref.read(cropFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 56),
                      child: Center(
                        child: Text(
                          'No crops match your filters.',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((c) => _CropRow(crop: c)),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/crops/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Crop',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared card bits
// ===========================================================================
Widget _cropStagePill(String stage) {
  final color = CropStyle.stageColor(stage);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      _stageLabelUpper(stage),
      style: TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color,
      ),
    ),
  );
}

Widget _cropMiniStat({
  required IconData icon,
  required String value,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ],
    ),
  );
}

String _stageLabelUpper(String stage) {
  switch (stage) {
    case 'growing':
      return 'GROWING';
    case 'harvest_ready':
      return 'READY';
    case 'harvested':
      return 'HARVESTED';
    default:
      return stage.toUpperCase();
  }
}

// ===========================================================================
// Desktop crop card — gradient icon + stage pill + mini stats
// ===========================================================================
class _DesktopCropCard extends ConsumerWidget {
  const _DesktopCropCard({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageColor = CropStyle.stageColor(crop.stage);
    final stageIcon = CropStyle.stageIcon(crop.stage);

    return Container(
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stageColor.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: stageColor.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/crops/${crop.id}/detail'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            stageColor.withValues(alpha: 0.24),
                            stageColor.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(stageIcon, color: stageColor, size: 22),
                    ),
                    const SizedBox(width: 12),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: DPalette.ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _cropStagePill(crop.stage),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            crop.variety.isEmpty
                                ? 'No variety'
                                : crop.variety,
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
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: DPalette.inkMuted,
                      ),
                      tooltip: 'More options',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          context.push('/crops/${crop.id}');
                        }
                        if (value == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Edit Crop'),
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
                                'Delete Crop',
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
                    const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: DPalette.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        crop.location.isEmpty
                            ? 'No location'
                            : crop.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: DPalette.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Mini stats row — fills the void with useful numbers
                Row(
                  children: [
                    Expanded(
                      child: _cropMiniStat(
                        icon: Icons.eco_outlined,
                        value: '${crop.plantCount}',
                        label: 'Plants',
                        color: CropStyle.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _cropMiniStat(
                        icon: Icons.square_foot_outlined,
                        value: '${_fmtAcreage(crop.acreage)} ac',
                        label: 'Acreage',
                        color: const Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _cropMiniStat(
                        icon: stageIcon,
                        value: _stageLabelUpper(crop.stage),
                        label: 'Stage',
                        color: stageColor,
                      ),
                    ),
                  ],
                ),

                const Spacer(),
                const Divider(color: DPalette.hairline, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 12,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Click card for crop details',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: DPalette.inkMuted,
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

  static String _fmtAcreage(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete crop?'),
        content: Text(
          '"${crop.cropName}" will be removed. Historical harvests, '
          'sales and expenses stay in the database.',
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
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cropRepositoryProvider).deleteCrop(farmId, crop.id);
  }
}

// ===========================================================================
// Hero banner (adaptive)
// ===========================================================================
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.summary, this.isDesktop = false});
  final CropSummary summary;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final padding = isDesktop
        ? const EdgeInsets.fromLTRB(32, 28, 32, 26)
        : const EdgeInsets.fromLTRB(20, 20, 20, 18);
    final acreageSize = isDesktop ? 64.0 : 42.0;
    final unitSize = isDesktop ? 18.0 : 15.0;
    final statLabelSize = isDesktop ? 11.0 : 9.5;
    final statValueSize = isDesktop ? 20.0 : 15.0;
    final dividerHeight = isDesktop ? 42.0 : 30.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_rXl),
        boxShadow: [
          BoxShadow(
            color: CropStyle.primary.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/hero_crop.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(
                'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF14532D).withValues(alpha: 0.88),
                    const Color(0xFF14532D).withValues(alpha: 0.58),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_outlined,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Under cultivation',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.grass_outlined,
                      size: isDesktop ? 24 : 20,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 20 : 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmtAcreage(summary.totalAcreage),
                        style: TextStyle(
                          fontSize: acreageSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: isDesktop ? 10 : 6,
                        ),
                        child: Text(
                          'acres',
                          style: TextStyle(
                            fontSize: unitSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary.readyCount > 0) ...[
                  SizedBox(height: isDesktop ? 16 : 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 14, color: Color(0xFFFFE082)),
                        const SizedBox(width: 6),
                        Text(
                          '${summary.readyCount} ready to harvest',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: isDesktop ? 22 : 18),
                Divider(
                  color: Colors.white.withValues(alpha: 0.18),
                  height: 1,
                ),
                SizedBox(height: isDesktop ? 18 : 14),
                _statsRow(statLabelSize, statValueSize, dividerHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(
    double labelSize,
    double valueSize,
    double dividerHeight,
  ) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 320) {
          return Column(
            children: [
              Row(children: [
                _stat('Growing', '${summary.growingCount}', labelSize,
                    valueSize),
                _divider(dividerHeight),
                _stat('Ready', '${summary.readyCount}', labelSize, valueSize),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _stat('Harvested', '${summary.harvestedCount}', labelSize,
                    valueSize),
                _divider(dividerHeight),
                _stat('Plants', _fmtCount(summary.totalPlants), labelSize,
                    valueSize),
              ]),
            ],
          );
        }
        return Row(
          children: [
            _stat('Growing', '${summary.growingCount}', labelSize, valueSize),
            _divider(dividerHeight),
            _stat('Ready', '${summary.readyCount}', labelSize, valueSize),
            _divider(dividerHeight),
            _stat('Harvested', '${summary.harvestedCount}', labelSize,
                valueSize),
            _divider(dividerHeight),
            _stat('Plants', _fmtCount(summary.totalPlants), labelSize,
                valueSize),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value, double labelSize, double valueSize) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _divider(double height) => Container(
        width: 1,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.18),
      );

  static String _fmtAcreage(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  static String _fmtCount(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ===========================================================================
// Filter chips
// ===========================================================================
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.counts,
    required this.onChange,
  });

  final String current;
  final ({int all, int growing, int ready, int harvested}) counts;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', 'all', counts.all, CropStyle.primary),
          const SizedBox(width: 8),
          _chip('Growing', 'growing', counts.growing, CropStyle.growing),
          const SizedBox(width: 8),
          _chip('Ready', 'harvest_ready', counts.ready, CropStyle.ready),
          const SizedBox(width: 8),
          _chip(
            'Harvested',
            'harvested',
            counts.harvested,
            CropStyle.harvested,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, int count, Color color) {
    final selected = current == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => onChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? color : Colors.black.withValues(alpha: 0.07),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
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
}

// ===========================================================================
// Crop row (mobile) — gradient icon + stage pill
// ===========================================================================
class _CropRow extends ConsumerWidget {
  const _CropRow({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageColor = CropStyle.stageColor(crop.stage);
    final stageIcon = CropStyle.stageIcon(crop.stage);
    final radius = BorderRadius.circular(_rMd);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/crops/${crop.id}/detail'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: stageColor.withValues(alpha: 0.15),
              ),
              boxShadow: _soft(stageColor, a: 0.05),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        stageColor.withValues(alpha: 0.24),
                        stageColor.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(stageIcon, size: 22, color: stageColor),
                ),
                const SizedBox(width: 12),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _cropStagePill(crop.stage),
                        ],
                      ),
                      if (crop.variety.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          crop.variety,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 12,
                              color: Colors.black.withValues(alpha: 0.45)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              crop.location.isEmpty
                                  ? 'No location'
                                  : crop.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _badge(
                            icon: Icons.eco_outlined,
                            label:
                                '${crop.plantCount} plant${crop.plantCount == 1 ? '' : 's'}',
                            color: CropStyle.primary,
                          ),
                          if (crop.acreage > 0)
                            _badge(
                              icon: Icons.square_foot_outlined,
                              label: '${_fmtAcreage(crop.acreage)} ac',
                              color: const Color(0xFF00897B),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  children: [
                    _iconBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      color: AppTheme.primaryGreen,
                      onTap: () => context.push('/crops/${crop.id}'),
                    ),
                    const SizedBox(height: 6),
                    _iconBtn(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete',
                      color: const Color(0xFFC62828),
                      onTap: () => _confirmDelete(context, ref),
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

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtAcreage(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete crop?'),
        content: Text(
          '"${crop.cropName}" will be removed. Historical harvests, '
          'sales and expenses stay in the database.',
          style: TextStyle(
              fontSize: 13, color: Colors.black.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cropRepositoryProvider).deleteCrop(farmId, crop.id);
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: CropStyle.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grass_outlined,
                  size: 38, color: CropStyle.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No crops yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first crop to track\nplanting, growth and harvest.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}