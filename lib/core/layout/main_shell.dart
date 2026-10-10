import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
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
        {
          'icon': Icons.dashboard_outlined,
          'label': 'Dashboard',
          'route': '/dashboard',
        },
        {
          'icon': Icons.manage_accounts_outlined,
          'label': 'Users',
          'route': '/admin/users',
        },
        {
          'icon': Icons.person_add_alt_1_outlined,
          'label': 'Register',
          'route': '/admin/register-customer',
        },
      ];
    }

    return [
      {
        'icon': Icons.dashboard_outlined,
        'label': 'Dashboard',
        'route': '/dashboard',
      },
      {
        'icon': Icons.agriculture_outlined,
        'label': 'Farms',
        'route': '/farms',
      },
      {
        'icon': Icons.grass_outlined,
        'label': 'Crops',
        'route': '/crops',
      },
      {
        'icon': Icons.warehouse_outlined,
        'label': 'Greenhouses',
        'route': '/greenhouses',
      },
      {
        'icon': Icons.agriculture,
        'label': 'Harvests',
        'route': '/harvests',
      },
      {
        'icon': Icons.shopping_cart_outlined,
        'label': 'Sales',
        'route': '/sales',
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'label': 'Expenses',
        'route': '/expenses',
      },
      {
        'icon': Icons.groups_outlined,
        'label': 'Labour',
        'route': '/labour',
      },
      {
        'icon': Icons.insert_chart_outlined,
        'label': 'Reports',
        'route': '/reports',
      },
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
    // Bottom-nav tabs replace the stack — intentional (tab-switch semantics).
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

    return ResponsiveLayout(
      // ==================== MOBILE ====================
      mobileScaffold: Scaffold(
        body: widget.child,
        bottomNavigationBar: _ProfessionalBottomNav(
          selectedIndex: _selectedIndex,
          onTap: _goTo,
          onMoreTap: () => _showMoreSheet(context, isAdmin, name, initials),
        ),
      ),

      // ==================== DESKTOP ====================
      desktopScaffold: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 240,
              backgroundColor: DPalette.brand,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _goTo,
              selectedIconTheme:
                  const IconThemeData(color: Colors.white, size: 22),
              unselectedIconTheme:
                  const IconThemeData(color: Colors.white70, size: 22),
              selectedLabelTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.eco,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'DANKA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.22),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        IconButton(
                          tooltip: 'Logout',
                          icon: const Icon(Icons.logout_rounded,
                              color: Colors.white70, size: 20),
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: items
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item['icon'] as IconData),
                        label: Text(item['label'] as String),
                      ))
                  .toList(),
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
// MORE SHEET
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
          // Capture the router BEFORE popping the sheet — the sheet's
          // BuildContext will be disposed the moment Navigator.pop runs.
          final router = GoRouter.of(context);
          final currentLocation =
              router.routerDelegate.currentConfiguration.uri.path;

          Navigator.pop(context);

          // Tapping the tile you're already on shouldn't stack a duplicate.
          if (currentLocation == route) return;

          // push (not go!) so the back button returns to wherever the user
          // was before opening the More sheet.
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

// ---- Dedicated logout tile (warm-gold alert family) ----
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
// BOTTOM NAV — each tab always shows its own colour
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
                          // Active = solid accent. Inactive = soft tint.
                          // Never grey — every tab keeps its identity.
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
                          // Colour the label too so inactive tabs
                          // read as coloured, not greyed-out.
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