import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/expense_format.dart';
import '../data/sale_model.dart';
import '../data/sale_style.dart';
import '../providers/sale_provider.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchCtrl.clear();
      ref.read(saleSearchProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);

    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales')),
        body: const Center(
          child: Text('Select a farm first from the Farms tab.'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) return _buildDesktopLayout(context, farmId);
        return _buildMobileLayout(context, farmId);
      },
    );
  }

  // ===========================================================================
  // MOBILE LAYOUT (unchanged)
  // ===========================================================================
  Widget _buildMobileLayout(BuildContext context, String farmId) {
    final salesAsync = ref.watch(salesStreamProvider);
    final summary = ref.watch(salesSummaryProvider);
    final filter = ref.watch(saleFilterProvider);
    final filtered = ref.watch(filteredSalesProvider);
    final counts = ref.watch(saleCountsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search buyer, crop, location…',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(saleSearchProvider.notifier).state = v,
              )
            : const Text('Sales'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Sales report',
            onPressed: () => context.push('/reports/sales'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Record sale',
            onPressed: () => context.push('/sales/add'),
          ),
        ],
      ),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _SalesHero(summary: summary),
              const SizedBox(height: 16),
              if (summary.hasPending) ...[
                _PendingBanner(
                  amount: summary.pendingAmount,
                  count: summary.pendingCount,
                  onTap: () =>
                      ref.read(saleFilterProvider.notifier).state = 'pending',
                ),
                const SizedBox(height: 12),
              ],
              _FilterRow(
                current: filter,
                counts: counts,
                onChange: (v) =>
                    ref.read(saleFilterProvider.notifier).state = v,
              ),
              const SizedBox(height: 4),
              ..._groupedList(filtered, farmId),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record Sale'),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(BuildContext context, String farmId) {
    final salesAsync = ref.watch(salesStreamProvider);
    final summary = ref.watch(salesSummaryProvider);
    final filter = ref.watch(saleFilterProvider);
    final filtered = ref.watch(filteredSalesProvider);
    final counts = ref.watch(saleCountsProvider);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDesktopHeader(context),
                      const SizedBox(height: 64),
                      const SizedBox(height: 420, child: _EmptyState()),
                    ],
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopHeader(context),
                    const SizedBox(height: 24),
                    _SalesHero(summary: summary, isDesktop: true),
                    const SizedBox(height: 24),
                    if (summary.hasPending) ...[
                      _PendingBanner(
                        amount: summary.pendingAmount,
                        count: summary.pendingCount,
                        onTap: () => ref
                            .read(saleFilterProvider.notifier)
                            .state = 'pending',
                      ),
                      const SizedBox(height: 20),
                    ],
                    _FilterRow(
                      current: filter,
                      counts: counts,
                      isDesktop: true,
                      onChange: (v) => ref
                          .read(saleFilterProvider.notifier)
                          .state = v,
                    ),
                    const SizedBox(height: 20),
                    ..._groupedList(
                      filtered,
                      farmId,
                      isDesktop: true,
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

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track revenue, buyers and invoices.',
                style: TextStyle(fontSize: 14, color: DPalette.inkMuted),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, minWidth: 220),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search sales...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: DPalette.inkMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: DPalette.inkMuted,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
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
                borderSide: const BorderSide(
                  color: DPalette.brand,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (v) =>
                ref.read(saleSearchProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(
            Icons.insights_outlined,
            color: DPalette.inkMuted,
          ),
          tooltip: 'Sales report',
          onPressed: () => context.push('/reports/sales'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/sales/add'),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Record Sale',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: DPalette.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Day grouping (adaptive)
  // -------------------------------------------------------------------------
  List<Widget> _groupedList(
    List<Sale> sales,
    String farmId, {
    bool isDesktop = false,
  }) {
    if (sales.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              'No sales match your filters.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
      ];
    }

    final sorted = [...sales]..sort((a, b) =>
        (b.saleDate ?? DateTime(2000)).compareTo(a.saleDate ?? DateTime(2000)));

    final groups = <DateTime, List<Sale>>{};
    for (final s in sorted) {
      final d = s.saleDate ?? DateTime.now();
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(s);
    }

    final widgets = <Widget>[];
    groups.forEach((day, items) {
      final dayRevenue = items
          .where((s) => s.status == 'completed')
          .fold<double>(0, (sum, s) => sum + s.totalAmount);

      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            top: isDesktop ? 20 : 16,
            bottom: 10,
          ),
          child: Row(
            children: [
              Text(
                dayLabel(day),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(width: 8),
              if (dayRevenue > 0)
                Text(
                  formatKsh(dayRevenue),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SaleStyle.completed.withValues(alpha: 0.9),
                  ),
                ),
            ],
          ),
        ),
      );

      if (isDesktop) {
        widgets.addAll(
          items.map((s) => _DesktopSaleTile(sale: s, farmId: farmId)),
        );
      } else {
        widgets.addAll(
          items.map((s) => _SaleTile(sale: s, farmId: farmId)),
        );
      }
    });

    return widgets;
  }
}

