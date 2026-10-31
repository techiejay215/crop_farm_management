import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart' show DPalette;
import '../data/admin_models.dart';
import '../providers/admin_providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) return _buildDesktop(context, ref);
        return _buildMobile(context, ref);
      },
    );
  }

  // ===========================================================================
  // MOBILE
  // ===========================================================================
  Widget _buildMobile(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersStreamProvider);
    final filter = ref.watch(userStatusFilterProvider);
    final query = ref.watch(userSearchQueryProvider).toLowerCase();

    return Scaffold(
      backgroundColor: DPalette.canvas,
      appBar: AppBar(
        backgroundColor: DPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'User Management',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: DPalette.ink,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, color: DPalette.inkSoft),
              onPressed: () => ref.invalidate(allUsersStreamProvider),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _searchField(ref),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _chip(ref, 'All', UserStatusFilter.all, filter),
                const SizedBox(width: 8),
                _chip(ref, 'Active', UserStatusFilter.active, filter),
                const SizedBox(width: 8),
                _chip(ref, 'Paused', UserStatusFilter.paused, filter),
              ],
            ),
          ),

          // List
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: DPalette.leaf),
              ),
              error: (e, _) => _errorState(e),
              data: (users) {
                final filtered = _applyFilters(users, filter, query);
                if (filtered.isEmpty) return const _EmptyState();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _mobileUserCard(context, ref, filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersStreamProvider);
    final filter = ref.watch(userStatusFilterProvider);
    final query = ref.watch(userSearchQueryProvider).toLowerCase();

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: usersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DPalette.leaf),
        ),
        error: (e, _) => _errorState(e),
        data: (users) {
          final filtered = _applyFilters(users, filter, query);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _desktopHeader(context, ref),
                    const SizedBox(height: 24),

                    // Stats
                    _desktopStats(users),
                    const SizedBox(height: 24),

                    // Filter toolbar
                    _desktopToolbar(
                      ref,
                      filter,
                      total: users.length,
                      filtered: filtered.length,
                    ),
                    const SizedBox(height: 20),

                    // Grid
                    if (filtered.isEmpty)
                      const SizedBox(height: 400, child: _EmptyState())
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 178,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _desktopUserCard(
                          context,
                          ref,
                          filtered[i],
                        ),
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

  Widget _desktopHeader(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Review, pause and manage every account on the platform.',
                style: TextStyle(fontSize: 14, color: DPalette.inkMuted),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 240),
          child: _searchField(ref, dense: true),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: DPalette.inkSoft),
          onPressed: () => ref.invalidate(allUsersStreamProvider),
        ),
      ],
    );
  }

  Widget _desktopStats(List<AdminUser> users) {
    final total = users.length;
    final active = users.where((u) => u.isActive).length;
    final paused = users.where((u) => u.isPaused).length;
    final admins = users.where((u) => u.isAdmin).length;

    return Row(
      children: [
        Expanded(
          child: _userStatCard(
            icon: Icons.people_alt_outlined,
            label: 'Total users',
            value: '$total',
            accent: DPalette.leaf,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _userStatCard(
            icon: Icons.check_circle_outline,
            label: 'Active',
            value: '$active',
            accent: DPalette.profit,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _userStatCard(
            icon: Icons.pause_circle_outline,
            label: 'Paused',
            value: '$paused',
            accent: DPalette.expense,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _userStatCard(
            icon: Icons.shield_outlined,
            label: 'Admins',
            value: '$admins',
            accent: DPalette.revenue,
          ),
        ),
      ],
    );
  }

  Widget _userStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DPalette.hairline),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: DPalette.ink,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: DPalette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopToolbar(
    WidgetRef ref,
    UserStatusFilter filter, {
    required int total,
    required int filtered,
  }) {
    return Row(
      children: [
        _chip(ref, 'All', UserStatusFilter.all, filter),
        const SizedBox(width: 8),
        _chip(ref, 'Active', UserStatusFilter.active, filter),
        const SizedBox(width: 8),
        _chip(ref, 'Paused', UserStatusFilter.paused, filter),
        const Spacer(),
        Text(
          filtered == total ? '$total users' : '$filtered of $total users',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: DPalette.inkMuted,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DESKTOP USER CARD
  // ===========================================================================
  Widget _desktopUserCard(
    BuildContext context,
    WidgetRef ref,
    AdminUser u,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(u, size: 46, radius: 13, fontSize: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: DPalette.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (u.isAdmin) ...[
                          const SizedBox(width: 6),
                          _adminBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      u.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DPalette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _statusBadge(u),
            ],
          ),

          const Spacer(),

          // Divider
          const Divider(height: 1, color: DPalette.hairline),
          const SizedBox(height: 10),

          // Footer row
          Row(
            children: [
              _statusPill(
                icon: Icons.agriculture_outlined,
                label:
                    '${u.farmCount} farm${u.farmCount == 1 ? '' : 's'}',
                color: DPalette.inkMuted,
              ),
              const Spacer(),
              if (u.isCustomer)
                _menuButton(context, ref, u),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE USER CARD
  // ===========================================================================
  Widget _mobileUserCard(
    BuildContext context,
    WidgetRef ref,
    AdminUser u,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.softShadow(),
      ),
      child: Row(
        children: [
          _avatar(u, size: 46, radius: 13, fontSize: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DPalette.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (u.isAdmin) ...[
                      const SizedBox(width: 6),
                      _adminBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  u.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DPalette.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statusBadge(u),
                    if (u.isCustomer) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: DPalette.inkFaint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${u.farmCount} farm${u.farmCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: DPalette.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (u.isCustomer) _menuButton(context, ref, u),
        ],
      ),
    );
  }

  // ===========================================================================
  // SHARED BITS
  // ===========================================================================
  Widget _searchField(WidgetRef ref, {bool dense = false}) {
    return TextField(
      onChanged: (v) =>
          ref.read(userSearchQueryProvider.notifier).state = v,
      style: const TextStyle(
        fontSize: 14,
        color: DPalette.ink,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Search by name or email',
        hintStyle: const TextStyle(
          color: DPalette.inkFaint,
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: DPalette.inkFaint,
        ),
        isDense: dense,
        contentPadding: EdgeInsets.symmetric(
          vertical: dense ? 12 : 14,
          horizontal: 12,
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
          borderSide: const BorderSide(color: DPalette.leaf, width: 1.5),
        ),
      ),
    );
  }

  Widget _chip(
    WidgetRef ref,
    String label,
    UserStatusFilter value,
    UserStatusFilter current,
  ) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          ref.read(userStatusFilterProvider.notifier).state = value,
      selectedColor: DPalette.leaf,
      backgroundColor: DPalette.surface,
      labelStyle: TextStyle(
        color: selected ? Colors.white : DPalette.ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? DPalette.leaf : DPalette.hairline,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _avatar(
    AdminUser u, {
    required double size,
    required double radius,
    required double fontSize,
  }) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: u.isAdmin
              ? [
                  DPalette.inkSoft.withValues(alpha: 0.20),
                  DPalette.inkSoft.withValues(alpha: 0.08),
                ]
              : [
                  DPalette.leaf.withValues(alpha: 0.22),
                  DPalette.leaf.withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        u.initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: u.isAdmin ? DPalette.inkSoft : DPalette.leaf,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _adminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DPalette.chipNeutral,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'ADMIN',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: DPalette.inkSoft,
          letterSpacing: 0.5,
        ),
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

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _menuButton(
    BuildContext context,
    WidgetRef ref,
    AdminUser u,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(
        Icons.more_vert_rounded,
        color: DPalette.inkMuted,
        size: 20,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: DPalette.hairline),
      ),
      color: Colors.white,
      onSelected: (v) => _handleAction(context, ref, u, v),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: u.isActive ? 'pause' : 'resume',
          child: Row(
            children: [
              Icon(
                u.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                size: 18,
                color: DPalette.ink,
              ),
              const SizedBox(width: 10),
              Text(
                u.isActive ? 'Pause account' : 'Resume account',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: DPalette.ink,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: DPalette.alert),
              SizedBox(width: 10),
              Text(
                'Delete user',
                style: TextStyle(
                  fontSize: 13.5,
                  color: DPalette.alert,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<AdminUser> _applyFilters(
    List<AdminUser> users,
    UserStatusFilter filter,
    String query,
  ) {
    var filtered = users;
    if (filter == UserStatusFilter.active) {
      filtered = filtered.where((u) => u.isActive).toList();
    } else if (filter == UserStatusFilter.paused) {
      filtered = filtered.where((u) => u.isPaused).toList();
    }
    if (query.isNotEmpty) {
      filtered = filtered
          .where((u) =>
              u.name.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  Widget _errorState(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Error: $e',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: DPalette.inkMuted,
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    AdminUser u,
    String action,
  ) async {
    final actions = ref.read(adminActionsProvider);

    if (action == 'pause') {
      final confirmed = await _confirm(
        context,
        title: 'Pause ${u.name}?',
        message:
            'The customer will not be able to sign in until you resume their account. Their data is preserved.',
        confirmLabel: 'Pause account',
        destructive: false,
      );
      if (!confirmed) return;
      await actions.pauseUser(u.uid);
      if (context.mounted) _toast(context, '${u.name} has been paused.');
    } else if (action == 'resume') {
      await actions.resumeUser(u.uid);
      if (context.mounted) _toast(context, '${u.name} can sign in again.');
    } else if (action == 'delete') {
      final confirmed = await _confirm(
        context,
        title: 'Delete ${u.name}?',
        message:
            'This permanently deletes the customer and ALL their farms, crops, harvests, sales, and expenses. This cannot be undone.',
        confirmLabel: 'Delete permanently',
        destructive: true,
      );
      if (!confirmed) return;
      await actions.deleteUserAndData(u.uid);
      if (context.mounted) _toast(context, '${u.name} has been deleted.');
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required bool destructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: DPalette.ink,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: DPalette.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DPalette.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? DPalette.alert : DPalette.leaf,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DPalette.chipGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 26, color: DPalette.leaf),
            ),
            const SizedBox(height: 14),
            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DPalette.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your filters or search query.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: DPalette.inkMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}