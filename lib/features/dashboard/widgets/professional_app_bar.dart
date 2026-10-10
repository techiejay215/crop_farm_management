import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/widgets/dashboard_palette.dart';

class ProfessionalAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;

  const ProfessionalAppBar({super.key, this.title});

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userDataProvider).value;
    final name = (userData?['name'] ?? 'User') as String;
    final photoUrl = userData?['photoUrl'] as String?;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,

      // ─── Grid + soft gradient background ──────────
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DPalette.sageSoft,
              DPalette.surface,
              DPalette.surface,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(
            color: Color(0x0F0B5D3B),
            spacing: 16,
          ),
        ),
      ),

      title: Row(
        children: [
          // ─── Brand logo (photo) ─────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DPalette.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: DPalette.brand.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: DPalette.brand.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/danka_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: DPalette.sageSoft,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.eco_rounded,
                    color: DPalette.brand,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'DANKA',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: DPalette.inkMuted,
                    letterSpacing: 2.2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title ?? 'Farm Management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.4,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ─── Notification bell (gold chip) ─────────
          GestureDetector(
            onTap: () => context.push('/reports'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: DPalette.iconChip(
                    DPalette.iconGold,
                    DPalette.iconGoldTint,
                    radius: 12,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 19,
                    color: DPalette.iconGold,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE15B3A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DPalette.surface,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ─── Profile avatar ─────────────────────────
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [DPalette.brandMid, DPalette.brandDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: DPalette.brand.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: DPalette.surface,
                ),
                child: ClipOval(
                  child: (photoUrl != null && photoUrl.isNotEmpty)
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initial(name),
                          loadingBuilder: (c, child, p) =>
                              p == null ? child : _initial(name),
                        )
                      : _initial(name),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(String name) {
    final letter =
        name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      color: DPalette.sageSoft,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: DPalette.brand,
        ),
      ),
    );
  }
}

// ─── Faint grid painter used behind the app bar ────────
class _GridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  const _GridPainter({required this.color, this.spacing = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.color != color || old.spacing != spacing;
}