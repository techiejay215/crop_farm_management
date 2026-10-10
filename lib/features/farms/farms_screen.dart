import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import 'data/farm_model.dart';
import 'data/farm_style.dart';
import 'providers/farm_provider.dart';

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

    return Scaffold(
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
            icon: const Icon(Icons.person_add),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 16),
              _FilterRow(
                current: filter,
                counts: counts,
                onChange: (v) =>
                    ref.read(farmFilterProvider.notifier).state = v,
              ),
              const SizedBox(height: 8),
              ..._farmList(filtered, selectedId),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farms/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Farm'),
      ),
    );
  }

  List<Widget> _farmList(List<Farm> farms, String? selectedId) {
    if (farms.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              'No farms match your filters.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
      ];
    }

    return farms
        .map((f) => _FarmCard(
              farm: f,
              isActive: f.id == selectedId,
            ))
        .toList();
  }
}

// ===========================================================================
// Summary hero — with background photo
// ===========================================================================
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final FarmSummary summary;

  /// Photo lives at assets/images/hero_crop.jpg
  static const String _bgAsset = 'assets/images/hero_crop.jpg';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FarmStyle.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1 ── the photo fills the card
          Positioned.fill(
            child: Image.asset(
              _bgAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stack) {
                debugPrint('🖼️ HERO ASSET ERROR: $error');
                return Container(color: Colors.red);
              },
            ),
          ),

          // 2 ── light dark scrim for text readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          // 3 ── subtle green brand tint
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FarmStyle.primary.withValues(alpha: 0.22),
              ),
            ),
          ),

          // 4 ── content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Your land',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.landscape_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'acres',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(
                  color: Colors.white.withValues(alpha: 0.25),
                  height: 1,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('Farms', '${summary.totalFarms}'),
                    _divider(),
                    _stat('Main', '${summary.mainFarms}'),
                    _divider(),
                    _stat('Rented', '${summary.rentedFarms}'),
                    _divider(),
                    _stat('Crops', '${summary.totalCrops}'),
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
                color: Colors.white.withValues(alpha: 0.85),
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
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.25),
      );
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
  final ({int all, int main, int rented}) counts;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', 'all', counts.all, FarmStyle.primary),
          const SizedBox(width: 8),
          _chip('Main', 'main', counts.main, FarmStyle.main),
          const SizedBox(width: 8),
          _chip('Rented', 'rented', counts.rented, FarmStyle.rented),
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
// Farm card
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
    final radius = BorderRadius.circular(14);
    final hasLogo = (farm.logoUrl ?? '').isNotEmpty;

    return Dismissible(
      key: ValueKey(farm.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
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
          border: Border.all(
            color: isActive
                ? FarmStyle.primary.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.05),
            width: isActive ? 1.4 : 1,
          ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasLogo
                          ? null
                          : typeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
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
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                farm.farmName.isEmpty
                                    ? '(unnamed farm)'
                                    : farm.farmName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FarmStyle.primary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: FarmStyle.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
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
                                fontWeight: FontWeight.w600,
                                color: FarmStyle.acreage,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _badge(
                              icon: FarmStyle.typeIcon(farm.type),
                              label: FarmStyle.typeLabel(farm.type),
                              color: typeColor,
                            ),
                            const SizedBox(width: 6),
                            _badge(
                              icon: Icons.grass_outlined,
                              label:
                                  '${farm.cropCount} crop${farm.cropCount == 1 ? '' : 's'}',
                              color: AppTheme.primaryGreen,
                            ),
                            if (farm.type == 'rented' &&
                                farm.rentalCost != null &&
                                farm.rentalCost! > 0) ...[
                              const SizedBox(width: 6),
                              _badge(
                                icon: Icons.payments_outlined,
                                label:
                                    'KSh ${_fmtMoney(farm.rentalCost!)}/${FarmStyle.rentalPeriodLabel(farm.rentalPeriod ?? 'monthly')}',
                                color: FarmStyle.rented,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right,
                      size: 20, color: Colors.black.withValues(alpha: 0.3)),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
                color: FarmStyle.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.agriculture_outlined,
                  size: 32, color: FarmStyle.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No farms yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your first farm to start tracking crops, harvests and sales.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}