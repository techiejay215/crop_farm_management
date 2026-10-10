import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/widgets/dashboard_palette.dart';

class DankaBottomNav extends StatelessWidget {
  final String currentPath;
  const DankaBottomNav({super.key, required this.currentPath});

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      path: '/dashboard',
      color: DPalette.iconGreen,
      tint: DPalette.iconGreenTint,
    ),
    _NavItem(
      icon: Icons.agriculture_outlined,
      activeIcon: Icons.agriculture_rounded,
      label: 'Farms',
      path: '/farms',
      color: DPalette.iconOlive,
      tint: DPalette.iconOliveTint,
    ),
    _NavItem(
      icon: Icons.grass_outlined,
      activeIcon: Icons.grass_rounded,
      label: 'Crops',
      path: '/crops',
      color: DPalette.iconFresh,
      tint: DPalette.iconFreshTint,
    ),
    _NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'More',
      path: '/settings',
      color: DPalette.iconSlate,
      tint: DPalette.iconSlateTint,
    ),
  ];

  bool _isActive(String path) {
    if (path == '/dashboard') return currentPath == '/dashboard';
    return currentPath == path || currentPath.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DPalette.surface,
        border: Border(top: BorderSide(color: DPalette.hairline)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0B5D3B),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: _items.map((item) {
              final active = _isActive(item.path);
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  splashColor: item.tint.withValues(alpha: 0.5),
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: 42,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? item.color : item.tint,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color:
                                        item.color.withValues(alpha: 0.32),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          size: 19,
                          color: active ? Colors.white : item.color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          color: active ? item.color : DPalette.inkMuted,
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
  final String path;
  final Color color;
  final Color tint;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
    required this.color,
    required this.tint,
  });
}