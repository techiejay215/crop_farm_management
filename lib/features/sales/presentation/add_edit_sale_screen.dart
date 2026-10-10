import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/expense_format.dart';
import '../../harvests/data/harvest_model.dart';
import '../../harvests/providers/harvest_provider.dart';
import '../data/sale_model.dart';
import '../data/sale_style.dart';
import '../providers/sale_provider.dart';

class AddEditSaleScreen extends ConsumerStatefulWidget {
  final String? saleId;
  const AddEditSaleScreen({super.key, this.saleId});

  @override
  ConsumerState<AddEditSaleScreen> createState() => _AddEditSaleScreenState();
}

class _AddEditSaleScreenState extends ConsumerState<AddEditSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _buyerCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String? _harvestId;
  String _status = 'completed';
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadedExisting = false;

  bool get _isEditing => widget.saleId != null;

  double get _total {
    final q = double.tryParse(_qtyCtrl.text) ?? 0;
    final p = double.tryParse(_priceCtrl.text) ?? 0;
    return q * p;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  @override
  void dispose() {
    _buyerCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loadedExisting || !mounted) return;
    final list = ref.read(salesStreamProvider).value;
    if (list == null) return;

    Sale? existing;
    for (final s in list) {
      if (s.id == widget.saleId) {
        existing = s;
        break;
      }
    }
    if (existing == null) return;

    _loadedExisting = true;
    setState(() {
      _harvestId = existing!.harvestId;
      _buyerCtrl.text = existing.buyer;
      _qtyCtrl.text = _formatNum(existing.quantity);
      _priceCtrl.text = _formatNum(existing.pricePerUnit);
      _status = existing.status;
      _date = existing.saleDate ?? DateTime.now();
    });
  }

  String _formatNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickHarvest(List<Harvest> harvests) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HarvestPickerSheet(
        harvests: harvests,
        selectedId: _harvestId,
      ),
    );
    if (picked != null) setState(() => _harvestId = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_harvestId == null) {
      _snack('Select a harvest first', error: true);
      return;
    }

    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) {
      _snack('Select a farm first', error: true);
      return;
    }

    final harvests = ref.read(harvestsStreamProvider).value ?? const [];
    Harvest? harvest;
    for (final h in harvests) {
      if (h.id == _harvestId) {
        harvest = h;
        break;
      }
    }
    if (harvest == null) {
      _snack('Linked harvest no longer exists', error: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final sale = Sale(
        id: widget.saleId ?? '',
        farmId: farmId,
        harvestId: _harvestId!,
        cropName: harvest.cropName,
        location: harvest.location,
        buyer: _buyerCtrl.text.trim(),
        quantity: double.parse(_qtyCtrl.text.trim()),
        unit: harvest.unit,
        pricePerUnit: double.parse(_priceCtrl.text.trim()),
        totalAmount: _total,
        status: _status,
        saleDate: _date,
      );

      final repo = ref.read(saleRepositoryProvider);
      if (!_isEditing) {
        await repo.addSale(farmId, sale);
      } else {
        await repo.updateSale(farmId, widget.saleId!, sale.toFirestore());
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Could not save: $e', error: true);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null || widget.saleId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(saleRepositoryProvider)
          .deleteSale(farmId, widget.saleId!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Could not delete: $e', error: true);
      }
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade600 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final harvestsAsync = ref.watch(harvestsStreamProvider);

    ref.listen(harvestsStreamProvider, (_, next) {
      if (_isEditing && !_loadedExisting) _prefill();
      next.whenData((harvests) {
        if (_harvestId != null &&
            !harvests.any((h) => h.id == _harvestId) &&
            mounted) {
          setState(() => _harvestId = null);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Sale' : 'Record Sale'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'View invoice',
              onPressed: () =>
                  context.push('/sales/${widget.saleId}/invoice'),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _loading ? null : _confirmDelete,
            ),
        ],
      ),
      body: harvestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (harvests) {
          if (harvests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Record a harvest first — sales must be linked to one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          Harvest? selected;
          for (final h in harvests) {
            if (h.id == _harvestId) {
              selected = h;
              break;
            }
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _TotalCard(
                  total: _total,
                  qty: double.tryParse(_qtyCtrl.text) ?? 0,
                  price: double.tryParse(_priceCtrl.text) ?? 0,
                  unit: selected?.unit ?? 'kg',
                ),
                const SizedBox(height: 24),
                _label('Harvest'),
                const SizedBox(height: 8),
                _HarvestTile(
                  harvest: selected,
                  onTap: () => _pickHarvest(harvests),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _buyerCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Buyer name',
                    hintText: 'e.g. Nairobi Fresh Produce',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          suffixText: selected?.unit ?? 'kg',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').trim());
                          if (n == null) return 'Required';
                          if (n <= 0) return '> 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price / unit',
                          prefixText: 'KSh ',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').trim());
                          if (n == null) return 'Required';
                          if (n <= 0) return '> 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _label('Payment status'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _statusChip(
                        'completed',
                        'Completed',
                        Icons.check_circle_outline,
                        SaleStyle.completed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statusChip(
                        'pending',
                        'Pending',
                        Icons.schedule,
                        SaleStyle.pending,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DateRow(date: _date, onTap: _pickDate),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Record Sale',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      );

  Widget _statusChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = _status == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _status = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.1),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? color : Colors.black45),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : Colors.black54,
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
// Total preview card
// ===========================================================================
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.qty,
    required this.price,
    required this.unit,
  });

  final double total;
  final double qty;
  final double price;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final hasMath = qty > 0 && price > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: SaleStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: SaleStyle.revenue.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total amount',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatKsh(total),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasMath
                ? '${formatQuantity(qty, unit)} × ${formatKsh(price)} / $unit'
                : 'Enter quantity and price',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Harvest picker tile
// ===========================================================================
class _HarvestTile extends StatelessWidget {
  const _HarvestTile({required this.harvest, required this.onTap});

  final Harvest? harvest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final linked = harvest != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: linked
                  ? AppTheme.primaryGreen.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.12),
            ),
            color: linked
                ? AppTheme.primaryGreen.withValues(alpha: 0.04)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.grass,
                    size: 19, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      linked ? harvest!.cropName : 'Select a harvest',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: linked ? Colors.black87 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      linked
                          ? '${formatQuantity(harvest!.quantity, harvest!.unit)}'
                              '${harvest!.location.isNotEmpty ? '  ·  ${harvest!.location}' : ''}'
                          : 'Sales must be linked to a harvest',
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
                linked ? 'Change' : 'Choose',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
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
// Harvest picker bottom sheet
// ===========================================================================
class _HarvestPickerSheet extends StatelessWidget {
  const _HarvestPickerSheet({
    required this.harvests,
    required this.selectedId,
  });

  final List<Harvest> harvests;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select harvest',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${harvests.length} ${harvests.length == 1 ? 'harvest' : 'harvests'} available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: harvests.length,
                itemBuilder: (context, i) {
                  final h = harvests[i];
                  final isSelected = h.id == selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, h.id),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                      .withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.grass,
                                    size: 18, color: AppTheme.primaryGreen),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.cropName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatQuantity(h.quantity, h.unit)}'
                                      '${h.location.isNotEmpty ? '  ·  ${h.location}' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color:
                                            Colors.black.withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    size: 18, color: AppTheme.primaryGreen),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Date row
// ===========================================================================
class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Text(
              fullDate(date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Text(
              'Change',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}