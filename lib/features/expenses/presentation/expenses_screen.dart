import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../dashboard/widgets/dashboard_palette.dart';
import '../data/expense_model.dart';
import '../expense_format.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_category_style.dart';
import '../widgets/expense_charts.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
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
      ref.read(expenseSearchProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);

    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expenses')),
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
    final expensesAsync = ref.watch(expensesStreamProvider);
    final summary = ref.watch(expenseSummaryProvider);
    final categoryTotals = ref.watch(categoryTotalsProvider);
    final monthlyTotals = ref.watch(monthlyTotalsProvider);
    final filtered = ref.watch(filteredExpensesProvider);
    final filter = ref.watch(expenseFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                  hintText: 'Search expenses…',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(expenseSearchProvider.notifier).state = v,
              )
            : const Text('Expenses'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add expense',
            onPressed: () => context.push('/expenses/add'),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          if (all.isEmpty) return const _EmptyState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _HeroBanner(summary: summary),
              const SizedBox(height: 16),
              CategoryBreakdownCard(
                totals: categoryTotals,
                highlighted: filter,
              ),
              const SizedBox(height: 16),
              MonthlyTrendCard(months: monthlyTotals),
              const SizedBox(height: 24),
              _filterRow(filter),
              ..._groupedList(filtered, farmId, filter),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout(BuildContext context, String farmId) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final summary = ref.watch(expenseSummaryProvider);
    final categoryTotals = ref.watch(categoryTotalsProvider);
    final monthlyTotals = ref.watch(monthlyTotalsProvider);
    final filtered = ref.watch(filteredExpensesProvider);
    final filter = ref.watch(expenseFilterProvider);

    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: expensesAsync.when(
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

                    // Hero banner
                    _HeroBanner(summary: summary, isDesktop: true),
                    const SizedBox(height: 24),

                    // Charts — side by side
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: CategoryBreakdownCard(
                              totals: categoryTotals,
                              highlighted: filter,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: MonthlyTrendCard(months: monthlyTotals),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filters
                    _filterRowDesktop(filter),
                    const SizedBox(height: 16),

                    // Grouped list
                    ..._groupedList(
                      filtered,
                      farmId,
                      filter,
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

  // -------------------------------------------------------------------------
  // Desktop header
  // -------------------------------------------------------------------------
  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expenses',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track every shilling spent on the farm.',
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
              hintText: 'Search expenses...',
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
                ref.read(expenseSearchProvider.notifier).state = v,
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => context.push('/expenses/add'),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Add Expense',
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
  // Filter chips
  // -------------------------------------------------------------------------
  Widget _filterRow(String selected) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chip('All', 'all', selected),
          ),
          for (final c in ExpenseCategories.all)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(c.shortLabel, c.value, selected),
            ),
        ],
      ),
    );
  }

  Widget _filterRowDesktop(String selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('All', 'all', selected),
        for (final c in ExpenseCategories.all)
          _chip(c.shortLabel, c.value, selected),
      ],
    );
  }

  Widget _chip(String label, String value, String selected) {
    final isSelected = selected == value;
    final color = value == 'all'
        ? AppTheme.primaryGreen
        : ExpenseCategories.of(value).color;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: color.withValues(alpha: isSelected ? 1 : 0.25),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : color,
      ),
      onSelected: (_) =>
          ref.read(expenseFilterProvider.notifier).state = value,
    );
  }

  // -------------------------------------------------------------------------
  // Grouped list
  // -------------------------------------------------------------------------
  List<Widget> _groupedList(
    List<Expense> expenses,
    String farmId,
    String filter, {
    bool isDesktop = false,
  }) {
    if (expenses.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              filter == 'all'
                  ? 'No expenses match your search.'
                  : 'Nothing in this category yet.',
              style: const TextStyle(color: Colors.black45),
            ),
          ),
        ),
      ];
    }

    final sorted = [...expenses]..sort((a, b) =>
        (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));

    final groups = <DateTime, List<Expense>>{};
    for (final e in sorted) {
      final d = e.date ?? DateTime.now();
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(e);
    }

    final widgets = <Widget>[];
    groups.forEach((day, items) {
      final dayTotal = items.fold<double>(0, (s, e) => s + e.amount);

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
              Text(
                formatKsh(dayTotal),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      );

      if (isDesktop) {
        widgets.addAll(
          items.map((e) => _DesktopExpenseTile(expense: e, farmId: farmId)),
        );
      } else {
        widgets.addAll(
          items.map((e) => _ExpenseTile(expense: e, farmId: farmId)),
        );
      }
    });

    return widgets;
  }
}

