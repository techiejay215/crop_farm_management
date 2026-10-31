import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../crops/data/crop_model.dart';
import '../../crops/data/crop_style.dart';
import '../../crops/providers/crop_provider.dart';
import '../data/greenhouse_model.dart';
import '../data/greenhouse_style.dart';
import '../providers/greenhouse_provider.dart';

class GreenhousesScreen extends ConsumerStatefulWidget {
  const GreenhousesScreen({super.key});

  @override
  ConsumerState<GreenhousesScreen> createState() => _GreenhousesScreenState();
}

class _GreenhousesScreenState extends ConsumerState<GreenhousesScreen> {
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
      ref.read(greenhouseSearchProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);

    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Greenhouses')),
        body: const Center(
          child: Text('Select a farm first from the Farms tab.'),
        ),
      );
    }

    final ghAsync = ref.watch(greenhousesStreamProvider);
    final summary = ref.watch(greenhouseSummaryProvider);
    final filter = ref.watch(greenhouseFilterProvider);
    final filtered = ref.watch(filteredGreenhousesProvider);
    final counts = ref.watch(greenhouseCountsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) {
          return _buildDesktopLayout(
            context,
            ghAsync,
            summary,
            filter,
            filtered,
            counts,
          );
        }
        return _buildMobileLayout(
          context,
          ghAsync,
          summary,
          filter,
          filtered,
          counts,
        );
      },
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    AsyncValue<List<Greenhouse>> ghAsync,
    GreenhouseSummary summary,
    String filter,
    List<Greenhouse> filtered,
    ({int all, int active, int empty}) counts,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search name or crop…',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(greenhouseSearchProvider.notifier).state = v,
              )
            : const Text('Greenhouses'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Greenhouse report',
            onPressed: () => context.push('/reports/greenhouse'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add greenhouse',
            onPressed: () => context.push('/greenhouses/add'),
          ),
        ],
      ),
      body: ghAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _Hero(summary: summary),
              const SizedBox(height: 16),
              _FilterRow(
                current: filter,
                counts: counts,
                onChange: (v) =>
                    ref.read(greenhouseFilterProvider.notifier).state = v,
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No greenhouses match your filters.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map((gh) => _GreenhouseCard(greenhouse: gh)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/greenhouses/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Greenhouse'),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(
    BuildContext context,
    AsyncValue<List<Greenhouse>> ghAsync,
    GreenhouseSummary summary,
    String filter,
    List<Greenhouse> filtered,
    ({int all, int active, int empty}) counts,
  ) {
    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: ghAsync.when(
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
                    _Hero(summary: summary, isDesktop: true),
                    const SizedBox(height: 24),
                    _FilterRow(
                      current: filter,
                      counts: counts,
                      isDesktop: true,
                      onChange: (v) => ref
                          .read(greenhouseFilterProvider.notifier)
                          .state = v,
                    ),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: Text(
                            'No greenhouses match your filters.',
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
                          maxCrossAxisExtent: 460,
                          mainAxisExtent: 320,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _DesktopGreenhouseCard(
                            greenhouse: filtered[index],
                          );
                        },
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
                'Greenhouses',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Controlled-environment crops under glass.',
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
              hintText: 'Search greenhouses...',
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
                ref.read(greenhouseSearchProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(
            Icons.insights_outlined,
            color: DPalette.inkMuted,
          ),
          tooltip: 'Greenhouse report',
          onPressed: () => context.push('/reports/greenhouse'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/greenhouses/add'),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Add Greenhouse',
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
}

// ===========================================================================
// Shared bits
// ===========================================================================
Widget _statusPill(bool isActive, Color accent) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      isActive ? 'ACTIVE' : 'EMPTY',
      style: TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: accent,
      ),
    ),
  );
}

Widget _stageBadge(String stage) {
  final color = CropStyle.stageColor(stage);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      CropStyle.stageLabel(stage).toUpperCase(),
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: color,
      ),
    ),
  );
}

