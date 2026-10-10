import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/data/crop_activity_model.dart';
import '../../crops/data/crop_style.dart';
import '../../expenses/expense_format.dart';
import '../../harvests/data/harvest_style.dart';
import '../../sales/data/sale_style.dart';
import '../data/greenhouse_style.dart';
import '../providers/greenhouse_detail_provider.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
const Color _profitGreen = Color(0xFF2E7D32);
const Color _lossRed = Color(0xFFC62828);
const Color _incomeBlue = Color(0xFF1565C0);
const Color _expenseOrange = Color(0xFFEF6C00);
const Color _harvestAmber = Color(0xFFB8860B);
const Color _ink = Color(0xFF11181C);
const Color _mutedInk = Color(0xFF5C6B73);
const Color _hairline = Color(0x14000000); // 8% black
const Color _cardBg = Colors.white;
const Color _chipBg = Color(0xFFF5F7F8);

class GreenhouseDetailScreen extends ConsumerWidget {
  final String greenhouseId;
  const GreenhouseDetailScreen({super.key, required this.greenhouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(greenhouseDetailProvider(greenhouseId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/greenhouses');
            }
          },
        ),
        title: const Text('Greenhouse'),
        actions: [
          detailAsync.maybeWhen(
            data: (d) => d == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit greenhouse',
                    onPressed: () =>
                        context.push('/greenhouses/${d.greenhouse.id}'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Greenhouse not found.'));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(greenhouseDetailProvider(greenhouseId)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final wide = w > 960;
                final horizontalPad = w < 420 ? 12.0 : 16.0;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    12,
                    horizontalPad,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroCard(detail: detail),
                          const SizedBox(height: 16),
                          if (detail.crop != null) ...[
                            _CurrentCropSection(
                              detail: detail,
                              onOpenCrop: () => context.push(
                                '/crops/${detail.crop!.id}/detail',
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _KpiGrid(detail: detail),
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _ActivitiesSection(detail: detail),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      _ExpensesSection(detail: detail),
                                      const SizedBox(height: 16),
                                      _IncomeSection(detail: detail),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _ActivitiesSection(detail: detail),
                            const SizedBox(height: 16),
                            _ExpensesSection(detail: detail),
                            const SizedBox(height: 16),
                            _IncomeSection(detail: detail),
                          ],
                          const SizedBox(height: 16),
                          if (detail.harvests.isNotEmpty)
                            _HarvestSection(detail: detail),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// HERO CARD
// ===========================================================================
class _HeroCard extends StatelessWidget {
  final GreenhouseDetail detail;
  const _HeroCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final gh = detail.greenhouse;
    final active = gh.currentCrop.trim().isNotEmpty || detail.crop != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: GreenhouseStyle.primaryDeep.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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
                        colors: [
                          GreenhouseStyle.primaryDeep,
                          GreenhouseStyle.primary,
                        ],
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
                      GreenhouseStyle.primaryDeep.withValues(alpha: 0.94),
                      GreenhouseStyle.primary.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
            // soft glow accent
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.warehouse_outlined,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gh.name.isEmpty ? '(unnamed)' : gh.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.4,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _StatusPill(active: active),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(color: Colors.white.withValues(alpha: 0.22), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _stat('Area', '${gh.size.toStringAsFixed(0)} m²'),
                      _vDivider(),
                      _stat('Plants', '${gh.plantCount}'),
                      _vDivider(),
                      _stat(
                        'Density',
                        GreenhouseStyle.densityLabel(detail.density),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );

  Widget _vDivider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.22),
      );
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF7CE0A4) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Empty',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CURRENT CROP SECTION
// ===========================================================================
class _CurrentCropSection extends StatelessWidget {
  final GreenhouseDetail detail;
  final VoidCallback onOpenCrop;
  const _CurrentCropSection({required this.detail, required this.onOpenCrop});

  @override
  Widget build(BuildContext context) {
    final crop = detail.crop!;
    final stageColor = CropStyle.stageColor(crop.stage);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'CURRENT CROP',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: _mutedInk,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CropStyle.stageIcon(crop.stage),
                        size: 12, color: stageColor),
                    const SizedBox(width: 5),
                    Text(
                      CropStyle.stageLabel(crop.stage).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: stageColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CropStyle.primary.withValues(alpha: 0.18),
                      CropStyle.primary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.grass_outlined,
                  size: 24,
                  color: CropStyle.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.cropName.isEmpty ? '(unnamed)' : crop.cropName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (crop.variety.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        crop.variety,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _mutedInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _metaRow('Planted',
              crop.plantingDate != null ? _fmtDate(crop.plantingDate!) : '—'),
          if (crop.expectedHarvest != null)
            _metaRow('Expected harvest', _fmtDate(crop.expectedHarvest!)),
          _metaRow('Plants', '${crop.plantCount}'),
          if (crop.acreage > 0)
            _metaRow(
              'Acreage',
              '${crop.acreage == crop.acreage.roundToDouble() ? crop.acreage.toStringAsFixed(0) : crop.acreage.toStringAsFixed(1)} ac',
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onOpenCrop,
              style: ElevatedButton.styleFrom(
                backgroundColor: CropStyle.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Open full crop details',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _mutedInk),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ===========================================================================
// KPI GRID
// ===========================================================================
class _KpiGrid extends StatelessWidget {
  final GreenhouseDetail detail;
  const _KpiGrid({required this.detail});

  @override
  Widget build(BuildContext context) {
    final profit = detail.profit;
    final positive = profit >= 0;

    final items = [
      _Kpi(Icons.payments_outlined, 'Income', formatShortKsh(detail.revenue),
          _incomeBlue),
      _Kpi(Icons.trending_down, 'Expenses',
          formatShortKsh(detail.totalExpenses), _expenseOrange),
      _Kpi(
        positive ? Icons.trending_up : Icons.trending_down,
        positive ? 'Net profit' : 'Net loss',
        formatShortKsh(profit.abs()),
        positive ? _profitGreen : _lossRed,
      ),
      _Kpi(Icons.scale_outlined, 'Net yield',
          formatQuantity(detail.netYield, detail.dominantUnit),
          GreenhouseStyle.primary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final perRow = w > 640 ? 4 : 2;
        const spacing = 10.0;
        final tileW = (w - (perRow - 1) * spacing) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              items.map((i) => SizedBox(width: tileW, child: _tile(i))).toList(),
        );
      },
    );
  }

  Widget _tile(_Kpi k) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: k.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(k.icon, size: 17, color: k.color),
          ),
          const SizedBox(height: 12),
          Text(
            k.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: _mutedInk,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              k.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: k.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  _Kpi(this.icon, this.label, this.value, this.color);
}

// ===========================================================================
// ACTIVITIES
// ===========================================================================
class _ActivitiesSection extends StatelessWidget {
  final GreenhouseDetail detail;
  const _ActivitiesSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    final activities = detail.activities;

    final grouped = <String, List<CropActivity>>{};
    for (final a in activities) {
      grouped.putIfAbsent(a.type, () => []).add(a);
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return _Section(
      title: 'Activities',
      accentColor: const Color(0xFF6A1B9A),
      subtitle: activities.isEmpty
          ? 'No activities recorded'
          : '${activities.length} entries · ${sorted.length} types',
      child: activities.isEmpty
          ? const _EmptyBlock(
              icon: Icons.history_edu_outlined,
              text: 'Record crop activities to see them here.',
            )
          : Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _activityRow(sorted[i].key, sorted[i].value),
                ],
              ],
            ),
    );
  }

  Widget _activityRow(String type, List<CropActivity> items) {
    final color = ActivityTypes.color(type);
    final icon = ActivityTypes.icon(type);
    final totalCost = items.fold<double>(0, (s, a) => s + (a.cost ?? 0));
    final totalQty = items.fold<double>(0, (s, a) => s + (a.quantity ?? 0));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ActivityTypes.label(type),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                  style: const TextStyle(fontSize: 10.5, color: _mutedInk),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (totalCost > 0)
                Text(
                  formatKsh(totalCost),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _expenseOrange,
                  ),
                ),
              if (totalQty > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'Qty ${_fmtNum(totalQty)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _mutedInk,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// EXPENSES
// ===========================================================================
class _ExpensesSection extends StatelessWidget {
  final GreenhouseDetail detail;
  const _ExpensesSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    final expenses = detail.expenses;
    final total = detail.totalExpenses;

    final grouped = <String, double>{};
    for (final e in expenses) {
      grouped[e.category] = (grouped[e.category] ?? 0) + e.amount;
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Section(
      title: 'Expenses',
      accentColor: _expenseOrange,
      subtitle: expenses.isEmpty
          ? 'No expenses recorded'
          : '${expenses.length} entries · ${formatKsh(total)}',
      child: expenses.isEmpty
          ? const _EmptyBlock(
              icon: Icons.account_balance_wallet_outlined,
              text: 'Costs linked to this greenhouse will appear here.',
            )
          : Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _categoryBar(
                    sorted[i].key,
                    sorted[i].value,
                    total <= 0 ? 0 : sorted[i].value / total,
                  ),
                ],
                const SizedBox(height: 14),
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatKsh(total),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _expenseOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _categoryBar(String category, double amount, double share) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _prettyCategory(category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
            Text(
              '${formatKsh(amount)}  (${(share * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 10.5, color: _mutedInk),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: _expenseOrange.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(_expenseOrange),
          ),
        ),
      ],
    );
  }

  static String _prettyCategory(String s) {
    if (s.isEmpty) return 'Other';
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ===========================================================================
// INCOME
// ===========================================================================
class _IncomeSection extends StatelessWidget {
  final GreenhouseDetail detail;
  const _IncomeSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    final sales = detail.sales.where((s) => s.status == 'completed').toList();
    final pending = detail.sales.where((s) => s.status != 'completed').toList();

    return _Section(
      title: 'Income',
      accentColor: _incomeBlue,
      subtitle: sales.isEmpty && pending.isEmpty
          ? 'No sales yet'
          : '${sales.length} completed${pending.isNotEmpty ? ' · ${pending.length} pending' : ''}',
      child: sales.isEmpty && pending.isEmpty
          ? const _EmptyBlock(
              icon: Icons.point_of_sale_outlined,
              text: 'Sales from this greenhouse will appear here.',
            )
          : Column(
              children: [
                for (var i = 0; i < sales.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 14,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  _row(sales[i]),
                ],
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(
                      height: 1,
                      color: Colors.black.withValues(alpha: 0.06)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.hourglass_bottom,
                          size: 14, color: _expenseOrange),
                      const SizedBox(width: 6),
                      Text(
                        '${pending.length} pending',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _expenseOrange,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatKsh(detail.pendingRevenue),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _expenseOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _row(dynamic s) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _incomeBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.attach_money_outlined,
              size: 16, color: _incomeBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.buyer.isEmpty ? 'Unknown buyer' : s.buyer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_fmtNum(s.quantity)} ${s.unit} × ${formatKsh(s.pricePerUnit)}',
                style: const TextStyle(fontSize: 10.5, color: _mutedInk),
              ),
            ],
          ),
        ),
        Text(
          formatKsh(s.totalAmount),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: _incomeBlue,
          ),
        ),
      ],
    );
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// HARVEST
// ===========================================================================
class _HarvestSection extends StatelessWidget {
  final GreenhouseDetail detail;
  const _HarvestSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Production',
      accentColor: _harvestAmber,
      subtitle:
          '${detail.harvests.length} harvests · net ${formatQuantity(detail.netYield, detail.dominantUnit)}',
      child: Column(
        children: [
          for (var i = 0; i < detail.harvests.length; i++) ...[
            if (i > 0)
              Divider(height: 14, color: Colors.black.withValues(alpha: 0.05)),
            _row(detail.harvests[i]),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 10),
          _summary('Gross', detail.grossYield, const Color(0xFF546E7A)),
          const SizedBox(height: 4),
          _summary('Wasted', detail.wasted, _lossRed),
          const SizedBox(height: 4),
          _summary('Net', detail.netYield, _profitGreen, bold: true),
        ],
      ),
    );
  }

  Widget _row(dynamic h) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HarvestStyle.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          // Fixed: replaced missing HarvestStyle.gradeIcon with a plain icon.
          child: const Icon(
            Icons.agriculture_outlined,
            size: 16,
            color: HarvestStyle.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade ${h.grade}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              if (h.harvestDate != null)
                Text(
                  _fmtDate(h.harvestDate),
                  style: const TextStyle(fontSize: 10.5, color: _mutedInk),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatQuantity(h.quantity, h.unit),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            if (h.wastedQuantity > 0) ...[
              const SizedBox(height: 2),
              Text(
                '−${_fmtNum(h.wastedQuantity)} ${h.unit}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _lossRed,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _summary(String label, double value, Color color,
      {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: _mutedInk,
          ),
        ),
        const Spacer(),
        Text(
          formatQuantity(value, detail.dominantUnit),
          style: TextStyle(
            fontSize: bold ? 13.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ===========================================================================
// SHARED: Card wrapper, Section wrapper, empty block
// ===========================================================================
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Color accentColor;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
    this.accentColor = const Color(0xFF2E7D32),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: _ink,
                  ),
                ),
              ),
              if (subtitle.isNotEmpty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _mutedInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyBlock({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: _mutedInk),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: _mutedInk),
          ),
        ],
      ),
    );
  }
}