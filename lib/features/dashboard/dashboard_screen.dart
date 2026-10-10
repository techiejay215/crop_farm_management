import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/providers/auth_provider.dart';
import '../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../farms/providers/farm_provider.dart';
import '../../core/widgets/professional_app_bar.dart';
import 'data/dashboard_stats.dart';
import 'providers/dashboard_provider.dart';
import 'widgets/dashboard_palette.dart';
import 'widgets/metric_card.dart';
import 'widgets/production_chart.dart';
import 'widgets/welcome_hero.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ChartRange _range = ChartRange.month;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final userData = ref.watch(userDataProvider).value;
    final farmsAsync = ref.watch(farmsStreamProvider);
    final selectedFarmId = ref.watch(selectedFarmIdProvider);

    final rawName = (userData?['name'] ?? 'User') as String;
    final name = rawName.isEmpty
        ? 'User'
        : rawName[0].toUpperCase() + rawName.substring(1);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      appBar: const ProfessionalAppBar(),
      body: RefreshIndicator(
        color: DPalette.brand,
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: statsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: DPalette.brand),
          ),
          error: (e, _) => _errorState(e),
          data: (stats) => LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final hPad = wide ? 24.0 : 16.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WelcomeHero(
                          greeting: _greetingText(),
                          name: name,
                          subtitle:
                              "Here's what's happening across your farms today.",
                          assetImage: 'assets/images/hero_crop.jpg',
                          networkImage:
                              'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
                          meta: [
                            HeroChip(
                              icon: Icons.agriculture_rounded,
                              label:
                                  '${stats.totalFarms} farm${stats.totalFarms == 1 ? '' : 's'}',
                            ),
                            HeroChip(
                              icon: Icons.grass_rounded,
                              label:
                                  '${stats.activeCrops} crop${stats.activeCrops == 1 ? '' : 's'}',
                            ),
                            HeroChip(
                              icon: Icons.scale_rounded,
                              label:
                                  '${_compact(stats.totalProductionKg)} kg',
                            ),
                          ],
                          selector: farmsAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (farms) => HeroSelectorContainer(
                              child: _farmSelector(farms, selectedFarmId),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ─── Your Farms ───────────────────────
                        _sectionHeader(
                          'Your Farms',
                          accent: DPalette.iconBlue,
                          trailing: 'At a glance',
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryMetricCard(
                                label: 'Farms',
                                value: '${stats.totalFarms}',
                                badge: 'LIVE',
                                icon: Icons.agriculture_outlined,
                                accent: DPalette.iconBlue,
                                accentTint: DPalette.iconBlueTint,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PrimaryMetricCard(
                                label: 'Crops',
                                value: '${stats.activeCrops}',
                                badge: 'GROW',
                                icon: Icons.grass_outlined,
                                accent: DPalette.iconOlive,
                                accentTint: DPalette.iconOliveTint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ─── Financial row ─────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: FinancialMetricCard(
                                label: 'Revenue',
                                value: 'KSh ${_compact(stats.totalRevenue)}',
                                accentColor: DPalette.iconTeal,
                                background: DPalette.iconTealTint
                                    .withValues(alpha: 0.35),
                                border: DPalette.iconTeal
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FinancialMetricCard(
                                label: 'Expenses',
                                value:
                                    'KSh ${_compact(stats.totalExpenses)}',
                                accentColor: DPalette.iconGold,
                                background: DPalette.iconGoldTint
                                    .withValues(alpha: 0.35),
                                border: DPalette.iconGold
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FinancialMetricCard(
                                label: 'Profit',
                                value: 'KSh ${_compact(stats.netProfit)}',
                                accentColor: stats.netProfit >= 0
                                    ? DPalette.iconGreen
                                    : DPalette.iconGold,
                                background: (stats.netProfit >= 0
                                        ? DPalette.iconGreenTint
                                        : DPalette.iconGoldTint)
                                    .withValues(alpha: 0.35),
                                border: (stats.netProfit >= 0
                                        ? DPalette.iconGreen
                                        : DPalette.iconGold)
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        _snapshotRow(stats),
                        const SizedBox(height: 18),

                        // ─── Shortcuts ────────────────────────
                        _quickActions(context, ref),
                        const SizedBox(height: 18),

                        ProductionChart(
                          data: stats.monthlyProduction,
                          range: _range,
                          onRangeChanged: (r) => setState(() => _range = r),
                        ),
                        const SizedBox(height: 18),

                        _recentActivity(stats),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ─── Farm selector ─────────────────────────────────────
  Widget _farmSelector(List<dynamic> farms, String? selectedFarmId) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: selectedFarmId,
        isDense: true,
        isExpanded: true,
        dropdownColor: DPalette.brandDeep,
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white,
          size: 20,
        ),
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.1,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text(
              'All Farms',
              style: TextStyle(color: Colors.white, fontSize: 13.5),
            ),
          ),
          ...farms.map(
            (f) => DropdownMenuItem<String?>(
              value: f.id as String,
              child: Text(
                f.farmName as String,
                style:
                    const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
          ),
        ],
        onChanged: (v) {
          ref.read(selectedFarmIdProvider.notifier).state = v;
          ref.invalidate(dashboardStatsProvider);
        },
      ),
    );
  }

  // ─── Shortcuts — single scrollable pill row ────────────
  Widget _quickActions(BuildContext context, WidgetRef ref) {
    final selectedFarmId = ref.watch(selectedFarmIdProvider);

    void requireFarm(VoidCallback action) {
      if (selectedFarmId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a farm first')),
        );
        return;
      }
      action();
    }

    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.add_business_outlined,
        label: 'New Farm',
        accent: DPalette.iconBlue,
        tint: DPalette.iconBlueTint,
        onTap: () => context.push('/farms/add'),
      ),
      _QuickAction(
        icon: Icons.grass_outlined,
        label: 'New Crop',
        accent: DPalette.iconOlive,
        tint: DPalette.iconOliveTint,
        onTap: () => requireFarm(() => context.push('/crops/add')),
      ),
      _QuickAction(
        icon: Icons.agriculture_outlined,
        label: 'Harvest',
        accent: DPalette.iconGold,
        tint: DPalette.iconGoldTint,
        onTap: () => requireFarm(() => context.push('/harvests/add')),
      ),
      _QuickAction(
        icon: Icons.attach_money_outlined,
        label: 'Sale',
        accent: DPalette.iconFresh,
        tint: DPalette.iconFreshTint,
        onTap: () => requireFarm(() => context.push('/sales/add')),
      ),
      _QuickAction(
        icon: Icons.people_alt_outlined,
        label: 'Labour',
        accent: DPalette.iconEarth,
        tint: DPalette.iconEarthTint,
        onTap: () => requireFarm(() => context.push('/labour/add')),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Shortcuts',
          accent: DPalette.iconGold,
          trailing: 'Tap to start',
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 4),
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _actionPill(actions[i]),
          ),
        ),
      ],
    );
  }

  Widget _actionPill(_QuickAction a) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: a.tint.withValues(alpha: 0.55),
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: a.accent.withValues(alpha: 0.18),
            ),
            boxShadow: DPalette.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration:
                    DPalette.iconChip(a.accent, a.tint, radius: 10),
                child: Icon(a.icon, size: 16, color: a.accent),
              ),
              const SizedBox(width: 9),
              Text(
                a.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DPalette.ink,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Snapshot row ──────────────────────────────────────
  Widget _snapshotRow(DashboardStats stats) {
    final items = <_Snapshot>[
      _Snapshot(
        icon: Icons.payments_outlined,
        label: 'WAGES OWED',
        value: 'KSh ${_compact(stats.pendingWages)}',
        accent: DPalette.iconBerry,
        tint: DPalette.iconBerryTint,
      ),
      _Snapshot(
        icon: Icons.percent_rounded,
        label: 'MARGIN',
        value: '${stats.profitMargin.toStringAsFixed(1)}%',
        accent: DPalette.iconPurple,
        tint: DPalette.iconPurpleTint,
      ),
      _Snapshot(
        icon: Icons.scale_outlined,
        label: 'YIELD / FARM',
        value: '${_compact(stats.avgYieldPerFarm)} kg',
        accent: DPalette.iconTeal,
        tint: DPalette.iconTealTint,
      ),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) => _snapshotPill(items[i]),
      ),
    );
  }

  Widget _snapshotPill(_Snapshot p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: DPalette.iconChip(p.accent, p.tint, radius: 10),
            child: Icon(p.icon, size: 14, color: p.accent),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                p.label,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: DPalette.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Recent activity ───────────────────────────────────
  Widget _recentActivity(DashboardStats stats) {
    final activities = <_Activity>[];

    for (final s in stats.recentSales.take(4)) {
      activities.add(
        _Activity(
          icon: Icons.receipt_long_outlined,
          accent: DPalette.iconFresh,
          tint: DPalette.iconFreshTint,
          title: 'Sale recorded',
          subtitle: '${s.cropName}  ·  KSh ${_compact(s.totalAmount)}',
          time: _timeAgo(s.date),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Recent',
          accent: DPalette.iconFresh,
          trailing: 'Latest first',
        ),
        Container(
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DPalette.hairline),
            boxShadow: DPalette.cardShadow,
          ),
          child: activities.isEmpty
              ? const Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                  child: Column(
                    children: [
                      _EmptyCircle(icon: Icons.history_rounded),
                      SizedBox(height: 12),
                      Text(
                        'No activity yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DPalette.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Record a sale or production to see updates here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: DPalette.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: List.generate(activities.length, (i) {
                    final a = activities[i];
                    return Column(
                      children: [
                        _activityRow(a),
                        if (i < activities.length - 1)
                          const Divider(
                            height: 1,
                            color: DPalette.hairline,
                            indent: 66,
                          ),
                      ],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _activityRow(_Activity a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: DPalette.iconChip(a.accent, a.tint, radius: 13),
            child: Icon(a.icon, size: 18, color: a.accent),
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
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DPalette.ink,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      a.time,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: DPalette.inkMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  a.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: DPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section header with colour ────────────────────────
  Widget _sectionHeader(String title,
      {required Color accent, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: DPalette.inkSoft,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: DPalette.inkFaint,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: DPalette.inkFaint,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Error state ───────────────────────────────────────
  Widget _errorState(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: DPalette.iconChip(
                DPalette.iconGold,
                DPalette.iconGoldTint,
                radius: 26,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DPalette.iconGold,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not load dashboard',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DPalette.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$e',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: DPalette.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => ref.invalidate(dashboardStatsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: DPalette.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────
  String _compact(double n) {
    if (n.abs() >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n.abs() >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toStringAsFixed(0);
  }

  String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}';
  }
}

// ---------------------------------------------------------------------------
// Internal models
// ---------------------------------------------------------------------------
class _Activity {
  final IconData icon;
  final Color accent;
  final Color tint;
  final String title;
  final String subtitle;
  final String time;

  _Activity({
    required this.icon,
    required this.accent,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;
  _QuickAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.tint,
    required this.onTap,
  });
}

class _Snapshot {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color tint;
  _Snapshot({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.tint,
  });
}

class _EmptyCircle extends StatelessWidget {
  final IconData icon;
  const _EmptyCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: DPalette.iconChip(
        DPalette.iconGreen,
        DPalette.iconGreenTint,
        radius: 26,
      ),
      child: Icon(icon, size: 22, color: DPalette.iconGreen),
    );
  }
}