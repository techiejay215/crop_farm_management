import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        return Scaffold(
          backgroundColor: isDesktop ? DPalette.canvas : null,
          appBar: isDesktop ? null : AppBar(title: const Text('Reports')),
          body: isDesktop ? _buildDesktop(context) : _buildMobile(context),
        );
      },
    );
  }

  // ===========================================================================
  // MOBILE (unchanged)
  // ===========================================================================
  Widget _buildMobile(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: const [
        _Header(),
        SizedBox(height: 20),
        _SectionLabel('Farm performance'),
        _ReportTile(
          icon: Icons.agriculture_outlined,
          title: 'Farm report',
          subtitle: 'Production, costs and revenue per farm',
          color: Color(0xFF2E7D32),
          route: '/reports/farm',
        ),
        _ReportTile(
          icon: Icons.grass_outlined,
          title: 'Crop report',
          subtitle: 'Profitability, yield and price per crop',
          color: Color(0xFF43A047),
          route: '/reports/crop',
        ),
        _ReportTile(
          icon: Icons.warehouse_outlined,
          title: 'Greenhouse report',
          subtitle: 'Profit, density and yield per m²',
          color: Color(0xFF00ACC1),
          route: '/reports/greenhouse',
        ),
        _ReportTile(
          icon: Icons.agriculture,
          title: 'Harvest report',
          subtitle: 'Yield, waste and grade quality over time',
          color: Color(0xFF00ACC1),
          route: '/reports/harvest',
        ),
        SizedBox(height: 20),
        _SectionLabel('Financial'),
        _ReportTile(
          icon: Icons.receipt_long_outlined,
          title: 'Expense report',
          subtitle: 'Spending breakdown, trends and top costs',
          color: Color(0xFFEF6C00),
          route: '/reports/expense',
        ),
        _ReportTile(
          icon: Icons.point_of_sale_outlined,
          title: 'Sales report',
          subtitle: 'Revenue, best sellers and top buyers',
          color: Color(0xFF1E88E5),
          route: '/reports/sales',
        ),
        _ReportTile(
          icon: Icons.groups_outlined,
          title: 'Labour report',
          subtitle: 'Wages, workers, tasks and outstanding payments',
          color: Color(0xFF7E57C2),
          route: '/reports/labour',
        ),
        _ReportTile(
          icon: Icons.account_balance_outlined,
          title: 'Financial summary',
          subtitle: 'Revenue, costs and net profit in one view',
          color: Color(0xFF1B5E20),
          route: '/reports/financial',
        ),
      ],
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Page header ----
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B5E20), AppTheme.primaryGreen],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.insights,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports & insights',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: DPalette.ink,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Understand where your farm makes and spends money.',
                          style: TextStyle(
                              fontSize: 14, color: DPalette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // ---- Farm performance section ----
              const _DesktopSectionHeader(
                icon: Icons.agriculture_outlined,
                title: 'Farm performance',
                subtitle: 'Production, crops, greenhouses and harvests',
                accent: Color(0xFF2E7D32),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 3.0,
                children: const [
                  _ReportTile(
                    compact: true,
                    icon: Icons.agriculture_outlined,
                    title: 'Farm report',
                    subtitle: 'Production, costs and revenue per farm',
                    color: Color(0xFF2E7D32),
                    route: '/reports/farm',
                  ),
                  _ReportTile(
                    compact: true,
                    icon: Icons.grass_outlined,
                    title: 'Crop report',
                    subtitle: 'Profitability, yield and price per crop',
                    color: Color(0xFF43A047),
                    route: '/reports/crop',
                  ),
                  _ReportTile(
                    compact: true,
                    icon: Icons.warehouse_outlined,
                    title: 'Greenhouse report',
                    subtitle: 'Profit, density and yield per m²',
                    color: Color(0xFF00ACC1),
                    route: '/reports/greenhouse',
                  ),
                  _ReportTile(
                    compact: true,
                    icon: Icons.agriculture,
                    title: 'Harvest report',
                    subtitle: 'Yield, waste and grade quality over time',
                    color: Color(0xFF00ACC1),
                    route: '/reports/harvest',
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // ---- Financial section ----
              const _DesktopSectionHeader(
                icon: Icons.account_balance_outlined,
                title: 'Financial',
                subtitle: 'Revenue, expenses and profit',
                accent: Color(0xFF1B5E20),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 3.0,
                children: const [
                  _ReportTile(
                    compact: true,
                    icon: Icons.receipt_long_outlined,
                    title: 'Expense report',
                    subtitle: 'Spending breakdown, trends and top costs',
                    color: Color(0xFFEF6C00),
                    route: '/reports/expense',
                  ),
                  _ReportTile(
                    compact: true,
                    icon: Icons.point_of_sale_outlined,
                    title: 'Sales report',
                    subtitle: 'Revenue, best sellers and top buyers',
                    color: Color(0xFF1E88E5),
                    route: '/reports/sales',
                  ),
                  _ReportTile(
                    compact: true,
                    icon: Icons.groups_outlined,
                    title: 'Labour report',
                    subtitle: 'Wages, workers, tasks and outstanding payments',
                    color: Color(0xFF7E57C2),
                    route: '/reports/labour',
                  ),
                  _ReportTile(
                    compact: true,
                    icon: Icons.account_balance_outlined,
                    title: 'Financial summary',
                    subtitle: 'Revenue, costs and net profit in one view',
                    color: Color(0xFF1B5E20),
                    route: '/reports/financial',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Header / section label / tile (unchanged)
// ===========================================================================
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1B5E20), AppTheme.primaryGreen],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insights, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports & insights',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Understand where your farm makes and spends money.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.black45,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DesktopSectionHeader extends StatelessWidget {
  const _DesktopSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DPalette.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: DPalette.inkMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.route,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? route;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = route != null;

    final pad = compact ? 12.0 : 14.0;
    final iconSize = compact ? 36.0 : 42.0;
    final innerIconSize = compact ? 18.0 : 20.0;
    final titleSize = compact ? 13.5 : 14.5;
    final subtitleSize = compact ? 11.0 : 12.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => context.push(route!) : null,
        child: Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: compact
                  ? color.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: compact
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: compact ? 0.20 : 0.12),
                      color.withValues(alpha: compact ? 0.10 : 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(compact ? 10 : 12),
                ),
                child: Icon(icon, size: innerIconSize, color: color),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: subtitleSize,
                        height: 1.3,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: compact ? 18 : 20,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}