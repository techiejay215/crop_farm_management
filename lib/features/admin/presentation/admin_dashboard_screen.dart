import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/dashboard_palette.dart' show DPalette;
import '../data/admin_models.dart';
import '../providers/admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final userData = ref.watch(userDataProvider).value;
    final adminName = (userData?['name'] ?? 'Administrator') as String;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        return Scaffold(
          backgroundColor: DPalette.canvas,
          body: RefreshIndicator(
            color: DPalette.leaf,
            onRefresh: () async => ref.invalidate(adminStatsProvider),
            child: statsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: DPalette.leaf),
              ),
              error: (e, _) => _errorState(ref, e),
              data: (stats) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: isDesktop
                    ? const EdgeInsets.fromLTRB(32, 24, 32, 32)
                    : const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: isDesktop
                        ? _buildDesktop(context, ref, stats, adminName)
                        : _buildMobile(context, stats, adminName),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // MOBILE
  // ===========================================================================
  Widget _buildMobile(
    BuildContext context,
    AdminStats stats,
    String adminName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(adminName, stats),
        const SizedBox(height: 24),
        _sectionHeader('Platform Overview'),
        _statsGrid(stats),
        const SizedBox(height: 28),
        _sectionHeader('Quick Actions'),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Register Customer',
                subtitle: 'Add a new farm owner',
                accent: DPalette.leaf,
                chip: DPalette.chipGreen,
                onTap: () => context.push('/admin/register-customer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.manage_accounts_outlined,
                label: 'Manage Users',
                subtitle: 'Pause · Resume · Delete',
                accent: DPalette.revenue,
                chip: DPalette.chipBlue,
                onTap: () => context.push('/admin/users'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader('Recent Registrations'),
            if (stats.recentUsers.isNotEmpty)
              TextButton(
                onPressed: () => context.push('/admin/users'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: const Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DPalette.leaf,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: DPalette.leaf),
                  ],
                ),
              ),
          ],
        ),
        _recentUsersList(stats),
      ],
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(
    BuildContext context,
    WidgetRef ref,
    AdminStats stats,
    String adminName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Page header ----
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: DPalette.ink,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Platform overview & user management.',
                    style: TextStyle(
                      fontSize: 14,
                      color: DPalette.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            _desktopIconButton(
              icon: Icons.person_add_alt_1_outlined,
              tooltip: 'Register customer',
              onTap: () => context.push('/admin/register-customer'),
            ),
            const SizedBox(width: 8),
            _desktopIconButton(
              icon: Icons.manage_accounts_outlined,
              tooltip: 'Manage users',
              onTap: () => context.push('/admin/users'),
            ),
            const SizedBox(width: 8),
            _desktopIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: () => ref.invalidate(adminStatsProvider),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ---- Hero ----
        _hero(adminName, stats, isDesktop: true),
        const SizedBox(height: 28),

        // ---- Stats ----
        _sectionHeader('Platform Overview'),
        _statsGrid(stats, isDesktop: true),
        const SizedBox(height: 28),

        // ---- Actions | Recent users ----
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick actions (left, narrower)
              SizedBox(
                width: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeader('Quick Actions'),
                    _actionCard(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Register Customer',
                      subtitle: 'Add a new farm owner to the platform',
                      accent: DPalette.leaf,
                      chip: DPalette.chipGreen,
                      onTap: () => context.push('/admin/register-customer'),
                    ),
                    const SizedBox(height: 12),
                    _actionCard(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Manage Users',
                      subtitle: 'Pause · Resume · Delete accounts',
                      accent: DPalette.revenue,
                      chip: DPalette.chipBlue,
                      onTap: () => context.push('/admin/users'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Recent users (right, wider)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionHeader('Recent Registrations'),
                        if (stats.recentUsers.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => context.push('/admin/users'),
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: DPalette.leaf,
                            ),
                            label: const Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: DPalette.leaf,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                    Expanded(child: _recentUsersList(stats)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: DPalette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DPalette.hairline),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 20, color: DPalette.inkSoft),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO — enriched with avatar
  // ===========================================================================
  Widget _hero(
    String name,
    AdminStats stats, {
    bool isDesktop = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF14532D),
            Color(0xFF2F855A),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14532D).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 11, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'ADMINISTRATOR',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isDesktop ? 16 : 14),
                Text(
                  'Welcome back, $name',
                  style: TextStyle(
                    fontSize: isDesktop ? 26 : 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You have ${stats.totalUsers} registered users across ${stats.totalFarms} farms.',
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _adminAvatar(name, size: isDesktop ? 68 : 56),
        ],
      ),
    );
  }

  Widget _adminAvatar(String name, {required double size}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: Text(
        _initialsFor(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ===========================================================================
  // STATS GRID
  // ===========================================================================
  Widget _statsGrid(AdminStats stats, {bool isDesktop = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = isDesktop || constraints.maxWidth >= 600;
        final perRow = isWide ? 4 : 2;
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (perRow - 1) * spacing) / perRow;

        final cards = [
          _StatCard(
            label: 'Total Users',
            value: '${stats.totalUsers}',
            icon: Icons.people_alt_outlined,
            accent: DPalette.leaf,
            chip: DPalette.chipGreen,
          ),
          _StatCard(
            label: 'Active',
            value: '${stats.activeUsers}',
            icon: Icons.check_circle_outline,
            accent: DPalette.profit,
            chip: DPalette.profitTint,
          ),
          _StatCard(
            label: 'Paused',
            value: '${stats.pausedUsers}',
            icon: Icons.pause_circle_outline,
            accent: DPalette.expense,
            chip: DPalette.expenseTint,
          ),
          _StatCard(
            label: 'Farms',
            value: '${stats.totalFarms}',
            icon: Icons.agriculture_outlined,
            accent: DPalette.revenue,
            chip: DPalette.revenueTint,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }

  // ===========================================================================
  // ACTION CARD — richer with gradient chip + chevron
  // ===========================================================================
  Widget _actionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color accent,
    required Color chip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DPalette.hairline),
            boxShadow: DPalette.softShadow(),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: DPalette.ink,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: DPalette.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: DPalette.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // RECENT USERS
  // ===========================================================================
  Widget _recentUsersList(AdminStats stats) {
    return Container(
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.softShadow(),
      ),
      child: stats.recentUsers.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  _EmptyChip(icon: Icons.group_outlined),
                  SizedBox(height: 14),
                  Text(
                    'No users yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DPalette.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Register your first customer to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: DPalette.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: List.generate(
                stats.recentUsers.length,
                (i) {
                  final u = stats.recentUsers[i];
                  return Column(
                    children: [
                      _userRow(u),
                      if (i < stats.recentUsers.length - 1)
                        const Divider(
                          height: 1,
                          color: DPalette.hairline,
                          indent: 68,
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _userRow(AdminUser u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: u.isAdmin
                    ? [
                        DPalette.inkSoft.withValues(alpha: 0.20),
                        DPalette.inkSoft.withValues(alpha: 0.10),
                      ]
                    : [
                        DPalette.leaf.withValues(alpha: 0.22),
                        DPalette.leaf.withValues(alpha: 0.10),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              u.initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: u.isAdmin ? DPalette.inkSoft : DPalette.leaf,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DPalette.ink,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  u.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: DPalette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(u),
        ],
      ),
    );
  }

  Widget _statusBadge(AdminUser u) {
    final isPaused = u.isPaused;
    final color = isPaused ? DPalette.expense : DPalette.profit;
    final tint = isPaused ? DPalette.expenseTint : DPalette.profitTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isPaused ? 'PAUSED' : 'ACTIVE',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ===========================================================================
  // MISC
  // ===========================================================================
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: DPalette.inkMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  Widget _errorState(WidgetRef ref, Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DPalette.alertTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: DPalette.alert, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load admin data',
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminStatsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: DPalette.leaf,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small stat card — richer icon chip + accent hairline
// ---------------------------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color chip;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DPalette.hairline),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
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
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: DPalette.ink,
                letterSpacing: -0.6,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: DPalette.inkMuted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChip extends StatelessWidget {
  final IconData icon;
  const _EmptyChip({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DPalette.chipGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 24, color: DPalette.leaf),
    );
  }
}