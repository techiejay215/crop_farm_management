import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/crops/providers/crop_provider.dart'
    show selectedFarmIdProvider;
import '../../features/farms/data/farm_model.dart';
import '../../features/farms/providers/farm_provider.dart';
import '../theme/app_theme.dart';

class ProfessionalAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final bool showLogo;
  final List<Widget>? extraActions;

  const ProfessionalAppBar({
    super.key,
    this.title,
    this.showLogo = true,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userDataProvider).value;
    final name = (userData?['name'] ?? 'User') as String;
    final photoUrl = userData?['photoUrl'] as String?;
    final role = (userData?['role'] ?? 'customer') as String;

    // Determine which farm is currently "in focus"
    final farms = ref.watch(farmsStreamProvider).value ?? [];
    final selectedFarmId = ref.watch(selectedFarmIdProvider);
    final displayedFarm = _pickFarm(farms, selectedFarmId);

    // Customer branding: show THEIR farm name + logo.
    // Admin / customer-without-farm: fall back to platform branding.
    final String appName;
    final String? logoUrl;
    if (role == 'customer' && displayedFarm != null) {
      appName = displayedFarm.farmName;
      logoUrl = displayedFarm.logoUrl;
    } else {
      appName = 'GreenHarvest';
      logoUrl = null;
    }

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 16,
      title: Row(
        children: [
          if (showLogo) ...[
            _logoMark(logoUrl),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title ?? appName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (title == null)
                  Text(
                    role == 'customer' && displayedFarm != null
                        ? 'Farm Management'
                        : 'Farm Management System',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (extraActions != null) ...extraActions!,
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new notifications')),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded,
                  size: 24, color: AppTheme.textPrimary),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _ProfileAvatar(
            name: name,
            photoUrl: photoUrl,
            role: role,
            farm: displayedFarm,
            onMenuTap: (value) =>
                _handleMenu(context, ref, value, displayedFarm, role),
          ),
        ),
      ],
    );
  }

  /// Pick the farm to display.
  /// Priority: selected farm → first farm → null.
  Farm? _pickFarm(List<Farm> farms, String? selectedId) {
    if (farms.isEmpty) return null;
    if (selectedId != null) {
      for (final f in farms) {
        if (f.id == selectedId) return f;
      }
    }
    return farms.first;
  }

  /// Renders the small rounded square logo mark.
  /// Shows the farm's logo image if available, else the default eco icon.
  Widget _logoMark(String? logoUrl) {
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(8),
        image: hasLogo
            ? DecorationImage(
                image: NetworkImage(logoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasLogo
          ? null
          : const Icon(Icons.eco, color: Colors.white, size: 20),
    );
  }

  void _handleMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
    Farm? farm,
    String role,
  ) {
    switch (value) {
      case 'profile':
        context.go('/settings');
        break;

      case 'farm_settings':
        if (role == 'admin') {
          // Admin manages the full list of farms
          context.go('/farms');
        } else if (farm != null) {
          // Customer edits their single assigned farm (name, logo, location)
          context.push('/farms/${farm.id}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No farm assigned yet. Contact your admin.'),
            ),
          );
        }
        break;

      case 'logout':
        ref.read(authRepositoryProvider).signOut();
        context.go('/login');
        break;
    }
  }
}

// =============================================================================
// PROFILE AVATAR + POPUP MENU
// =============================================================================
class _ProfileAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String role;
  final Farm? farm;
  final ValueChanged<String> onMenuTap;

  const _ProfileAvatar({
    required this.name,
    required this.photoUrl,
    required this.role,
    required this.farm,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    final isAdmin = role == 'admin';

    return PopupMenuButton<String>(
      tooltip: 'Profile',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      color: Colors.white,
      onSelected: onMenuTap,
      itemBuilder: (context) => [
        // Header
        PopupMenuItem<String>(
          enabled: false,
          height: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
              Text(
                isAdmin ? 'ADMINISTRATOR' : 'FARM OWNER',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),

        // Actions
        _menuItem('profile', Icons.person_outline, 'My Profile'),
        _menuItem(
          'farm_settings',
          isAdmin ? Icons.tune_outlined : Icons.edit_outlined,
          isAdmin ? 'Manage Farms' : 'Edit My Farm',
          enabled: isAdmin || farm != null,
        ),
        _menuItem(
          'users',
          Icons.group_outlined,
          'Users & Permissions',
          enabled: false,
        ),
        _menuItem(
          'notifications',
          Icons.notifications_none,
          'Notifications',
          enabled: false,
        ),
        _menuItem(
          'subscription',
          Icons.card_membership_outlined,
          'Subscription',
          enabled: false,
        ),

        // Logout
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 18, color: AppTheme.alertRed),
              SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(color: AppTheme.alertRed, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.lightGreen,
          border: Border.all(color: AppTheme.border),
          image: photoUrl != null && photoUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(photoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: (photoUrl == null || photoUrl!.isEmpty)
            ? Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              )
            : null,
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}