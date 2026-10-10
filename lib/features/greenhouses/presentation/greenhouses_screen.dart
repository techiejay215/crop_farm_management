import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
              // ---- HERO with background image ----
              _Hero(summary: summary),
              const SizedBox(height: 16),

              // ---- Filters ----
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
}

// ===========================================================================
// HERO with background image
// ===========================================================================
class _Hero extends StatelessWidget {
  const _Hero({required this.summary});
  final GreenhouseSummary summary;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Background image
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
          // Tint overlay
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
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Under glass',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.warehouse_outlined,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _fmtArea(summary.totalArea),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'm²',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(
                  color: Colors.white.withValues(alpha: 0.2),
                  height: 1,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('Active', '${summary.active}'),
                    _divider(),
                    _stat('Empty', '${summary.emptyCount}'),
                    _divider(),
                    _stat('Plants', _fmtCount(summary.totalPlants)),
                    _divider(),
                    _stat(
                      'Density',
                      GreenhouseStyle.densityLabel(summary.avgDensity),
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

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.75),
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
// Filter chips
// ===========================================================================
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.counts,
    required this.onChange,
  });

  final String current;
  final ({int all, int active, int empty}) counts;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', 'all', counts.all, GreenhouseStyle.primary),
          const SizedBox(width: 8),
          _chip('Active', 'active', counts.active, GreenhouseStyle.primaryDeep),
          const SizedBox(width: 8),
          _chip('Empty', 'empty', counts.empty, Colors.blueGrey),
        ],
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
// Greenhouse card — shows the current crop with a link to its details
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
    final densityColor = GreenhouseStyle.densityColor(density);

    // Find the crop grown in this greenhouse.
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                // ---- Header row ----
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              '${_fmtArea(greenhouse.size)} m²',
                              '${greenhouse.plantCount} plants',
                              if (density != null)
                                GreenhouseStyle.densityLabel(density),
                            ].join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

                // ---- Crop block ----
                const SizedBox(height: 12),
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
                              const Text(
                                'CURRENT CROP',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: CropStyle.primaryDeep,
                                  letterSpacing: 1.1,
                                ),
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
                              const SizedBox(height: 2),
                              Text(
                                CropStyle.stageLabel(crop.stage),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black.withValues(alpha: 0.55),
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
                  // Has currentCrop text but no matching crop document.
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
                  // Empty greenhouse
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

                // ---- Footer hint ----
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
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