import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../expenses/expense_format.dart';
import '../data/crop_model.dart';
import '../data/crop_style.dart';
import '../providers/crop_provider.dart';

const _maxContent = 560.0;

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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete crop?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) return _buildDesktop(context);
        return _buildMobile(context);
      },
    );
  }

  // ===========================================================================
  // MOBILE (unchanged)
  // ===========================================================================
  Widget _buildMobile(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContent),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + bottomInset),
              children: _buildFormFields(),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: DPalette.canvas,
      body: Column(
        children: [
          _buildDesktopHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Form(
                    key: _formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _buildFormFields(),
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 360,
                          child: _buildSidebar(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 18, 32, 18),
      decoration: const BoxDecoration(
        color: DPalette.surface,
        border: Border(bottom: BorderSide(color: DPalette.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: DPalette.ink),
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Crop' : 'New Crop',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEditing
                      ? 'Update crop details and growth stage.'
                      : 'Create a new crop and start tracking production.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: DPalette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_isEditing)
            TextButton.icon(
              onPressed: _loading ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIVE HERO SIDEBAR
  // ===========================================================================
  Widget _buildSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageHero(
          name: _nameCtrl.text.trim(),
          variety: _varietyCtrl.text.trim(),
          stage: _stage,
          acreage: double.tryParse(_acreageCtrl.text) ?? 0,
          plants: int.tryParse(_plantsCtrl.text) ?? 0,
        ),
        const SizedBox(height: 16),
        // Dates info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DPalette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KEY DATES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: DPalette.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              _sidebarInfoRow(
                'Planted',
                _plantingDate == null ? 'Not set' : fullDate(_plantingDate!),
                _plantingDate != null,
              ),
              const SizedBox(height: 8),
              _sidebarInfoRow(
                'Harvest',
                _expectedHarvest == null
                    ? 'Not set'
                    : fullDate(_expectedHarvest!),
                _expectedHarvest != null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebarInfoRow(String label, String value, bool isSet) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DPalette.inkMuted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSet ? DPalette.ink : DPalette.inkMuted,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SHARED FORM FIELDS
  // ===========================================================================
  List<Widget> _buildFormFields() {
    return [
      // Mobile-only: hero at the top
      LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          if (isDesktop) return const SizedBox.shrink();
          return Column(
            children: [
              _StageHero(
                name: _nameCtrl.text.trim(),
                variety: _varietyCtrl.text.trim(),
                stage: _stage,
                acreage: double.tryParse(_acreageCtrl.text) ?? 0,
                plants: int.tryParse(_plantsCtrl.text) ?? 0,
              ),
              const SizedBox(height: 26),
            ],
          );
        },
      ),
      _sectionLabel('Basics'),
      const SizedBox(height: 10),
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
        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _varietyCtrl,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Variety (optional)',
          hintText: 'e.g. Roma, Cherry',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.local_florist_outlined),
        ),
      ),
      const SizedBox(height: 14),
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
      const SizedBox(height: 24),
      _sectionLabel('Growth stage'),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          return isDesktop ? _stageRowDesktop() : _stageRow();
        },
      ),
      const SizedBox(height: 24),
      _sectionLabel('Size'),
      const SizedBox(height: 10),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
      _sectionLabel('Dates'),
      const SizedBox(height: 10),
      _DateTile(
        icon: Icons.local_florist_outlined,
        label: 'Planted',
        date: _plantingDate,
        onTap: () => _pickDate(isPlanting: true),
        onClear: _plantingDate == null
            ? null
            : () => setState(() => _plantingDate = null),
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 34),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    ];
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.black.withValues(alpha: 0.45),
        ),
      );

  // ---- Mobile stage picker: horizontal scroll (unchanged) ----
  Widget _stageRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CropStyle.stages.map((s) {
          final selected = _stage == s;
          final color = CropStyle.stageColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 92,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _stage = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          selected ? color : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? color
                            : Colors.black.withValues(alpha: 0.07),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          CropStyle.stageIcon(s),
                          size: 22,
                          color: selected ? Colors.white : Colors.black45,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CropStyle.stageShort(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: selected ? Colors.white : Colors.black87,
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
      ),
    );
  }

  // ---- Desktop stage picker: Wrap, all visible at once ----
  Widget _stageRowDesktop() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CropStyle.stages.map((s) {
        final selected = _stage == s;
        final color = CropStyle.stageColor(s);
        return SizedBox(
          width: 120,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _stage = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selected ? color : DPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? color : DPalette.hairline,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      CropStyle.stageIcon(s),
                      size: 22,
                      color: selected ? Colors.white : DPalette.inkMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CropStyle.stageShort(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: selected ? Colors.white : DPalette.ink,
                      ),
                    ),
                  ],
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
// Hero preview card (unchanged)
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: CropStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: CropStyle.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CropStyle.stageIcon(stage),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  CropStyle.stageShort(stage),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.grass_outlined,
                  size: 20, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 16),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: name.isEmpty
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.white,
                  ),
                ),
              ),
              if (variety.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      variety,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
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
                Flexible(
                  child: Text(
                    '${acreage == acreage.roundToDouble() ? acreage.toStringAsFixed(0) : acreage.toStringAsFixed(1)} acres',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
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
// Date tile (unchanged)
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

    String? hint;
    if (hasDate) {
      final diff = date!.difference(now).inDays;
      if (diff > 0) {
        hint = CropStyle.daysLabel(diff);
      } else if (diff < 0) {
        hint = '${-diff} days ago';
      } else {
        hint = 'Today';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasDate
                  ? color.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            color: hasDate
                ? color.withValues(alpha: 0.05)
                : Theme.of(context).cardColor,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasDate ? fullDate(date!) : 'Not set',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: hasDate
                            ? Colors.black87
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (hint != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
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