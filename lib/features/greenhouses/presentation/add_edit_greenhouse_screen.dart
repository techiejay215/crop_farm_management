import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_palette.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/greenhouse_model.dart';
import '../data/greenhouse_style.dart';
import '../providers/greenhouse_provider.dart';

class AddEditGreenhouseScreen extends ConsumerStatefulWidget {
  final String? greenhouseId;
  const AddEditGreenhouseScreen({super.key, this.greenhouseId});

  @override
  ConsumerState<AddEditGreenhouseScreen> createState() =>
      _AddEditGreenhouseScreenState();
}

class _AddEditGreenhouseScreenState
    extends ConsumerState<AddEditGreenhouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _cropCtrl = TextEditingController();
  final _plantsCtrl = TextEditingController();

  bool _loading = false;
  bool _loadedExisting = false;

  bool get _isEditing => widget.greenhouseId != null;

  double? get _density => GreenhouseStyle.density(
        plants: int.tryParse(_plantsCtrl.text.trim()) ?? 0,
        size: double.tryParse(_sizeCtrl.text.trim()) ?? 0,
      );

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
    _sizeCtrl.dispose();
    _cropCtrl.dispose();
    _plantsCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loadedExisting || !mounted) return;
    final list = ref.read(greenhousesStreamProvider).value;
    if (list == null) return;

    Greenhouse? existing;
    for (final gh in list) {
      if (gh.id == widget.greenhouseId) {
        existing = gh;
        break;
      }
    }
    if (existing == null) return;

    _loadedExisting = true;
    setState(() {
      _nameCtrl.text = existing!.name;
      _sizeCtrl.text = _fmtNum(existing.size);
      _cropCtrl.text = existing.currentCrop;
      _plantsCtrl.text =
          existing.plantCount > 0 ? existing.plantCount.toString() : '';
    });
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

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
      final gh = Greenhouse(
        id: widget.greenhouseId ?? '',
        farmId: farmId,
        name: _nameCtrl.text.trim(),
        size: double.parse(_sizeCtrl.text.trim()),
        currentCrop: _cropCtrl.text.trim(),
        plantCount: int.tryParse(_plantsCtrl.text.trim()) ?? 0,
      );

      final repo = ref.read(greenhouseRepositoryProvider);
      if (!_isEditing) {
        await repo.addGreenhouse(farmId, gh);
      } else {
        await repo.updateGreenhouse(
            farmId, widget.greenhouseId!, gh.toFirestore());
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
    if (farmId == null || widget.greenhouseId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete greenhouse?'),
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
          .read(greenhouseRepositoryProvider)
          .deleteGreenhouse(farmId, widget.greenhouseId!);
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
    ref.listen(greenhousesStreamProvider, (_, __) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Greenhouse' : 'New Greenhouse'),
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
          children: _buildFormFields(),
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
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildFormFields(),
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
                  _isEditing ? 'Edit Greenhouse' : 'New Greenhouse',
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
                      ? 'Update greenhouse details and production.'
                      : 'Add a new greenhouse to your farm.',
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
  // SHARED FORM FIELDS
  // ===========================================================================
  List<Widget> _buildFormFields() {
    final density = _density;
    final densityColor = GreenhouseStyle.densityColor(density);

    return [
      _HeroCard(
        name: _nameCtrl.text.trim(),
        size: double.tryParse(_sizeCtrl.text) ?? 0,
        crop: _cropCtrl.text.trim(),
        plants: int.tryParse(_plantsCtrl.text) ?? 0,
      ),
      const SizedBox(height: 24),
      TextFormField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Greenhouse name',
          hintText: 'e.g. Greenhouse 1, Tunnel A',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.warehouse_outlined),
        ),
        onChanged: (_) => setState(() {}),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _sizeCtrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Size',
          hintText: 'e.g. 480',
          suffixText: 'm²',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.square_foot_outlined),
        ),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          final n = double.tryParse((v ?? '').trim());
          if (n == null) return 'Enter a number';
          if (n <= 0) return '> 0';
          return null;
        },
      ),
      const SizedBox(height: 24),
      _label('Current crop'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _cropCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Leave blank if the greenhouse is empty',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.grass_outlined),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _plantsCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Number of plants',
          hintText: 'e.g. 600',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.eco_outlined),
        ),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          if ((v ?? '').trim().isEmpty) return null;
          final n = int.tryParse(v!.trim());
          if (n == null) return 'Enter a number';
          if (n < 0) return 'Cannot be negative';
          return null;
        },
      ),
      if (density != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: densityColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: densityColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.density_medium_outlined,
                  size: 16, color: densityColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plant density',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: densityColor.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      GreenhouseStyle.densityLabel(density),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: densityColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${int.tryParse(_plantsCtrl.text) ?? 0} plants ÷ '
                '${double.tryParse(_sizeCtrl.text)?.toStringAsFixed(0) ?? 0} m²',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
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
                  _isEditing ? 'Save Changes' : 'Create Greenhouse',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    ];
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      );
}

// ===========================================================================
// Hero preview card (unchanged)
// ===========================================================================
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.size,
    required this.crop,
    required this.plants,
  });

  final String name;
  final double size;
  final String crop;
  final int plants;

  @override
  Widget build(BuildContext context) {
    final density = GreenhouseStyle.density(plants: plants, size: size);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: GreenhouseStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: GreenhouseStyle.primary.withValues(alpha: 0.24),
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
                child: const Icon(Icons.warehouse_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'GREENHOUSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name.isEmpty ? 'Greenhouse name' : name,
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
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                size <= 0 ? '— m²' : '${size.toStringAsFixed(0)} m²',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              if (crop.isNotEmpty) ...[
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
                    crop,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (density != null) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Density',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  GreenhouseStyle.densityLabel(density),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '$plants plants',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}