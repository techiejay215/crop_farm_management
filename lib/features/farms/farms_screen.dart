import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/widgets/dashboard_palette.dart';
import '../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import 'data/farm_model.dart';
import 'data/farm_style.dart';
import 'providers/farm_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _rXl = 24.0;
const _rLg = 20.0;
const _rMd = 16.0;
const _rSm = 12.0;

List<BoxShadow> _soft(Color c, {double a = 0.06}) => [
      BoxShadow(
        color: c.withValues(alpha: a),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];

class FarmsScreen extends ConsumerStatefulWidget {
  const FarmsScreen({super.key});

  @override
  ConsumerState<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends ConsumerState<FarmsScreen> {
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
      ref.read(farmSearchProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmsStreamProvider);
    final summary = ref.watch(farmSummaryProvider);
    final filter = ref.watch(farmFilterProvider);
    final filtered = ref.watch(filteredFarmsProvider);
    final counts = ref.watch(farmCountsProvider);
    final selectedId = ref.watch(selectedFarmIdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) {
          return _buildDesktopLayout(
            context,
            farmsAsync,
            summary,
            filter,
            filtered,
            counts,
            selectedId,
          );
        }
        return _buildMobileLayout(
          context,
          farmsAsync,
          summary,
          filter,
          filtered,
          counts,
          selectedId,
        );
      },
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    AsyncValue<List<Farm>> farmsAsync,
    FarmSummary summary,
    String filter,
    List<Farm> filtered,
    ({int all, int main, int rented}) counts,
    String? selectedId,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search name, location, landlord…',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(farmSearchProvider.notifier).state = v,
              )
            : const Text('Farms'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Farm report',
            onPressed: () => context.push('/reports/farm'),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Register customer',
            onPressed: () => context.push('/admin/register-customer'),
          ),
        ],
      ),
      body: farmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 18),
              _FilterRow(
                current: filter,
                counts: counts,
                onChange: (v) =>
                    ref.read(farmFilterProvider.notifier).state = v,
              ),
              const SizedBox(height: 12),
              ..._farmList(filtered, selectedId),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farms/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Farm',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
    );
  }

  List<Widget> _farmList(List<Farm> farms, String? selectedId) {
    if (farms.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 56),
          child: Center(
            child: Text(
              'No farms match your filters.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ];
    }

    return farms
        .map((f) => _FarmCard(farm: f, isActive: f.id == selectedId))
        .toList();
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(
    BuildContext context,
    AsyncValue<List<Farm>> farmsAsync,
    FarmSummary summary,
    String filter,
    List<Farm> filtered,
    ({int all, int main, int rented}) counts,
    String? selectedId,
  ) {
    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: farmsAsync.when(
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
                    _FilterRow(
                      current: filter,
                      counts: counts,
                      isDesktop: true,
                      onChange: (v) =>
                          ref.read(farmFilterProvider.notifier).state = v,
                    ),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: Text(
                            'No farms match your filters.',
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
                          maxCrossAxisExtent: 440,
                          mainAxisExtent: 260,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final f = filtered[index];
                          return _DesktopFarmCard(
                            farm: f,
                            isActive: f.id == selectedId,
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
                'Farms',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage all your land, main and rented.',
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
              hintText: 'Search farms...',
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
                ref.read(farmSearchProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(
            Icons.insights_outlined,
            color: DPalette.inkMuted,
          ),
          tooltip: 'Farm report',
          onPressed: () => context.push('/reports/farm'),
        ),
        IconButton(
          icon: const Icon(
            Icons.person_add_alt_1_outlined,
            color: DPalette.inkMuted,
          ),
          tooltip: 'Register customer',
          onPressed: () => context.push('/admin/register-customer'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/farms/add'),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Add Farm',
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
// Shared card bits
// ===========================================================================
Widget _farmStatusPill(bool isActive, Color accent) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      isActive ? 'ACTIVE' : 'FARM',
      style: TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: accent,
      ),
    ),
  );
}

Widget _farmMiniStat({
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
// Summary hero — with background photo (adaptive)
// ===========================================================================
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, this.isDesktop = false});
  final FarmSummary summary;
  final bool isDesktop;

  static const String _bgAsset = 'assets/images/hero_crop.jpg';

  @override
  Widget build(BuildContext context) {
    final padding = isDesktop
        ? const EdgeInsets.fromLTRB(32, 28, 32, 26)
        : const EdgeInsets.fromLTRB(22, 22, 22, 20);
    final acreageSize = isDesktop ? 64.0 : 42.0;
    final unitSize = isDesktop ? 18.0 : 15.0;
    final statLabelSize = isDesktop ? 11.0 : 9.5;
    final statValueSize = isDesktop ? 20.0 : 15.0;
    final dividerHeight = isDesktop ? 42.0 : 30.0;
    final iconSize = isDesktop ? 24.0 : 20.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_rXl),
        boxShadow: [
          BoxShadow(
            color: FarmStyle.primary.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _bgAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stack) {
                debugPrint('🖼️ HERO ASSET ERROR: $error');
                return Container(color: FarmStyle.primary);
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    FarmStyle.primary.withValues(alpha: 0.42),
                    FarmStyle.primary.withValues(alpha: 0.06),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.landscape_outlined,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Your land',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.spa_outlined,
                      size: iconSize,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 20 : 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      summary.totalAcreage.toStringAsFixed(
                        summary.totalAcreage ==
                                summary.totalAcreage.roundToDouble()
                            ? 0
                            : 1,
                      ),
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
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 22 : 20),
                Divider(
                  color: Colors.white.withValues(alpha: 0.20),
                  height: 1,
                ),
                SizedBox(height: isDesktop ? 18 : 16),
                Row(
                  children: [
                    _stat(
                      'Farms',
                      '${summary.totalFarms}',
                      statLabelSize,
                      statValueSize,
                    ),
                    _divider(dividerHeight),
                    _stat(
                      'Main',
                      '${summary.mainFarms}',
                      statLabelSize,
                      statValueSize,
                    ),
                    _divider(dividerHeight),
                    _stat(
                      'Rented',
                      '${summary.rentedFarms}',
                      statLabelSize,
                      statValueSize,
                    ),
                    _divider(dividerHeight),
                    _stat(
                      'Crops',
                      '${summary.totalCrops}',
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
              label.toUpperCase(),
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );

  Widget _divider(double height) => Container(
        width: 1,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.20),
      );
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
  final ({int all, int main, int rented}) counts;
  final ValueChanged<String> onChange;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('All', 'all', counts.all, FarmStyle.primary),
      _chip('Main', 'main', counts.main, FarmStyle.main),
      _chip('Rented', 'rented', counts.rented, FarmStyle.rented),
    ];

    if (isDesktop) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return SizedBox(
      height: 38,
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
              color: selected
                  ? color
                  : Colors.black.withValues(alpha: 0.07),
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
// MOBILE FARM CARD — richer icon, status pill, tighter layout
// ===========================================================================
class _FarmCard extends ConsumerWidget {
  const _FarmCard({required this.farm, required this.isActive});

  final Farm farm;
  final bool isActive;

  String get _initial {
    final n = farm.farmName.trim();
    if (n.isEmpty) return '?';
    return n.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = FarmStyle.typeColor(farm.type);
    final radius = BorderRadius.circular(_rMd);
    final hasLogo = (farm.logoUrl ?? '').isNotEmpty;

    return Dismissible(
      key: ValueKey(farm.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete farm?'),
          content: Text(
            '"${farm.farmName}" will be removed. Its crops, harvests, sales and '
            'expenses will remain in the database but will no longer be reachable '
            'from the app.',
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
          ref.read(farmRepositoryProvider).deleteFarm(farm.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: radius,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              ref.read(selectedFarmIdProvider.notifier).state = farm.id;
              context.push('/farms/${farm.id}');
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: isActive
                      ? FarmStyle.primary.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.05),
                  width: isActive ? 1.4 : 1,
                ),
                boxShadow: _soft(
                  isActive ? FarmStyle.primary : Colors.black,
                  a: isActive ? 0.06 : 0.035,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: hasLogo
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  typeColor.withValues(alpha: 0.24),
                                  typeColor.withValues(alpha: 0.10),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(14),
                        image: hasLogo
                            ? DecorationImage(
                                image: NetworkImage(farm.logoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: hasLogo
                          ? null
                          : Text(
                              _initial,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: typeColor,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  farm.farmName.isEmpty
                                      ? '(unnamed farm)'
                                      : farm.farmName,
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
                              _farmStatusPill(isActive, FarmStyle.primary),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 12,
                                  color: Colors.black.withValues(alpha: 0.45)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  farm.location.isEmpty
                                      ? 'No location'
                                      : farm.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Colors.black.withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_fmtAcreage(farm.acreage)} ac',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: FarmStyle.acreage,
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
                                icon: FarmStyle.typeIcon(farm.type),
                                label: FarmStyle.typeLabel(farm.type),
                                color: typeColor,
                              ),
                              _badge(
                                icon: Icons.grass_outlined,
                                label:
                                    '${farm.cropCount} crop${farm.cropCount == 1 ? '' : 's'}',
                                color: AppTheme.primaryGreen,
                              ),
                              if (farm.type == 'rented' &&
                                  farm.rentalCost != null &&
                                  farm.rentalCost! > 0)
                                _badge(
                                  icon: Icons.payments_outlined,
                                  label:
                                      'KSh ${_fmtMoney(farm.rentalCost!)}/${FarmStyle.rentalPeriodLabel(farm.rentalPeriod ?? 'monthly')}',
                                  color: FarmStyle.rented,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 22, color: Colors.black.withValues(alpha: 0.28)),
                  ],
                ),
              ),
            ),
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
              letterSpacing: 0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtAcreage(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  String _fmtMoney(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ===========================================================================
// DESKTOP FARM CARD — mini stats row + status pill + gradient icon
// ===========================================================================
class _DesktopFarmCard extends ConsumerWidget {
  const _DesktopFarmCard({required this.farm, required this.isActive});

  final Farm farm;
  final bool isActive;

  String get _initial {
    final n = farm.farmName.trim();
    if (n.isEmpty) return '?';
    return n.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = FarmStyle.typeColor(farm.type);
    final radius = BorderRadius.circular(20);
    final hasLogo = (farm.logoUrl ?? '').isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: radius,
        border: Border.all(
          color: isActive
              ? FarmStyle.primary.withValues(alpha: 0.28)
              : DPalette.hairline,
          width: isActive ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? FarmStyle.primary : Colors.black)
                .withValues(alpha: isActive ? 0.10 : 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            ref.read(selectedFarmIdProvider.notifier).state = farm.id;
            context.push('/farms/${farm.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: hasLogo
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  typeColor.withValues(alpha: 0.26),
                                  typeColor.withValues(alpha: 0.10),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(14),
                        image: hasLogo
                            ? DecorationImage(
                                image: NetworkImage(farm.logoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: hasLogo
                          ? null
                          : Text(
                              _initial,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: typeColor,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  farm.farmName.isEmpty
                                      ? '(unnamed farm)'
                                      : farm.farmName,
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
                              _farmStatusPill(isActive, FarmStyle.primary),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: DPalette.inkMuted,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  farm.location.isEmpty
                                      ? 'No location'
                                      : farm.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: DPalette.inkMuted,
                                  ),
                                ),
                              ),
                            ],
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
                        if (value == 'open') {
                          ref.read(selectedFarmIdProvider.notifier).state =
                              farm.id;
                          context.push('/farms/${farm.id}');
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
                              Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.red,
                              ),
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
                const SizedBox(height: 14),

                // Mini stats
                Row(
                  children: [
                    Expanded(
                      child: _farmMiniStat(
                        icon: Icons.square_foot_outlined,
                        value: '${_fmtAcreage(farm.acreage)} ac',
                        label: 'Acreage',
                        color: FarmStyle.acreage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _farmMiniStat(
                        icon: Icons.grass_outlined,
                        value: '${farm.cropCount}',
                        label: 'Crops',
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _farmMiniStat(
                        icon: FarmStyle.typeIcon(farm.type),
                        value: FarmStyle.typeLabel(farm.type),
                        label: 'Type',
                        color: typeColor,
                      ),
                    ),
                  ],
                ),

                const Spacer(),
                const Divider(color: DPalette.hairline, height: 1),
                const SizedBox(height: 12),

                // Footer badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge(
                      icon: FarmStyle.typeIcon(farm.type),
                      label: FarmStyle.typeLabel(farm.type),
                      color: typeColor,
                    ),
                    _badge(
                      icon: Icons.grass_outlined,
                      label:
                          '${farm.cropCount} crop${farm.cropCount == 1 ? '' : 's'}',
                      color: AppTheme.primaryGreen,
                    ),
                    if (farm.type == 'rented' &&
                        farm.rentalCost != null &&
                        farm.rentalCost! > 0)
                      _badge(
                        icon: Icons.payments_outlined,
                        label:
                            'KSh ${_fmtMoney(farm.rentalCost!)}/${FarmStyle.rentalPeriodLabel(farm.rentalPeriod ?? 'monthly')}',
                        color: FarmStyle.rented,
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
              letterSpacing: 0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtAcreage(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  String _fmtMoney(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete farm?'),
        content: Text(
          '"${farm.farmName}" will be removed. Its crops, harvests, sales and '
          'expenses will remain in the database but will no longer be reachable '
          'from the app.',
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
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(farmRepositoryProvider).deleteFarm(farm.id);
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
                color: FarmStyle.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.agriculture_outlined,
                  size: 38, color: FarmStyle.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No farms yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first farm to start tracking\ncrops, harvests and sales.',
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