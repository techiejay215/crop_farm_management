// lib/features/expenses/widgets/expense_charts.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../expense_format.dart';
import '../providers/expense_provider.dart';
import 'expense_category_style.dart';

// ---------------------------------------------------------------------------
// Hero summary
// ---------------------------------------------------------------------------
class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({super.key, required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final change = summary.monthChangePct;
    final goingUp = (change ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B5E20),
            AppTheme.primaryGreen,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: Colors.white.withValues(alpha: 0.75)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatKsh(summary.total),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    goingUp ? Icons.trending_up : Icons.trending_down,
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
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
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
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

// ---------------------------------------------------------------------------
// "Where the money went" — horizontal bars
// ---------------------------------------------------------------------------
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    super.key,
    required this.totals,
    this.highlighted = 'all',
  });

  final List<CategoryTotal> totals;
  final String highlighted;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Spending by category',
      subtitle: '${totals.length} ${totals.length == 1 ? 'category' : 'categories'}',
      child: Column(
        children: [
          for (final t in totals) _row(t),
        ],
      ),
    );
  }

  Widget _row(CategoryTotal t) {
    final style = ExpenseCategories.of(t.category);
    final dimmed = highlighted != 'all' && highlighted != t.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(style.icon, size: 15, color: style.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  style.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: dimmed ? Colors.black38 : Colors.black87,
                  ),
                ),
              ),
              Text(
                formatKsh(t.total),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: dimmed ? Colors.black38 : Colors.black87,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${(t.share * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                        begin: 0, end: t.share.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Container(
                      height: 6,
                      width: constraints.maxWidth * value,
                      decoration: BoxDecoration(
                        color: style.color
                            .withValues(alpha: dimmed ? 0.35 : 1.0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6-month trend — vertical bars
// ---------------------------------------------------------------------------
class MonthlyTrendCard extends StatelessWidget {
  const MonthlyTrendCard({super.key, required this.months});

  final List<MonthlyTotal> months;

  @override
  Widget build(BuildContext context) {
    final maxTotal = months.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    if (maxTotal <= 0) return const SizedBox.shrink();

    final now = DateTime.now();
    final periodTotal = months.fold<double>(0, (s, m) => s + m.total);

    return _SectionCard(
      title: 'Last 6 months',
      subtitle: formatKsh(periodTotal),
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final m in months)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _bar(
                    m,
                    maxTotal,
                    isCurrent:
                        m.month.year == now.year && m.month.month == now.month,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(MonthlyTotal m, double maxTotal, {required bool isCurrent}) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final factor = m.total / maxTotal;
              return Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                      begin: 0, end: factor * constraints.maxHeight),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, height, _) => Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.primaryGreen
                          : AppTheme.primaryGreen.withValues(alpha: 0.28),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          monthShort(m.month),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? AppTheme.primaryGreen : Colors.black45,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card shell
// ---------------------------------------------------------------------------
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}