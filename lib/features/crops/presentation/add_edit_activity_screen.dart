import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../farms/providers/farm_provider.dart';
import '../data/crop_activity_model.dart';
import '../data/crop_model.dart';
import '../providers/crop_activity_provider.dart';
import '../providers/crop_provider.dart';

class AddEditActivityScreen extends ConsumerStatefulWidget {
  final String cropId;
  final String? activityId;
  const AddEditActivityScreen({
    super.key,
    required this.cropId,
    this.activityId,
  });

  @override
  ConsumerState<AddEditActivityScreen> createState() =>
      _AddEditActivityScreenState();
}

class _AddEditActivityScreenState
    extends ConsumerState<AddEditActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'kg');
  final _costCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = ActivityTypes.fertilization;
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loaded = false;

  bool get _isEditing => widget.activityId != null;

  @override
  void dispose() {
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _costCtrl.dispose();
    _incomeCtrl.dispose();
    _personCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(List<CropActivity> activities) {
    if (_loaded || !_isEditing) return;
    final a = activities.where((x) => x.id == widget.activityId).firstOrNull;
    if (a == null) return;
    _loaded = true;
    _type = a.type;
    _descCtrl.text = a.description;
    _qtyCtrl.text = a.quantity?.toString() ?? '';
    _unitCtrl.text = a.unit ?? 'kg';
    _costCtrl.text = a.cost?.toString() ?? '';
    _incomeCtrl.text = a.income?.toString() ?? '';
    _personCtrl.text = a.personResponsible ?? '';
    _notesCtrl.text = a.notes ?? '';
    _date = a.date ?? DateTime.now();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;

    setState(() => _loading = true);

    try {
      final crops = ref.read(cropsStreamProvider).value ?? [];
      final crop = crops.where((c) => c.id == widget.cropId).firstOrNull;
      if (crop == null) throw Exception('Crop not found');

      // Get farm location for the linked expense/sale.
      final farms = ref.read(farmsStreamProvider).value ?? [];
      final farm = farms.where((f) => f.id == farmId).firstOrNull;
      final farmLocation = crop.location.isNotEmpty
          ? crop.location
          : (farm?.farmName ?? '');

      final activity = CropActivity(
        id: widget.activityId ?? '',
        farmId: farmId,
        cropId: widget.cropId,
        date: _date,
        type: _type,
        description: _descCtrl.text.trim(),
        quantity: double.tryParse(_qtyCtrl.text),
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        cost: double.tryParse(_costCtrl.text),
        income: double.tryParse(_incomeCtrl.text),
        personResponsible: _personCtrl.text.trim().isEmpty
            ? null
            : _personCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      final repo = ref.read(cropActivityRepositoryProvider);
      if (_isEditing) {
        await repo.updateActivity(
          activity: activity,
          cropName: crop.cropName,
          farmLocation: farmLocation,
        );
      } else {
        await repo.addActivity(
          activity: activity,
          cropName: crop.cropName,
          farmLocation: farmLocation,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('No farm selected')));
    }

    final activitiesAsync = ref.watch(
      cropActivitiesStreamProvider(
        (farmId: farmId, cropId: widget.cropId),
      ),
    );
    activitiesAsync.whenData(_prefill);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Activity' : 'Record Activity'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ---- Type picker ----
            _label('Activity type'),
            const SizedBox(height: 8),
            _typePicker(),
            const SizedBox(height: 20),

            // ---- Date + description ----
            _DateField(date: _date, onTap: _pickDate),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Applied calcium nitrate',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Quantity ----
            if (ActivityTypes.hasQuantity(_type))
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'kg',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            if (ActivityTypes.hasQuantity(_type)) const SizedBox(height: 16),

            // ---- Cost ----
            if (ActivityTypes.hasCost(_type))
              TextFormField(
                controller: _costCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cost (auto-links to expenses)',
                  prefixText: 'KSh ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_down),
                ),
              ),
            if (ActivityTypes.hasCost(_type)) const SizedBox(height: 16),

            // ---- Income ----
            if (ActivityTypes.hasIncome(_type))
              TextFormField(
                controller: _incomeCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Income (auto-links to sales)',
                  prefixText: 'KSh ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_up),
                ),
              ),
            if (ActivityTypes.hasIncome(_type)) const SizedBox(height: 16),

            // ---- Person responsible ----
            TextFormField(
              controller: _personCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Person responsible (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Notes ----
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Additional notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ---- Info banner ----
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Record once — costs and income automatically appear '
                      'in crop, farm and financial reports.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- Save ----
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save changes' : 'Record activity',
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
          letterSpacing: 0.3,
        ),
      );

  Widget _typePicker() {
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ActivityTypes.all.map((t) {
          final selected = _type == t;
          final color = ActivityTypes.color(t);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 76,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? color
                          : Colors.black.withValues(alpha: 0.08),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ActivityTypes.icon(t),
                        size: 20,
                        color: selected ? color : Colors.black45,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ActivityTypes.label(t),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : Colors.black87,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 12),
              const Text('Date',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: const TextStyle(
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