Widget _miniStat({
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

// ===========================================================================
// HERO (adaptive)
// ===========================================================================
class _Hero extends StatelessWidget {
  const _Hero({required this.summary, this.isDesktop = false});
  final GreenhouseSummary summary;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final padding = isDesktop
        ? const EdgeInsets.fromLTRB(32, 28, 32, 26)
        : const EdgeInsets.all(20);
    final areaSize = isDesktop ? 56.0 : 34.0;
    final unitSize = isDesktop ? 18.0 : 15.0;
    final statLabelSize = isDesktop ? 11.5 : 11.0;
    final statValueSize = isDesktop ? 18.0 : 13.5;
    final dividerHeight = isDesktop ? 42.0 : 26.0;
    final radius = isDesktop ? 24.0 : 20.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
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
                      colors: [
                        GreenhouseStyle.primaryDeep,
                        GreenhouseStyle.primary,
                      ],
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
                    GreenhouseStyle.primaryDeep.withValues(alpha: 0.88),
                    GreenhouseStyle.primary.withValues(alpha: 0.72),
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
                    Text(
                      'Under glass',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.warehouse_outlined,
                      size: isDesktop ? 22 : 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 8 : 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _fmtArea(summary.totalArea),
                      style: TextStyle(
                        fontSize: areaSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.8,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: isDesktop ? 10 : 4,
                      ),
                      child: Text(
                        'm²',
                        style: TextStyle(
                          fontSize: unitSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 22 : 18),
                Divider(
                  color: Colors.white.withValues(alpha: 0.2),
                  height: 1,
                ),
                SizedBox(height: isDesktop ? 18 : 14),
                Row(
                  children: [
                    _stat('Active', '${summary.active}', statLabelSize,
                        statValueSize),
                    _divider(dividerHeight),
                    _stat('Empty', '${summary.emptyCount}', statLabelSize,
                        statValueSize),
                    _divider(dividerHeight),
                    _stat('Plants', _fmtCount(summary.totalPlants),
                        statLabelSize, statValueSize),
                    _divider(dividerHeight),
                    _stat(
                      'Density',
                      GreenhouseStyle.densityLabel(summary.avgDensity),
                      statLabelSize,
                      statValueSize,
                    ),
                  ],
                ),
              ],
            ),
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
                color: Colors.white.withValues(alpha: 0.75),
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
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.2),
      );

  static String _fmtArea(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(0);

  static String _fmtCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
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
  final ({int all, int active, int empty}) counts;
  final ValueChanged<String> onChange;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('All', 'all', counts.all, GreenhouseStyle.primary),
      _chip('Active', 'active', counts.active, GreenhouseStyle.primaryDeep),
      _chip('Empty', 'empty', counts.empty, Colors.blueGrey),
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
// MOBILE greenhouse card
// ===========================================================================
class _GreenhouseCard extends ConsumerWidget {
  const _GreenhouseCard({required this.greenhouse});
  final Greenhouse greenhouse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = greenhouse.currentCrop.trim().isNotEmpty &&
        greenhouse.plantCount > 0;
    final accent =
        isActive ? GreenhouseStyle.primary : const Color(0xFF78909C);

    final density = GreenhouseStyle.density(
      plants: greenhouse.plantCount,
      size: greenhouse.size,
    );
    final densityColor = density != null
        ? GreenhouseStyle.densityColor(density)
        : Colors.blueGrey;

    final crops = ref.watch(cropsStreamProvider).value ?? const <Crop>[];
    final key = greenhouse.name.trim().toLowerCase();
    Crop? crop = crops
        .where((c) => c.location.trim().toLowerCase() == key)
        .firstOrNull;
    if (crop == null && greenhouse.currentCrop.trim().isNotEmpty) {
      final ck = greenhouse.currentCrop.trim().toLowerCase();
      crop = crops
          .where((c) => c.cropName.trim().toLowerCase() == ck)
          .firstOrNull;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? GreenhouseStyle.primary.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/greenhouses/${greenhouse.id}/detail'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.warehouse_outlined,
                        size: 20,
                        color: accent,
                      ),
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
                                  greenhouse.name.isEmpty
                                      ? '(unnamed greenhouse)'
                                      : greenhouse.name,
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
                              _statusPill(isActive, accent),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_fmtArea(greenhouse.size)} m²',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          size: 18,
                          color: Colors.black.withValues(alpha: 0.45)),
                      tooltip: 'Edit',
                      onPressed: () =>
                          context.push('/greenhouses/${greenhouse.id}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mini stats row
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        icon: Icons.square_foot_outlined,
                        value: '${_fmtArea(greenhouse.size)} m²',
                        label: 'Area',
                        color: const Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat(
                        icon: Icons.eco_outlined,
                        value: '${greenhouse.plantCount}',
                        label: 'Plants',
                        color: GreenhouseStyle.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat(
                        icon: Icons.density_medium_outlined,
                        value: density != null
                            ? density.toStringAsFixed(density < 10 ? 1 : 0)
                            : '—',
                        label: 'Density /m²',
                        color: densityColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Crop block
                if (crop != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CropStyle.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CropStyle.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: CropStyle.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.grass_outlined,
                            size: 17,
                            color: CropStyle.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'CURRENT CROP',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: CropStyle.primaryDeep,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _stageBadge(crop.stage),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                crop.cropName.isEmpty
                                    ? '(unnamed crop)'
                                    : crop.cropName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/crops/${crop!.id}/detail'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 30),
                          ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: CropStyle.primary,
                          ),
                          label: const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: CropStyle.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isActive) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grass_outlined,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            greenhouse.currentCrop,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 16,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Empty — no crop growing',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      'Tap card for full greenhouse details',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.black.withValues(alpha: 0.25),
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

  String _fmtArea(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(0);
}

// ===========================================================================
// DESKTOP greenhouse card — richer, denser, more visual
// ===========================================================================
class _DesktopGreenhouseCard extends ConsumerWidget {
  const _DesktopGreenhouseCard({required this.greenhouse});
  final Greenhouse greenhouse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = greenhouse.currentCrop.trim().isNotEmpty &&
        greenhouse.plantCount > 0;
    final accent =
        isActive ? GreenhouseStyle.primary : const Color(0xFF78909C);

    final density = GreenhouseStyle.density(
      plants: greenhouse.plantCount,
      size: greenhouse.size,
    );
    final densityColor = density != null
        ? GreenhouseStyle.densityColor(density)
        : Colors.blueGrey;

    final crops = ref.watch(cropsStreamProvider).value ?? const <Crop>[];
    final key = greenhouse.name.trim().toLowerCase();
    Crop? crop = crops
        .where((c) => c.location.trim().toLowerCase() == key)
        .firstOrNull;
    if (crop == null && greenhouse.currentCrop.trim().isNotEmpty) {
      final ck = greenhouse.currentCrop.trim().toLowerCase();
      crop = crops
          .where((c) => c.cropName.trim().toLowerCase() == ck)
          .firstOrNull;
    }

    final radius = BorderRadius.circular(20);

    return Container(
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: radius,
        border: Border.all(
          color: isActive
              ? GreenhouseStyle.primary.withValues(alpha: 0.22)
              : DPalette.hairline,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/greenhouses/${greenhouse.id}/detail'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: gradient icon + name + pill + menu
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
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.warehouse_outlined,
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greenhouse.name.isEmpty
                                ? '(unnamed greenhouse)'
                                : greenhouse.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DPalette.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _statusPill(isActive, accent),
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
                          context.push('/greenhouses/${greenhouse.id}');
                        }
                        if (value == 'open') {
                          context.push(
                            '/greenhouses/${greenhouse.id}/detail',
                          );
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
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Mini stats row
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        icon: Icons.square_foot_outlined,
                        value: '${_fmtArea(greenhouse.size)} m²',
                        label: 'Area',
                        color: const Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat(
                        icon: Icons.eco_outlined,
                        value: '${greenhouse.plantCount}',
                        label: 'Plants',
                        color: GreenhouseStyle.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat(
                        icon: Icons.density_medium_outlined,
                        value: density != null
                            ? density.toStringAsFixed(density < 10 ? 1 : 0)
                            : '—',
                        label: 'Density /m²',
                        color: densityColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Crop block / fallback
                if (crop != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CropStyle.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CropStyle.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: CropStyle.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.grass_outlined,
                            size: 17,
                            color: CropStyle.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'CURRENT CROP',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: CropStyle.primaryDeep,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _stageBadge(crop.stage),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                crop.cropName.isEmpty
                                    ? '(unnamed crop)'
                                    : crop.cropName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: CropStyle.primary,
                          ),
                          tooltip: 'View crop',
                          onPressed: () =>
                              context.push('/crops/${crop!.id}/detail'),
                        ),
                      ],
                    ),
                  )
                else if (isActive)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grass_outlined,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            greenhouse.currentCrop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 16,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Empty — no crop growing',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
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
                      'Click card for details',
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

  String _fmtArea(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(0);
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
                color: GreenhouseStyle.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warehouse_outlined,
                  size: 32, color: GreenhouseStyle.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No greenhouses yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your first greenhouse to track controlled-environment crops.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}