import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/expense_format.dart';
import '../data/crop_model.dart';
import '../data/crop_style.dart';
import '../providers/crop_provider.dart';

class AddEditCropScreen extends ConsumerStatefulWidget {
  final String? cropId;
  const AddEditCropScreen({super.key, this.cropId});

  @override
  ConsumerState<AddEditCropScreen> createState() => _AddEditCropScreenState();
}

class _AddEditCropScreenState extends ConsumerState<AddEditCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _varietyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _acreageCtrl = TextEditingController();
  final _plantsCtrl = TextEditingController();

  String _stage = 'growing';
  DateTime? _plantingDate;
  DateTime? _expectedHarvest;
  bool _loading = false;
  bool _loadedExisting = false;

  bool get _isEditing => widget.cropId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _varietyCtrl.dispose();
    _locationCtrl.dispose();
    _acreageCtrl.dispose();
    _plantsCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loadedExisting || !mounted) return;
    final list = ref.read(cropsStreamProvider).value;
    if (list == null) return;

    Crop? existing;
    for (final c in list) {
      if (c.id == widget.cropId) {
        existing = c;
        break;
      }
    }
    if (existing == null) return;

    _loadedExisting = true;
    setState(() {
      _nameCtrl.text = existing!.cropName;
      _varietyCtrl.text = existing.variety;
      _locationCtrl.text = existing.location;
      _acreageCtrl.text = _fmtNum(existing.acreage);
      _plantsCtrl.text = existing.plantCount.toString();
      _stage = existing.stage;
      _plantingDate = existing.plantingDate;
      _expectedHarvest = existing.expectedHarvest;
    });
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _pickDate({required bool isPlanting}) async {
    final initial = isPlanting
        ? (_plantingDate ?? DateTime.now())
        : (_expectedHarvest ?? DateTime.now().add(const Duration(days: 60)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isPlanting) {
        _plantingDate = picked;
      } else {
        _expectedHarvest = picked;
      }
    });
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
      final crop = Crop(
        id: widget.cropId ?? '',
        farmId: farmId,
        cropName: _nameCtrl.text.trim(),
        variety: _varietyCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        acreage: double.tryParse(_acreageCtrl.text.trim()) ?? 0,
        plantCount: int.tryParse(_plantsCtrl.text.trim()) ?? 0,
        plantingDate: _plantingDate,
        expectedHarvest: _expectedHarvest,
        stage: _stage,
      );

      final repo = ref.read(cropRepositoryProvider);
      if (!_isEditing) {
        await repo.addCrop(farmId, crop);
      } else {
        // Explicit nulls so clearing a date actually clears it in Firestore.
        final data = crop.toFirestore()
          ..['plantingDate'] = crop.plantingDate != null
              ? crop.toFirestore()['plantingDate']
              : null
          ..['expectedHarvest'] = crop.expectedHarvest != null
              ? crop.toFirestore()['expectedHarvest']
              : null;
        await repo.updateCrop(farmId, widget.cropId!, data);
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
    if (farmId == null || widget.cropId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete crop?'),
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
          .read(cropRepositoryProvider)
          .deleteCrop(farmId, widget.cropId!);
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
    ref.listen(cropsStreamProvider, (_, __) {
      if (_isEditing && !_loadedExisting) _prefill();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Crop' : 'New Crop'),
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
            _StageHero(
              name: _nameCtrl.text.trim(),
              variety: _varietyCtrl.text.trim(),
              stage: _stage,
              acreage: double.tryParse(_acreageCtrl.text) ?? 0,
              plants: int.tryParse(_plantsCtrl.text) ?? 0,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Crop name',
                hintText: 'e.g. Tomatoes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grass_outlined),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _varietyCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Variety (optional)',
                hintText: 'e.g. Roma, Cherry',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_florist_outlined),
              ),
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
            const SizedBox(height: 20),
            _label('Growth stage'),
            const SizedBox(height: 8),
            _stageRow(),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _plantsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Plants',
                      hintText: 'e.g. 500',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _acreageCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Acreage',
                      suffixText: 'ac',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _label('Dates'),
            const SizedBox(height: 8),
            _DateTile(
              // FIX: Icons.sprout_outlined does not exist in Material Icons.
              // Using local_florist_outlined as the closest "plant / seeded" icon.
              icon: Icons.local_florist_outlined,
              label: 'Planted',
              date: _plantingDate,
              onTap: () => _pickDate(isPlanting: true),
              onClear: _plantingDate == null
                  ? null
                  : () => setState(() => _plantingDate = null),
            ),
            const SizedBox(height: 10),
            _DateTile(
              icon: Icons.event_available_outlined,
              label: 'Expected harvest',
              date: _expectedHarvest,
              onTap: () => _pickDate(isPlanting: false),
              onClear: _expectedHarvest == null
                  ? null
                  : () => setState(() => _expectedHarvest = null),
              accent: CropStyle.ready,
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
                        _isEditing ? 'Save Changes' : 'Create Crop',
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

  Widget _stageRow() {
    return Row(
      children: CropStyle.stages.map((s) {
        final selected = _stage == s;
        final color = CropStyle.stageColor(s);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _stage = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.13)
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
                      Icon(
                        CropStyle.stageIcon(s),
                        size: 20,
                        color: selected ? color : Colors.black45,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CropStyle.stageShort(s),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: selected ? color : Colors.black87,
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
// Hero preview card
// ===========================================================================
class _StageHero extends StatelessWidget {
  const _StageHero({
    required this.name,
    required this.variety,
    required this.stage,
    required this.acreage,
    required this.plants,
  });

  final String name;
  final String variety;
  final String stage;
  final double acreage;
  final int plants;

  @override
  Widget build(BuildContext context) {
    final color = CropStyle.stageColor(stage);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: CropStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: CropStyle.primary.withValues(alpha: 0.24),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CropStyle.stageIcon(stage),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  CropStyle.stageShort(stage),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.grass_outlined,
                  size: 18, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  name.isEmpty ? 'Crop name' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: name.isEmpty
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.white,
                  ),
                ),
              ),
              if (variety.isNotEmpty) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    variety,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                plants > 0 ? '$plants plants' : '— plants',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              if (acreage > 0) ...[
                const SizedBox(width: 10),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${acreage == acreage.roundToDouble() ? acreage.toStringAsFixed(0) : acreage.toStringAsFixed(1)} acres',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Date tile
// ===========================================================================
class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
    this.accent,
  });

  final IconData icon;
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.primaryGreen;
    final hasDate = date != null;
    final now = DateTime.now();

    // Add "in X days" / "X days ago" context when available.
    String? context;
    if (hasDate) {
      final diff = date!.difference(now).inDays;
      if (diff > 0) {
        context = CropStyle.daysLabel(diff);
      } else if (diff < 0) {
        context = '${-diff} days ago';
      } else {
        context = 'Today';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasDate
                  ? color.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.12),
            ),
            color: hasDate ? color.withValues(alpha: 0.04) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDate ? fullDate(date!) : 'Not set',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasDate
                            ? Colors.black87
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (context != null)
                Text(
                  context,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.black.withValues(alpha: 0.4),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}