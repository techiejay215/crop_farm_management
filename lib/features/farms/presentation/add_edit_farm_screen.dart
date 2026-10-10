import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/providers/customer_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/farm_model.dart';
import '../data/farm_style.dart';
import '../providers/farm_provider.dart';

class AddEditFarmScreen extends ConsumerStatefulWidget {
  final String? farmId;
  const AddEditFarmScreen({super.key, this.farmId});

  @override
  ConsumerState<AddEditFarmScreen> createState() => _AddEditFarmScreenState();
}

class _AddEditFarmScreenState extends ConsumerState<AddEditFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _acreageCtrl = TextEditingController();
  final _landlordCtrl = TextEditingController();
  final _rentalCostCtrl = TextEditingController();

  String _type = 'main';
  String _rentalPeriod = 'monthly';
  String? _selectedOwnerId;
  bool _loading = false;
  bool _loadedExisting = false;

  /// Snapshots of fields the form doesn't edit but must preserve on update —
  /// otherwise update() would zero them.
  int _existingCropCount = 0;
  DateTime? _existingCreatedAt;
  String? _existingLogoUrl;

  bool get _isEditing => widget.farmId != null;

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
    _locationCtrl.dispose();
    _acreageCtrl.dispose();
    _landlordCtrl.dispose();
    _rentalCostCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loadedExisting || !mounted) return;
    final farms = ref.read(farmsStreamProvider).value;
    if (farms == null) return;

    Farm? existing;
    for (final f in farms) {
      if (f.id == widget.farmId) {
        existing = f;
        break;
      }
    }
    if (existing == null) return;

    _loadedExisting = true;
    setState(() {
      _nameCtrl.text = existing!.farmName;
      _locationCtrl.text = existing.location;
      _acreageCtrl.text = _fmtNum(existing.acreage);
      _landlordCtrl.text = existing.landlord ?? '';
      _rentalCostCtrl.text =
          existing.rentalCost != null ? _fmtNum(existing.rentalCost!) : '';
      _type = existing.type;
      _rentalPeriod = existing.rentalPeriod ?? 'monthly';
      _selectedOwnerId = existing.ownerId;
      _existingCropCount = existing.cropCount;
      _existingCreatedAt = existing.createdAt;
      _existingLogoUrl = existing.logoUrl;
    });
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isAdmin = ref.read(isAdminProvider);
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    final ownerId = isAdmin ? _selectedOwnerId : currentUser.uid;
    if (ownerId == null || ownerId.isEmpty) {
      _snack('Assign this farm to a customer', error: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final farm = Farm(
        id: widget.farmId ?? '',
        ownerId: ownerId,
        farmName: _nameCtrl.text.trim(),
        type: _type,
        location: _locationCtrl.text.trim(),
        acreage: double.parse(_acreageCtrl.text.trim()),
        landlord:
            _type == 'rented' ? _landlordCtrl.text.trim() : null,
        rentalCost: _type == 'rented'
            ? double.tryParse(_rentalCostCtrl.text.trim())
            : null,
        rentalPeriod: _type == 'rented' ? _rentalPeriod : null,
        // --- preserved fields (the real bug fix) ---
        logoUrl: _existingLogoUrl,
        cropCount: _existingCropCount,
        createdAt: _existingCreatedAt,
      );

      final repo = ref.read(farmRepositoryProvider);
      if (!_isEditing) {
        await repo.createFarm(farm);
      } else {
        // Explicit nulls so switching from rented → main actually clears
        // the rental fields in Firestore.
        final data = farm.toFirestore()
          ..['landlord'] = farm.landlord
          ..['rentalCost'] = farm.rentalCost
          ..['rentalPeriod'] = farm.rentalPeriod;
        await repo.updateFarm(widget.farmId!, data);
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
    if (widget.farmId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete farm?'),
        content: const Text(
          'This removes the farm. Crops, harvests, sales and expenses tied '
          'to it will remain in the database but become unreachable from the app.',
        ),
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
      await ref.read(farmRepositoryProvider).deleteFarm(widget.farmId!);
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
    final isAdmin = ref.watch(isAdminProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    // Late-arriving stream safety net.
    ref.listen(farmsStreamProvider, (_, __) {
      if (_isEditing && !_loadedExisting) _prefill();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Farm' : 'New Farm'),
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
            _TypeHero(
              type: _type,
              name: _nameCtrl.text.trim(),
              acreage: double.tryParse(_acreageCtrl.text) ?? 0,
            ),
            const SizedBox(height: 24),
            if (isAdmin) ...[
              _label('Customer'),
              const SizedBox(height: 8),
              customersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading customers: $e'),
                data: (customers) => DropdownButtonFormField<String>(
                  value: _selectedOwnerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Select customer',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: customers
                      .map((c) => DropdownMenuItem(
                            value: c.uid,
                            child: Text(
                              '${c.name} (${c.email})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedOwnerId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 20),
            ],
            _label('Farm type'),
            const SizedBox(height: 8),
            _typeRow(),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Farm name',
                hintText: 'e.g. Riverside Farm',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.agriculture_outlined),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. Nakuru, Kiambu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _acreageCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Acreage',
                suffixText: 'acres',
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
            if (_type == 'rented') ...[
              const SizedBox(height: 24),
              _label('Rental details'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _landlordCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Landlord name',
                  hintText: 'Who owns this land?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _rentalCostCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Rental cost',
                        prefixText: 'KSh ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _rentalPeriod,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Per',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Month')),
                        DropdownMenuItem(
                            value: 'quarterly', child: Text('Quarter')),
                        DropdownMenuItem(
                            value: 'yearly', child: Text('Year')),
                      ],
                      onChanged: (v) =>
                          setState(() => _rentalPeriod = v!),
                    ),
                  ),
                ],
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
                        _isEditing ? 'Save Changes' : 'Create Farm',
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

  Widget _typeRow() {
    return Row(
      children: [
        Expanded(
          child: _typeCard(
            value: 'main',
            icon: Icons.home_work_outlined,
            label: 'Main Farm',
            subtitle: 'You own this land',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _typeCard(
            value: 'rented',
            icon: Icons.key_outlined,
            label: 'Rented',
            subtitle: 'Leased from a landlord',
          ),
        ),
      ],
    );
  }

  Widget _typeCard({
    required String value,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final selected = _type == value;
    final color = FarmStyle.typeColor(value);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.1),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? color : Colors.black45),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected
                      ? color.withValues(alpha: 0.8)
                      : Colors.black45,
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
// Hero preview card
// ===========================================================================
class _TypeHero extends StatelessWidget {
  const _TypeHero({
    required this.type,
    required this.name,
    required this.acreage,
  });

  final String type;
  final String name;
  final double acreage;

  @override
  Widget build(BuildContext context) {
    final color = FarmStyle.typeColor(type);
    final icon = FarmStyle.typeIcon(type);
    final label = FarmStyle.typeLabel(type);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: type == 'rented'
              ? [const Color(0xFFBF360C), const Color(0xFFEF6C00)]
              : [FarmStyle.primaryDeep, FarmStyle.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
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
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
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
            name.isEmpty ? 'Farm name' : name,
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
                acreage <= 0 ? '— acres' : '${_fmt(acreage)} acres',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}