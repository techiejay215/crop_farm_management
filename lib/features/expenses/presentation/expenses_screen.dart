import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
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
              // ---- Hero banner with background image ----
              _HeroBanner(summary: summary),
              const SizedBox(height: 16),

              // ---- Charts ----
              CategoryBreakdownCard(
                totals: categoryTotals,
                highlighted: filter,
              ),
              const SizedBox(height: 16),
              MonthlyTrendCard(months: monthlyTotals),
              const SizedBox(height: 24),

              // ---- Filters + list ----
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

  // -------------------------------------------------------------------------
  // Filter chips
  // -------------------------------------------------------------------------
  Widget _filterRow(String selected) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', 'all', selected),
          for (final c in ExpenseCategories.all)
            _chip(c.shortLabel, c.value, selected),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, String selected) {
    final isSelected = selected == value;
    final color = value == 'all'
        ? AppTheme.primaryGreen
        : ExpenseCategories.of(value).color;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
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
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Grouped list
  // -------------------------------------------------------------------------
  List<Widget> _groupedList(
    List<Expense> expenses,
    String farmId,
    String filter,
  ) {
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
          padding: const EdgeInsets.only(top: 16, bottom: 10),
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

      widgets.addAll(
        items.map((e) => _ExpenseTile(expense: e, farmId: farmId)),
      );
    });

    return widgets;
  }
}

// ===========================================================================
// HERO BANNER with background image
// ===========================================================================
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.summary});
  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final change = summary.monthChangePct;
    final goingUp = (change ?? 0) >= 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Background image
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
                      colors: [
                        Color(0xFF1B5E20),
                        AppTheme.primaryGreen,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Tint overlay
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
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Total spent',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatKsh(summary.total),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      height: 1,
                    ),
                  ),
                ),
                if (change != null) ...[
                  const SizedBox(height: 12),
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
                const SizedBox(height: 18),
                Divider(
                  color: Colors.white.withValues(alpha: 0.2),
                  height: 1,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('This month', formatKsh(summary.thisMonth)),
                    _divider(),
                    _stat('Last month', formatKsh(summary.lastMonth)),
                    _divider(),
                    _stat('Average', formatKsh(summary.average)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
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
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.white.withValues(alpha: 0.2),
      );
}

// ===========================================================================
// Expense row
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
// Empty state
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
              child: const Icon(Icons.receipt_long,
                  size: 32, color: AppTheme.expenseOrange),
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