import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/expense_format.dart';
import '../data/harvest_model.dart';
import '../data/harvest_style.dart';
import '../providers/harvest_provider.dart';

class AddEditHarvestScreen extends ConsumerStatefulWidget {
  final String? harvestId;
  const AddEditHarvestScreen({super.key, this.harvestId});

  @override
  ConsumerState<AddEditHarvestScreen> createState() =>
      _AddEditHarvestScreenState();
}

class _AddEditHarvestScreenState extends ConsumerState<AddEditHarvestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cropCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _wastedCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  String _unit = 'kg';
  String _grade = 'A';
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadedExisting = false;

  bool get _isEditing => widget.harvestId != null;

  double get _gross => double.tryParse(_qtyCtrl.text.trim()) ?? 0;
  double get _wasted => double.tryParse(_wastedCtrl.text.trim()) ?? 0;
  double get _net => (_gross - _wasted).clamp(0, double.infinity);
  double get _wasteRatio => _gross <= 0 ? 0 : _wasted / _gross;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  @override
  void dispose() {
    _cropCtrl.dispose();
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    _wastedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loadedExisting || !mounted) return;
    final list = ref.read(harvestsStreamProvider).value;
    if (list == null) return;

    Harvest? existing;
    for (final h in list) {
      if (h.id == widget.harvestId) {
        existing = h;
        break;
      }
    }
    if (existing == null) return;

    _loadedExisting = true;
    setState(() {
      _cropCtrl.text = existing!.cropName;
      _locationCtrl.text = existing.location;
      _qtyCtrl.text = _fmt(existing.quantity);
      _wastedCtrl.text = _fmt(existing.wastedQuantity);
      _unit = existing.unit;
      _grade = existing.grade;
      _date = existing.harvestDate ?? DateTime.now();
      _notesCtrl.text = existing.notes ?? '';
    });
  }

  String _fmt(double v) =>
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) {
      _snack('Select a farm first', error: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final harvest = Harvest(
        id: widget.harvestId ?? '',
        farmId: farmId,
        cropName: _cropCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        harvestDate: _date,
        quantity: _gross,
        unit: _unit,
        grade: _grade,
        wastedQuantity: _wasted,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      final repo = ref.read(harvestRepositoryProvider);
      if (!_isEditing) {
        await repo.addHarvest(farmId, harvest);
      } else {
        final data = harvest.toFirestore()..['notes'] = harvest.notes;
        await repo.updateHarvest(farmId, widget.harvestId!, data);
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
    if (farmId == null || widget.harvestId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete harvest?'),
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
          .read(harvestRepositoryProvider)
          .deleteHarvest(farmId, widget.harvestId!);
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
    ref.listen(harvestsStreamProvider, (_, __) {
      if (_isEditing && !_loadedExisting) _prefill();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Harvest' : 'Record Harvest'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _loading ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _YieldCard(
              gross: _gross,
              wasted: _wasted,
              net: _net,
              unit: _unit,
              grade: _grade,
              wasteRatio: _wasteRatio,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _cropCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Crop',
                hintText: 'e.g. Tomatoes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grass),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Field A / Greenhouse 1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 16),
            _DateRow(date: _date, onTap: _pickDate),
            const SizedBox(height: 24),
            _label('Grade'),
            const SizedBox(height: 8),
            _gradeRow(),
            const SizedBox(height: 20),
            _label('Quantity'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total harvested',
                      suffixText: _unit,
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
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: HarvestStyle.units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wastedCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Wasted / lost (optional)',
                suffixText: _unit,
                border: const OutlineInputBorder(),
                helperText: _wasteRatio > 0
                    ? '${(_wasteRatio * 100).toStringAsFixed(1)}% · ${HarvestStyle.wasteLabel(_wasteRatio)}'
                    : null,
                helperStyle: TextStyle(
                  color: HarvestStyle.wasteColor(_wasteRatio),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final n = double.tryParse(v!.trim());
                if (n == null) return 'Enter a number';
                if (n < 0) return 'Cannot be negative';
                if (n > _gross) return 'More than harvested';
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Weather, quality, buyers…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
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
                        _isEditing ? 'Save Changes' : 'Record Harvest',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
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

  Widget _gradeRow() {
    return Row(
      children: HarvestStyle.grades.map((g) {
        final selected = _grade == g;
        final color = HarvestStyle.gradeColor(g);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _grade = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? color.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.1),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Grade $g',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        HarvestStyle.gradeLabel(g),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? color.withValues(alpha: 0.85)
                              : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ===========================================================================
// Hero yield card
// ===========================================================================
class _YieldCard extends StatelessWidget {
  const _YieldCard({
    required this.gross,
    required this.wasted,
    required this.net,
    required this.unit,
    required this.grade,
    required this.wasteRatio,
  });

  final double gross;
  final double wasted;
  final double net;
  final String unit;
  final String grade;
  final double wasteRatio;

  @override
  Widget build(BuildContext context) {
    final gradeColor = HarvestStyle.gradeColor(grade);
    final hasWaste = wasted > 0;
    final wasteColor = HarvestStyle.wasteColor(wasteRatio);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: HarvestStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: HarvestStyle.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Net yield',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'GRADE $grade',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatQuantity(net, unit),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (hasWaste) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: wasteColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${formatQuantity(wasted, unit)} lost · '
                  '${(wasteRatio * 100).toStringAsFixed(1)}% · '
                  '${HarvestStyle.wasteLabel(wasteRatio)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
          if (gross > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: wasteRatio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                  hasWaste ? wasteColor : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasWaste
                  ? '${formatQuantity(gross, unit)} harvested, '
                      '${formatQuantity(wasted, unit)} wasted'
                  : '${formatQuantity(gross, unit)} harvested, no wastage',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
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