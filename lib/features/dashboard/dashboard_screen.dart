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

    // Determine if desktop to conditionally hide the app bar
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      backgroundColor: DPalette.canvas,
      // AppBar only for mobile. Desktop handles profile in the header.
      appBar: isDesktop ? null : const ProfessionalAppBar(),
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
              if (constraints.maxWidth >= 1100) {
                return _buildDesktopLayout(
                  context, ref, stats, userData, farmsAsync, selectedFarmId, name,
                );
              }
              return _buildMobileLayout(
                context, ref, stats, userData, farmsAsync, selectedFarmId, name,
              );
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats,
    Map<String, dynamic>? userData,
    AsyncValue<List<dynamic>> farmsAsync,
    String? selectedFarmId,
    String name,
  ) {
    String farmName = 'All Your Farms';
    String? farmImageUrl;

    if (selectedFarmId != null && farmsAsync.hasValue) {
      for (final f in farmsAsync.value!) {
        try {
          if (f.id == selectedFarmId) {
            farmName = f.farmName as String;
            // Grab the image/logo URL to use as the banner background
            final dynamic farmData = f;
            farmImageUrl = farmData.logoUrl ?? farmData.imageUrl ?? farmData.photoUrl;
            break;
          }
        } catch (_) {}
      }
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesktopHeader(context, name, userData),
          const SizedBox(height: 28),

          // ── KPI row ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  title: 'Total Farms',
                  value: '${stats.totalFarms}',
                  trendText: 'Active this month',
                  icon: Icons.agriculture_rounded,
                  watermark: Icons.cottage_rounded,
                  iconColor: DPalette.kpiGreenIcon,
                  iconBg: DPalette.kpiGreenBg,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: KpiCard(
                  title: 'Active Crops',
                  value: '${stats.activeCrops}',
                  trendText: 'Growing',
                  icon: Icons.eco_rounded,
                  watermark: Icons.local_florist_rounded,
                  iconColor: DPalette.kpiGreenIcon,
                  iconBg: DPalette.kpiGreenBg,
                  trendColor: DPalette.inkMuted,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: KpiCard(
                  title: 'Revenue',
                  value: 'KSh ${_compact(stats.totalRevenue)}',
                  trendText: 'Sales income',
                  icon: Icons.account_balance_wallet_rounded,
                  watermark: Icons.bar_chart_rounded,
                  iconColor: DPalette.kpiBlueIcon,
                  iconBg: DPalette.kpiBlueBg,
                  trendColor: DPalette.kpiGreenIcon,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: KpiCard(
                  title: 'Net Profit',
                  value: 'KSh ${_compact(stats.netProfit)}',
                  trendText: stats.netProfit >= 0 ? 'In profit' : 'In loss',
                  icon: Icons.savings_rounded,
                  watermark: Icons.trending_up_rounded,
                  iconColor: stats.netProfit >= 0
                      ? DPalette.kpiGreenIcon
                      : DPalette.kpiGoldIcon,
                  iconBg: stats.netProfit >= 0
                      ? DPalette.kpiGreenBg
                      : DPalette.kpiGoldBg,
                  trendColor: stats.netProfit >= 0
                      ? DPalette.kpiGreenIcon
                      : DPalette.iconGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Main body ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _buildFarmBanner(context, ref, stats, farmsAsync, selectedFarmId, farmName, farmImageUrl),
                    const SizedBox(height: 24),
                    ProductionChart(
                      data: stats.monthlyProduction,
                      range: _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                      lineMode: true,
                    ),
                    const SizedBox(height: 24),
                    _buildDesktopRecentActivity(stats),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildDesktopQuickActions(context, ref),
                    const SizedBox(height: 24),
                    _buildDesktopSnapshots(stats),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Desktop header (Greeting + Search + Profile) ─────────────────────────
  Widget _buildDesktopHeader(BuildContext context, String name, Map<String, dynamic>? userData) {
    final photoUrl = userData?['photoUrl'] as String?;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greetingText()}, $name 👋',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Here's your farm's performance overview.",
                style: TextStyle(
                  fontSize: 14,
                  color: DPalette.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatDate(),
                style: const TextStyle(
                  fontSize: 13,
                  color: DPalette.inkFaint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        
        // Search Box
        Container(
          width: 260,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DPalette.hairline),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Search anything...',
              hintStyle: TextStyle(color: DPalette.inkFaint, fontSize: 13.5),
              prefixIcon:
                  Icon(Icons.search, color: DPalette.inkFaint, size: 19),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Notification
        GestureDetector(
          onTap: () => context.push('/reports'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: DPalette.hairline),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    color: DPalette.inkMuted, size: 20),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE15B3A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Text(
                    '4',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Profile (Clickable)
        GestureDetector(
          onTap: () => context.push('/settings'),
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: DPalette.hairline),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: ClipOval(
                    child: (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initialAvatar(name),
                            loadingBuilder: (c, child, p) =>
                                p == null ? child : _initialAvatar(name),
                          )
                        : _initialAvatar(name),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: DPalette.inkMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _initialAvatar(String name) {
    final letter = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      color: DPalette.iconGreenTint,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: DPalette.iconGreen,
        ),
      ),
    );
  }

  // ── Farm banner (Dynamic Background Image) ───────────────────────────────
  Widget _buildFarmBanner(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats,
    AsyncValue<List<dynamic>> farmsAsync,
    String? selectedFarmId,
    String farmName,
    String? farmImageUrl,
  ) {
    final farmCount = stats.totalFarms;
    final cropCount = stats.activeCrops;
    final production = _compact(stats.totalProductionKg);

    // Use the selected farm's uploaded image as background if it exists
    final ImageProvider bgImage = (farmImageUrl != null && farmImageUrl.isNotEmpty)
        ? NetworkImage(farmImageUrl)
        : const AssetImage('assets/images/hero_crop.jpg') as ImageProvider;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: bgImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(
                'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration:
                      const BoxDecoration(gradient: DPalette.heroGradient),
                ),
              ),
            ),
            // Left-to-right legibility gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF052014).withValues(alpha: 0.88),
                    const Color(0xFF052014).withValues(alpha: 0.55),
                    const Color(0xFF052014).withValues(alpha: 0.10),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Bottom vignette
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF000000).withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
            
            // Farm Selector (Top Right inside the image)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: SizedBox(
                  width: 180,
                  child: farmsAsync.when(
                    loading: () => const SizedBox(
                      height: 30,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox(height: 30),
                    data: (farms) => _farmSelector(farms, selectedFarmId, ref),
                  ),
                ),
              ),
            ),

            // Bottom content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco_rounded,
                            size: 11, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'FARM STATUS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    farmName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$farmCount farm${farmCount == 1 ? "" : "s"}  ·  '
                    '$cropCount crop${cropCount == 1 ? "" : "s"}  ·  '
                    '$production kg produced',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          if (selectedFarmId != null) {
                            context.push('/farms/$selectedFarmId');
                          } else {
                            context.push('/farms');
                          }
                        },
                        icon: const Icon(Icons.arrow_forward_rounded,
                            size: 14),
                        label: const Text(
                          'View Farm Details',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────────────────
  Widget _buildDesktopQuickActions(BuildContext context, WidgetRef ref) {
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: DPalette.iconChip(
                  DPalette.brand,
                  DPalette.iconGreenTint,
                  radius: 8,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: DPalette.brand,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DPalette.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDesktopActionTile(
            Icons.add_business_rounded,
            'New Farm',
            'Register a new farm',
            DPalette.iconBlue,
            DPalette.iconBlueTint,
            () => context.push('/farms/add'),
          ),
          const SizedBox(height: 10),
          _buildDesktopActionTile(
            Icons.grass_rounded,
            'New Crop',
            'Add a crop to a farm',
            DPalette.iconOlive,
            DPalette.iconOliveTint,
            () => requireFarm(() => context.push('/crops/add')),
          ),
          const SizedBox(height: 10),
          _buildDesktopActionTile(
            Icons.agriculture_rounded,
            'Harvest',
            'Record a harvest',
            DPalette.iconGold,
            DPalette.iconGoldTint,
            () => requireFarm(() => context.push('/harvests/add')),
          ),
          const SizedBox(height: 10),
          _buildDesktopActionTile(
            Icons.attach_money_rounded,
            'Sale',
            'Record a sale',
            DPalette.iconFresh,
            DPalette.iconFreshTint,
            () => requireFarm(() => context.push('/sales/add')),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActionTile(
    IconData icon,
    String label,
    String subtitle,
    Color accent,
    Color tint,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: tint.withValues(alpha: 0.5),
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: DPalette.surfaceTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: accent, size: 18),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: DPalette.ink,
                        letterSpacing: -0.1,
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
                Icons.chevron_right_rounded,
                size: 18,
                color: accent.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── At a Glance (Snapshots) ────────────────────────────────────────────────
  Widget _buildDesktopSnapshots(DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: DPalette.iconChip(
                  DPalette.iconPurple,
                  DPalette.iconPurpleTint,
                  radius: 8,
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: DPalette.iconPurple,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'At a Glance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DPalette.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDesktopSnapshotItem(
            Icons.payments_rounded,
            'Wages Owed',
            'KSh ${_compact(stats.pendingWages)}',
            DPalette.iconBerry,
            DPalette.iconBerryTint,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: DPalette.hairline),
          ),
          _buildDesktopSnapshotItem(
            Icons.percent_rounded,
            'Margin',
            '${stats.profitMargin.toStringAsFixed(1)}%',
            DPalette.iconPurple,
            DPalette.iconPurpleTint,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: DPalette.hairline),
          ),
          _buildDesktopSnapshotItem(
            Icons.scale_rounded,
            'Yield / Farm',
            '${_compact(stats.avgYieldPerFarm)} kg',
            DPalette.iconTeal,
            DPalette.iconTealTint,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSnapshotItem(
    IconData icon,
    String label,
    String value,
    Color accent,
    Color tint,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint,
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: accent, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: DPalette.inkSoft,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: DPalette.ink,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  // ── Recent Activity (desktop) ──────────────────────────────────────────────
  Widget _buildDesktopRecentActivity(DashboardStats stats) {
    final activities = <_Activity>[];
    for (final s in stats.recentSales.take(5)) {
      activities.add(
        _Activity(
          icon: Icons.receipt_long_rounded,
          accent: DPalette.iconFresh,
          tint: DPalette.iconFreshTint,
          title: 'Sale recorded',
          subtitle: '${s.cropName} · KSh ${_compact(s.totalAmount)}',
          time: _timeAgo(s.date),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: DPalette.iconChip(
                  DPalette.iconFresh,
                  DPalette.iconFreshTint,
                  radius: 8,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: DPalette.iconFresh,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DPalette.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              const Text(
                'Latest first',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: DPalette.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: DPalette.inkMuted, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: List.generate(activities.length, (i) {
                final a = activities[i];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: a.tint,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: a.accent.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Icon(a.icon, size: 16, color: a.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
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
                                const SizedBox(height: 2),
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
                          Text(
                            a.time,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: DPalette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < activities.length - 1)
                      const Divider(
                        height: 1,
                        color: DPalette.hairline,
                        indent: 48,
                      ),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT (unchanged)
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats,
    Map<String, dynamic>? userData,
    AsyncValue<List<dynamic>> farmsAsync,
    String? selectedFarmId,
    String name,
  ) {
    final hPad = 16.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 40 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WelcomeHero(
                greeting: _greetingText(),
                name: name,
                subtitle: "Here's what's happening across your farms today.",
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
                    label: '${_compact(stats.totalProductionKg)} kg',
                  ),
                ],
                selector: farmsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (farms) => HeroSelectorContainer(
                    child: _farmSelector(farms, selectedFarmId, ref),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _sectionHeader('Your Farms',
                  accent: DPalette.iconBlue, trailing: 'At a glance'),
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
              Row(
                children: [
                  Expanded(
                    child: FinancialMetricCard(
                      label: 'Revenue',
                      value: 'KSh ${_compact(stats.totalRevenue)}',
                      accentColor: DPalette.iconTeal,
                      background:
                          DPalette.iconTealTint.withValues(alpha: 0.35),
                      border: DPalette.iconTeal.withValues(alpha: 0.22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FinancialMetricCard(
                      label: 'Expenses',
                      value: 'KSh ${_compact(stats.totalExpenses)}',
                      accentColor: DPalette.iconGold,
                      background:
                          DPalette.iconGoldTint.withValues(alpha: 0.35),
                      border: DPalette.iconGold.withValues(alpha: 0.22),
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
  }

  // ─── Shared Helpers & Mobile Widgets ──────────────────────────────────────
  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate() {
    final now = DateTime.now();
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _farmSelector(List<dynamic> farms, String? selectedFarmId, WidgetRef ref) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: selectedFarmId,
        isDense: true,
        isExpanded: true,
        dropdownColor: DPalette.brandDeep,
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Colors.white, size: 20),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 13.5),
            ),
          ),
          ...farms.map(
            (f) => DropdownMenuItem<String?>(
              value: f.id as String,
              child: Text(
                f.farmName as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
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
        _sectionHeader('Shortcuts',
            accent: DPalette.iconGold, trailing: 'Tap to start'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _actionPill(actions[i]),
                ],
              ],
            ),
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
            border: Border.all(color: a.accent.withValues(alpha: 0.18)),
            boxShadow: DPalette.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: DPalette.iconChip(a.accent, a.tint, radius: 10),
                child: Icon(a.icon, size: 16, color: a.accent),
              ),
              const SizedBox(width: 9),
              Text(
                a.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 9),
              _snapshotPill(items[i]),
            ],
          ],
        ),
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
        mainAxisSize: MainAxisSize.min,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Widget _recentActivity(DashboardStats stats) {
    final activities = <_Activity>[];
    for (final s in stats.recentSales.take(4)) {
      activities.add(_Activity(
        icon: Icons.receipt_long_outlined,
        accent: DPalette.iconFresh,
        tint: DPalette.iconFreshTint,
        title: 'Sale recorded',
        subtitle: '${s.cropName}  ·  KSh ${_compact(s.totalAmount)}',
        time: _timeAgo(s.date),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent',
            accent: DPalette.iconFresh, trailing: 'Latest first'),
        Container(
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DPalette.hairline),
            boxShadow: DPalette.cardShadow,
          ),
          child: activities.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28, horizontal: 24),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: DPalette.iconChip(
                                    a.accent, a.tint,
                                    radius: 13),
                                child:
                                    Icon(a.icon, size: 18, color: a.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                          maxLines: 1,
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
                        ),
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
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: DPalette.inkSoft,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      trailing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: DPalette.inkFaint,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded,
                      size: 14, color: DPalette.inkFaint),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
                  DPalette.iconGold, DPalette.iconGoldTint,
                  radius: 26),
              child: const Icon(Icons.error_outline_rounded,
                  color: DPalette.iconGold, size: 24),
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not load dashboard',
              textAlign: TextAlign.center,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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

  String _compact(double n) {
    if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
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

// ─── Internal Models ───────────────────────────────────
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