// ===========================================================================
// HERO BANNER (adaptive)
// ===========================================================================
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.summary, this.isDesktop = false});
  final ExpenseSummary summary;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final change = summary.monthChangePct;
    final goingUp = (change ?? 0) >= 0;

    final totalSize = isDesktop ? 48.0 : 32.0;
    final padding = isDesktop
        ? const EdgeInsets.all(28)
        : const EdgeInsets.all(20);
    final statLabelSize = isDesktop ? 11.5 : 10.5;
    final statValueSize = isDesktop ? 14.5 : 12.5;
    final dividerHeight = isDesktop ? 32.0 : 26.0;
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
                'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B5E20), AppTheme.primaryGreen],
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
                    const Color(0xFF1B5E20).withValues(alpha: 0.9),
                    AppTheme.primaryGreen.withValues(alpha: 0.72),
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
                      'Total spent',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: isDesktop ? 22 : 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 8 : 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatKsh(summary.total),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: totalSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                      height: 1,
                    ),
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
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          goingUp
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 14,
                          color: goingUp
                              ? const Color(0xFFFFCC80)
                              : const Color(0xFFA5D6A7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${goingUp ? '+' : ''}${change.toStringAsFixed(0)}% vs last month',
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
                      formatKsh(summary.thisMonth),
                      statLabelSize,
                      statValueSize,
                    ),
                    _divider(dividerHeight),
                    _stat(
                      'Last month',
                      formatKsh(summary.lastMonth),
                      statLabelSize,
                      statValueSize,
                    ),
                    _divider(dividerHeight),
                    _stat(
                      'Average',
                      formatKsh(summary.average),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _divider(double height) => Container(
        width: 1,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.white.withValues(alpha: 0.2),
      );
}

// ===========================================================================
// MOBILE EXPENSE TILE (unchanged — swipe to delete)
// ===========================================================================
class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense, required this.farmId});

  final Expense expense;
  final String farmId;

  String get _subtitle {
    final parts = <String>[
      ExpenseCategories.of(expense.category).shortLabel,
    ];
    if ((expense.cropName ?? '').isNotEmpty) parts.add(expense.cropName!);
    if ((expense.location ?? '').isNotEmpty) parts.add(expense.location!);
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ExpenseCategories.of(expense.category);
    final radius = BorderRadius.circular(14);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete expense?'),
          content:
              Text('"${expense.description}" will be removed permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFC62828)),
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(expenseRepositoryProvider).deleteExpense(farmId, expense.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: radius,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: () => context.push('/expenses/${expense.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(style.icon, size: 19, color: style.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle,
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
                  Text(
                    formatKsh(expense.amount),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.expenseOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DESKTOP EXPENSE TILE (popup menu instead of swipe)
// ===========================================================================
class _DesktopExpenseTile extends ConsumerWidget {
  const _DesktopExpenseTile({required this.expense, required this.farmId});

  final Expense expense;
  final String farmId;

  String get _subtitle {
    final parts = <String>[
      ExpenseCategories.of(expense.category).shortLabel,
    ];
    if ((expense.cropName ?? '').isNotEmpty) parts.add(expense.cropName!);
    if ((expense.location ?? '').isNotEmpty) parts.add(expense.location!);
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ExpenseCategories.of(expense.category);
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
          onTap: () => context.push('/expenses/${expense.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, size: 20, color: style.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
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
                        _subtitle,
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
                Text(
                  formatKsh(expense.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.expenseOrange,
                  ),
                ),
                const SizedBox(width: 4),
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
                    if (value == 'edit') {
                      context.push('/expenses/${expense.id}');
                    }
                    if (value == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete expense?'),
        content: Text(
          '"${expense.description}" will be removed permanently.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(expenseRepositoryProvider).deleteExpense(farmId, expense.id);
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
                color: AppTheme.expenseOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 32,
                color: AppTheme.expenseOrange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No expenses yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Record seeds, labour, transport — everything you spend on the farm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}