// ===========================================================================
// HERO BANNER (adaptive)
// ===========================================================================
class _SalesHero extends StatelessWidget {
  final SalesSummary summary;
  final bool isDesktop;
  const _SalesHero({required this.summary, this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final change = summary.monthChangePct;
    final up = (change ?? 0) >= 0;

    final padding = isDesktop
        ? const EdgeInsets.all(28)
        : const EdgeInsets.all(20);
    final revenueSize = isDesktop ? 48.0 : 34.0;
    final statLabelSize = isDesktop ? 11.5 : 11.0;
    final statValueSize = isDesktop ? 18.0 : 13.5;
    final dividerHeight = isDesktop ? 42.0 : 28.0;
    final radius = isDesktop ? 24.0 : 20.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/hero_crop.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(
                'https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    SaleStyle.revenueDeep.withValues(alpha: 0.88),
                    SaleStyle.revenue.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Total revenue',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.payments_outlined,
                      size: isDesktop ? 22 : 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 8 : 6),
                Text(
                  formatKsh(summary.totalRevenue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: revenueSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1,
                  ),
                ),
                if (change != null) ...[
                  SizedBox(height: isDesktop ? 16 : 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up ? Icons.trending_up : Icons.trending_down,
                          size: 14,
                          color: up
                              ? const Color(0xFFA5D6A7)
                              : const Color(0xFFFFCC80),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${up ? '+' : ''}${change.toStringAsFixed(1)}% vs last month',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: isDesktop ? 22 : 18),
                Divider(
                  color: Colors.white.withValues(alpha: 0.2),
                  height: 1,
                ),
                SizedBox(height: isDesktop ? 18 : 14),
                Row(
                  children: [
                    _stat(
                      'This month',
                      formatShortKsh(summary.thisMonth),
                      statLabelSize,
                      statValueSize,
                    ),
                    _vDivider(dividerHeight),
                    _stat(
                      'Last month',
                      formatShortKsh(summary.lastMonth),
                      statLabelSize,
                      statValueSize,
                    ),
                    _vDivider(dividerHeight),
                    _stat(
                      'Sales',
                      '${summary.completedCount}',
                      statLabelSize,
                      statValueSize,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    String value,
    double labelSize,
    double valueSize,
  ) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _vDivider(double height) => Container(
        width: 1,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

// ===========================================================================
// PENDING BANNER (unchanged)
// ===========================================================================
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.amount,
    required this.count,
    required this.onTap,
  });

  final double amount;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: SaleStyle.pending.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: SaleStyle.pending.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: SaleStyle.pending.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.hourglass_top,
                    size: 17, color: SaleStyle.pending),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatKsh(amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SaleStyle.pending,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$count ${count == 1 ? 'sale' : 'sales'} awaiting payment',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: SaleStyle.pending.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// FILTER ROW (adaptive)
// ===========================================================================
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.counts,
    required this.onChange,
    this.isDesktop = false,
  });

  final String current;
  final ({int all, int completed, int pending}) counts;
  final ValueChanged<String> onChange;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('All', 'all', counts.all, AppTheme.primaryGreen),
      _chip('Completed', 'completed', counts.completed, SaleStyle.completed),
      _chip('Pending', 'pending', counts.pending, SaleStyle.pending),
    ];

    if (isDesktop) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(String label, String value, int count, Color color) {
    final selected = current == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0 : 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// MOBILE SALE TILE (unchanged)
// ===========================================================================
class _SaleTile extends ConsumerWidget {
  const _SaleTile({required this.sale, required this.farmId});

  final Sale sale;
  final String farmId;

  String get _initial {
    final b = sale.buyer.trim();
    if (b.isEmpty) return '?';
    return b.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = sale.status == 'pending';
    final statusColor = SaleStyle.statusColor(sale.status);
    final radius = BorderRadius.circular(14);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: radius,
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/sales/${sale.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _initial,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.buyer.isEmpty ? '(no buyer)' : sale.buyer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (sale.cropName.isNotEmpty) sale.cropName,
                          formatQuantity(sale.quantity, sale.unit),
                          if (sale.location.isNotEmpty) sale.location,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatKsh(sale.totalAmount),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isPending
                            ? SaleStyle.pending
                            : SaleStyle.revenueDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        SaleStyle.statusLabel(sale.status).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined, size: 20),
                  color: Colors.black.withValues(alpha: 0.45),
                  tooltip: 'View invoice',
                  onPressed: () => context.push('/sales/${sale.id}/invoice'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DESKTOP SALE TILE (popup menu: Open / View Invoice)
// ===========================================================================
class _DesktopSaleTile extends ConsumerWidget {
  const _DesktopSaleTile({required this.sale, required this.farmId});

  final Sale sale;
  final String farmId;

  String get _initial {
    final b = sale.buyer.trim();
    if (b.isEmpty) return '?';
    return b.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = sale.status == 'pending';
    final statusColor = SaleStyle.statusColor(sale.status);
    final radius = BorderRadius.circular(14);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: radius,
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/sales/${sale.id}'),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _initial,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.buyer.isEmpty ? '(no buyer)' : sale.buyer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DPalette.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (sale.cropName.isNotEmpty) sale.cropName,
                          formatQuantity(sale.quantity, sale.unit),
                          if (sale.location.isNotEmpty) sale.location,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: DPalette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatKsh(sale.totalAmount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isPending
                            ? SaleStyle.pending
                            : SaleStyle.revenueDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        SaleStyle.statusLabel(sale.status).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: DPalette.inkMuted,
                    size: 20,
                  ),
                  tooltip: 'More options',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'open') {
                      context.push('/sales/${sale.id}');
                    }
                    if (value == 'invoice') {
                      context.push('/sales/${sale.id}/invoice');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 16),
                          SizedBox(width: 8),
                          Text('Open sale'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'invoice',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('View invoice'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// EMPTY STATE
// ===========================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: SaleStyle.revenue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.point_of_sale_outlined,
                  size: 32, color: SaleStyle.revenue),
            ),
            const SizedBox(height: 16),
            const Text(
              'No sales yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Record your first sale to start tracking revenue and buyers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}