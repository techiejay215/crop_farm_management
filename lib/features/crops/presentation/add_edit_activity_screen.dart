import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../expenses/expense_format.dart';
import '../../farms/providers/farm_provider.dart';
import '../data/crop_activity_model.dart';
import '../data/crop_model.dart';
import '../providers/crop_activity_provider.dart';
import '../providers/crop_provider.dart';

const _maxContent = 560.0;

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

class _AddEditActivityScreenState extends ConsumerState<AddEditActivityScreen> {
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
        title: Text(_isEditing ? 'Edit Activity' : 'Record Activity'),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContent),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 40 + bottomInset),
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
                        // ---- Left: form ----
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildFormFields(),
                        )),
                        const SizedBox(width: 24),
                        // ---- Right: live summary sidebar ----
                        SizedBox(
                          width: 340,
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
                  _isEditing ? 'Edit Activity' : 'Record Activity',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Costs and income auto-appear in crop, farm and financial reports.',
                  style: TextStyle(fontSize: 13, color: DPalette.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIVE SUMMARY SIDEBAR
  // ===========================================================================
  Widget _buildSidebar() {
    final typeColor = ActivityTypes.color(_type);
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final income = double.tryParse(_incomeCtrl.text) ?? 0;
    final net = income - cost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Live summary ----
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DPalette.hairline),
            boxShadow: DPalette.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: DPalette.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ActivityTypes.icon(_type),
                        size: 13, color: typeColor),
                    const SizedBox(width: 6),
                    Text(
                      ActivityTypes.label(_type),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: typeColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                fullDate(_date),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DPalette.ink,
                ),
              ),
              if (_descCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _descCtrl.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DPalette.inkMuted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: DPalette.hairline, height: 1),
              const SizedBox(height: 16),
              _sidebarRow(
                'Cost',
                formatKsh(cost),
                const Color(0xFFEF6C00),
              ),
              const SizedBox(height: 8),
              _sidebarRow(
                'Income',
                formatKsh(income),
                const Color(0xFF1E88E5),
              ),
              const SizedBox(height: 12),
              const Divider(color: DPalette.hairline, height: 1),
              const SizedBox(height: 12),
              _sidebarRow(
                net >= 0 ? 'Net gain' : 'Net loss',
                formatKsh(net.abs()),
                net >= 0
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ---- Info banner ----
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_outlined,
                  size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Record once — costs and income automatically '
                  'appear in crop, farm and financial reports.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebarRow(String label, String value, Color color,
      {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 13.5 : 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: DPalette.inkMuted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: FontWeight.w800,
            color: color,
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
      _sectionLabel('Activity type'),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          return isDesktop ? _typePickerDesktop() : _typePicker();
        },
      ),
      const SizedBox(height: 24),

      _sectionLabel('When'),
      const SizedBox(height: 10),
      _DateField(date: _date, onTap: _pickDate),
      const SizedBox(height: 24),

      _sectionLabel('Details'),
      const SizedBox(height: 10),
      TextFormField(
        controller: _descCtrl,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Description',
          hintText: 'e.g. Applied calcium nitrate',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.notes_outlined),
        ),
      ),
      const SizedBox(height: 14),

      if (ActivityTypes.hasQuantity(_type))
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
      if (ActivityTypes.hasQuantity(_type))
        const SizedBox(height: 14),

      if (ActivityTypes.hasCost(_type))
        TextFormField(
          controller: _costCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Cost (auto-links to expenses)',
            prefixText: 'KSh ',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.trending_down),
          ),
        ),
      if (ActivityTypes.hasCost(_type)) const SizedBox(height: 14),

      if (ActivityTypes.hasIncome(_type))
        TextFormField(
          controller: _incomeCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Income (auto-links to sales)',
            prefixText: 'KSh ',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.trending_up),
          ),
        ),
      if (ActivityTypes.hasIncome(_type)) const SizedBox(height: 14),

      _sectionLabel('Assignment'),
      const SizedBox(height: 10),
      TextFormField(
        controller: _personCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Person responsible (optional)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 14),

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

      // Mobile-only info banner
      LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          if (isDesktop) return const SizedBox.shrink();
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_outlined,
                        size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Record once — costs and income automatically '
                        'appear in crop, farm and financial reports.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),

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
          color: Colors.black.withValues(alpha: 0.45),
          letterSpacing: 0.8,
        ),
      );

  // ---- Mobile type picker: horizontal scroll (unchanged) ----
  Widget _typePicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ActivityTypes.all.map((t) {
          final selected = _type == t;
          final color = ActivityTypes.color(t);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 80,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected ? color : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ActivityTypes.icon(t),
                        size: 22,
                        color: selected ? Colors.white : color,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ActivityTypes.label(t),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: selected ? Colors.white : Colors.black87,
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

  // ---- Desktop type picker: Wrap, all visible at once ----
  Widget _typePickerDesktop() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ActivityTypes.all.map((t) {
        final selected = _type == t;
        final color = ActivityTypes.color(t);
        return SizedBox(
          width: 110,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _type = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ActivityTypes.icon(t),
                      size: 22,
                      color: selected ? Colors.white : color,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ActivityTypes.label(t),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: selected ? Colors.white : DPalette.ink,
                        height: 1.2,
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

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 12),
              const Text('Date',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Flexible(
                child: Text(
                  '${date.day}/${date.month}/${date.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
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