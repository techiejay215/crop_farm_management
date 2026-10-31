import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../features/farms/providers/farm_provider.dart';
import '../../features/dashboard/widgets/dashboard_palette.dart' show DPalette;
import 'responsive_layout.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  List<Map<String, dynamic>> _buildNavItems({required bool isAdmin}) {
    if (isAdmin) {
      return [
        {'icon': Icons.space_dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
        {'icon': Icons.manage_accounts_rounded, 'label': 'Users', 'route': '/admin/users'},
        {'icon': Icons.person_add_alt_1_rounded, 'label': 'Register', 'route': '/admin/register-customer'},
        {'icon': Icons.settings_rounded, 'label': 'Settings', 'route': '/settings'},
      ];
    }

    return [
      {'icon': Icons.space_dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.agriculture_rounded, 'label': 'Farms', 'route': '/farms'},
      {'icon': Icons.grass_rounded, 'label': 'Crops', 'route': '/crops'},
      {'icon': Icons.warehouse_rounded, 'label': 'Greenhouses', 'route': '/greenhouses'},
      {'icon': Icons.eco_rounded, 'label': 'Harvests', 'route': '/harvests'},
      {'icon': Icons.shopping_cart_rounded, 'label': 'Sales', 'route': '/sales'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Expenses', 'route': '/expenses'},
      {'icon': Icons.groups_rounded, 'label': 'Labour', 'route': '/labour'},
      {'icon': Icons.insert_chart_rounded, 'label': 'Reports', 'route': '/reports'},
      {'icon': Icons.settings_rounded, 'label': 'Settings', 'route': '/settings'},
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final items = _buildNavItems(isAdmin: ref.read(isAdminProvider));
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i]['route'] as String)) {
        if (_selectedIndex != i) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = i);
          });
        }
        break;
      }
    }
  }

  void _goTo(int index) {
    final items = _buildNavItems(isAdmin: ref.read(isAdminProvider));
    setState(() => _selectedIndex = index);
    context.go(items[index]['route'] as String);
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final items = _buildNavItems(isAdmin: isAdmin);
    final userData = ref.watch(userDataProvider).value;
    final name = (userData?['name'] ?? 'User') as String;
    final initials = _initialsOf(name);

    // ── Dynamic Farm Data for Sidebar ──────────────────────────────────────
    final selectedFarmId = ref.watch(selectedFarmIdProvider);
    final farmsAsync = ref.watch(farmsStreamProvider);
    
    String activeFarmName = 'DANKA';
    String? activeFarmLogo;

    if (selectedFarmId != null && farmsAsync.hasValue) {
      for (final f in farmsAsync.value!) {
        try {
          if (f.id == selectedFarmId) {
            activeFarmName = f.farmName as String;
            // Safely extract logo URL (handles common model field names)
            final dynamic farmData = f;
            activeFarmLogo = farmData.logoUrl ?? farmData.imageUrl ?? farmData.photoUrl;
            break;
          }
        } catch (_) {}
      }
    }

    return ResponsiveLayout(
      // ==================== MOBILE (UNCHANGED) ====================
      mobileScaffold: Scaffold(
        body: widget.child,
        bottomNavigationBar: _ProfessionalBottomNav(
          selectedIndex: _selectedIndex,
          onTap: _goTo,
          onMoreTap: () => _showMoreSheet(context, isAdmin, name, initials),
        ),
      ),

      // ==================== DESKTOP (REDESIGNED) ====================
      desktopScaffold: Scaffold(
        backgroundColor: DPalette.canvas,
        body: Row(
          children: [
            _DesktopSidebar(
              items: items,
              selectedIndex: _selectedIndex,
              onTap: _goTo,
              name: name,
              initials: initials,
              onLogout: _logout,
              farmName: activeFarmName,
              farmLogo: activeFarmLogo,
            ),
            const VerticalDivider(
                thickness: 1, width: 1, color: DPalette.hairline),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  void _showMoreSheet(
    BuildContext context,
    bool isAdmin,
    String name,
    String initials,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _MoreSheet(
        isAdmin: isAdmin,
        name: name,
        initials: initials,
        onLogout: _logout,
      ),
    );
  }
}

// ===========================================================================
// DESKTOP SIDEBAR (Dynamic Farm Branding)
// ===========================================================================
class _DesktopSidebar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final String name;
  final String initials;
  final Future<void> Function() onLogout;
  final String farmName;
  final String? farmLogo;

  const _DesktopSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.name,
    required this.initials,
    required this.onLogout,
    required this.farmName,
    this.farmLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: DPalette.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dynamic Farm Brand Mark ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DPalette.brand.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DPalette.brand.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: (farmLogo != null && farmLogo!.isNotEmpty)
                        ? Image.network(
                            farmLogo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackLogo(),
                          )
                        : _fallbackLogo(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        farmName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: DPalette.brandDeep,
                          letterSpacing: 0.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Farm Management',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DPalette.inkMuted,
                          letterSpacing: 0.2,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: DPalette.hairline,
          ),
          const SizedBox(height: 14),

          // ── Navigation list ────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final selected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onTap(i),
                      borderRadius: BorderRadius.circular(10),
                      splashColor: DPalette.brand.withValues(alpha: 0.10),
                      highlightColor: Colors.transparent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: selected
                              ? DPalette.sidebarActive
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 19,
                              color: selected
                                  ? DPalette.brand
                                  : DPalette.inkSoft,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? DPalette.brandDeep
                                      : DPalette.inkSoft,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── User card / logout ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            child: Column(
              children: [
                Container(
                  height: 1,
                  color: DPalette.hairline,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DPalette.hairline),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: DPalette.sidebarActive,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: DPalette.brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: DPalette.ink,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onLogout,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: DPalette.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackLogo() {
    return Container(
      color: DPalette.sageSoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.eco_rounded,
        color: DPalette.brand,
        size: 22,
      ),
    );
  }
}

// ===========================================================================
// MORE SHEET (Unchanged for Mobile)
// ===========================================================================
class _MoreSheet extends StatelessWidget {
  final bool isAdmin;
  final String name;
  final String initials;
  final Future<void> Function() onLogout;

  const _MoreSheet({
    required this.isAdmin,
    required this.name,
    required this.initials,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final maxHeight = media.size.height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: DPalette.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DPalette.hairlineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: DPalette.iconGreenTint,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DPalette.iconGreen.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DPalette.iconGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: DPalette.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAdmin ? 'Administrator' : 'Farm Owner',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: DPalette.inkMuted,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: DPalette.inkMuted,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: DPalette.hairline),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + bottomInset,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 500;
                      final tileWidth = twoColumns
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isAdmin) ...[
                            _section(
                              'Administration',
                              [
                                const _MoreTile(
                                  label: 'User Management',
                                  icon: Icons.manage_accounts_outlined,
                                  route: '/admin/users',
                                  accent: DPalette.iconGreen,
                                  tint: DPalette.iconGreenTint,
                                ),
                                const _MoreTile(
                                  label: 'Register Customer',
                                  icon: Icons.person_add_alt_1_outlined,
                                  route: '/admin/register-customer',
                                  accent: DPalette.iconOlive,
                                  tint: DPalette.iconOliveTint,
                                ),
                              ],
                              tileWidth,
                            ),
                          ] else ...[
                            _section(
                              'Operations',
                              [
                                const _MoreTile(
                                  label: 'Greenhouses',
                                  icon: Icons.warehouse_outlined,
                                  route: '/greenhouses',
                                  accent: DPalette.iconFresh,
                                  tint: DPalette.iconFreshTint,
                                ),
                                const _MoreTile(
                                  label: 'Harvests',
                                  icon: Icons.agriculture_outlined,
                                  route: '/harvests',
                                  accent: DPalette.iconGold,
                                  tint: DPalette.iconGoldTint,
                                ),
                                const _MoreTile(
                                  label: 'Sales',
                                  icon: Icons.point_of_sale_outlined,
                                  route: '/sales',
                                  accent: DPalette.iconFresh,
                                  tint: DPalette.iconFreshTint,
                                ),
                              ],
                              tileWidth,
                            ),
                            const SizedBox(height: 20),
                            _section(
                              'Financial',
                              [
                                const _MoreTile(
                                  label: 'Expenses',
                                  icon:
                                      Icons.account_balance_wallet_outlined,
                                  route: '/expenses',
                                  accent: DPalette.iconGold,
                                  tint: DPalette.iconGoldTint,
                                ),
                                const _MoreTile(
                                  label: 'Labour',
                                  icon: Icons.groups_outlined,
                                  route: '/labour',
                                  accent: DPalette.iconEarth,
                                  tint: DPalette.iconEarthTint,
                                ),
                                const _MoreTile(
                                  label: 'Reports',
                                  icon: Icons.insights_outlined,
                                  route: '/reports',
                                  accent: DPalette.iconSlate,
                                  tint: DPalette.iconSlateTint,
                                ),
                              ],
                              tileWidth,
                            ),
                          ],
                          const SizedBox(height: 20),
                          _section(
                            'Account',
                            [
                              const _MoreTile(
                                label: 'Settings',
                                icon: Icons.settings_outlined,
                                route: '/settings',
                                accent: DPalette.iconSlate,
                                tint: DPalette.iconSlateTint,
                              ),
                            ],
                            tileWidth,
                          ),
                          const SizedBox(height: 16),
                          _LogoutTile(onTap: () async {
                            Navigator.pop(context);
                            await onLogout();
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles, double tileWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: DPalette.inkMuted,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in tiles) SizedBox(width: tileWidth, child: t),
          ],
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;
  final Color accent;
  final Color tint;

  const _MoreTile({
    required this.label,
    required this.icon,
    required this.route,
    required this.accent,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final router = GoRouter.of(context);
          final currentLocation =
              router.routerDelegate.currentConfiguration.uri.path;

          Navigator.pop(context);
          if (currentLocation == route) return;
          router.push(route);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: DPalette.surfaceTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.16),
              width: 1.1,
            ),
            boxShadow: DPalette.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DPalette.ink,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: accent.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: DPalette.alertTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DPalette.alertEdge),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DPalette.alert.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded,
                    size: 19, color: DPalette.alert),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DPalette.alert,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: DPalette.alert.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// BOTTOM NAV — UNCHANGED
// ===========================================================================
class _ProfessionalBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMoreTap;

  const _ProfessionalBottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final moreSelected = selectedIndex >= 3;

    final items = [
      const _NavItem(
        Icons.home_outlined,
        Icons.home_rounded,
        'Home',
        0,
        accent: DPalette.iconGreen,
        tint: DPalette.iconGreenTint,
      ),
      const _NavItem(
        Icons.agriculture_outlined,
        Icons.agriculture_rounded,
        'Farms',
        1,
        accent: DPalette.iconOlive,
        tint: DPalette.iconOliveTint,
      ),
      const _NavItem(
        Icons.grass_outlined,
        Icons.grass_rounded,
        'Crops',
        2,
        accent: DPalette.iconFresh,
        tint: DPalette.iconFreshTint,
      ),
      const _NavItem(
        Icons.grid_view_outlined,
        Icons.grid_view_rounded,
        'More',
        -1,
        accent: DPalette.iconSlate,
        tint: DPalette.iconSlateTint,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: DPalette.surface,
        border: Border(top: BorderSide(color: DPalette.hairline, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140B5D3B),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: items.map((item) {
              final selected = item.index == -1
                  ? moreSelected
                  : item.index == selectedIndex;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (item.index == -1) {
                      onMoreTap();
                    } else {
                      onTap(item.index);
                    }
                  },
                  splashColor: item.tint.withValues(alpha: 0.6),
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: 46,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? item.accent : item.tint,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color:
                                        item.accent.withValues(alpha: 0.32),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          selected ? item.activeIcon : item.icon,
                          size: 19,
                          color: selected ? Colors.white : item.accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: selected
                              ? item.accent
                              : item.accent.withValues(alpha: 0.75),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final Color accent;
  final Color tint;
  const _NavItem(
    this.icon,
    this.activeIcon,
    this.label,
    this.index, {
    required this.accent,
    required this.tint,
  });
}