import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
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
      ),
    );
  }
}

// ===========================================================================
// Header
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

// ===========================================================================
// Section label
// ===========================================================================
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

// ===========================================================================
// Report tile
// ===========================================================================
class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  /// Null = tile is decorative only. This app currently has every
  /// report wired up, so no tile should ever be null here.
  final String? route;

  @override
  Widget build(BuildContext context) {
    final enabled = route != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => context.push(route!) : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}