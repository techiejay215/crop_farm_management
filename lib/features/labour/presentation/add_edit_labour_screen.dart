import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/expense_format.dart';
import '../data/labour_model.dart';
import '../data/labour_style.dart';
import '../providers/labour_provider.dart';

class AddEditLabourScreen extends ConsumerStatefulWidget {
  final String? labourId;
  const AddEditLabourScreen({super.key, this.labourId});

  @override
  ConsumerState<AddEditLabourScreen> createState() =>
      _AddEditLabourScreenState();
}

class _AddEditLabourScreenState extends ConsumerState<AddEditLabourScreen> {
  final _formKey = GlobalKey<FormState>();
  final _workerCtrl = TextEditingController();
  final _taskCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');

  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadedExisting = false;

  bool get _isEditing => widget.labourId != null;

  double get _total {
    final d = double.tryParse(_daysCtrl.text) ?? 0;
    final r = double.tryParse(_rateCtrl.text) ?? 0;
    return d * r;
  }

  double get _paid {
    final p = double.tryParse(_paidCtrl.text) ?? 0;
    return p.clamp(0, _total <= 0 ? double.infinity : _total);
  }

  double get _pending => (_total - _paid).clamp(0, double.infinity);

  String get _paymentState =>
      LabourStyle.state(total: _total, paid: _paid);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  @override
  void dispose() {
    _workerCtrl.dispose();
    _taskCtrl.dispose();
    _locationCtrl.dispose();
    _daysCtrl.dispose();
    _rateCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loadedExisting || !mounted) return;
    final list = ref.read(labourStreamProvider).value;
    if (list == null) return;

    Labour? existing;
    for (final l in list) {
      if (l.id == widget.labourId) {
        existing = l;
        break;
      }
    }
    if (existing == null) return;

    _loadedExisting = true;
    setState(() {
      _workerCtrl.text = existing!.workerName;
      _taskCtrl.text = existing.task;
      _locationCtrl.text = existing.location ?? '';
      _daysCtrl.text = _fmtNum(existing.daysWorked);
      _rateCtrl.text = _fmtNum(existing.dailyRate);
      _paidCtrl.text = _fmtNum(existing.amountPaid);
      _date = existing.date ?? DateTime.now();
    });
  }

  String _fmtNum(double v) =>
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

  void _setPaymentState(String state) {
    switch (state) {
      case 'paid':
        _paidCtrl.text = _fmtNum(_total);
        break;
      case 'unpaid':
        _paidCtrl.text = '0';
        break;
      case 'partial':
        // Keep current, no-op; user will type into the field.
        break;
    }
    setState(() {});
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
      final labour = Labour(
        id: widget.labourId ?? '',
        farmId: farmId,
        workerName: _workerCtrl.text.trim(),
        task: _taskCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        daysWorked: double.parse(_daysCtrl.text.trim()),
        dailyRate: double.parse(_rateCtrl.text.trim()),
        totalAmount: _total,
        amountPaid: _paid,
        date: _date,
      );

      final repo = ref.read(labourRepositoryProvider);
      if (!_isEditing) {
        await repo.addLabour(farmId, labour);
      } else {
        // Explicit null so clearing location actually clears it in Firestore.
        final data = labour.toFirestore()..['location'] = labour.location;
        await repo.updateLabour(farmId, widget.labourId!, data);
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
    if (farmId == null || widget.labourId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
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
          .read(labourRepositoryProvider)
          .deleteLabour(farmId, widget.labourId!);
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
    ref.listen(labourStreamProvider, (_, __) {
      if (_isEditing && !_loadedExisting) _prefill();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Record' : 'New Worker Record'),
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
            _TotalCard(
              total: _total,
              paid: _paid,
              pending: _pending,
              state: _paymentState,
              days: double.tryParse(_daysCtrl.text) ?? 0,
              rate: double.tryParse(_rateCtrl.text) ?? 0,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _workerCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Worker name',
                hintText: 'e.g. Joseph Kamau',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taskCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Task performed',
                hintText: 'e.g. Weeding, spraying, harvesting',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.task_alt_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Field A / Greenhouse 1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 20),
            _label('Wage calculation'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _daysCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Days worked',
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
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Daily rate',
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
            _label('Payment'),
            const SizedBox(height: 8),
            _paymentRow(),
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
                        _isEditing ? 'Save Changes' : 'Record Labour',
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

  /// Quick-fill buttons + editable "amount paid" field with a clear
  /// paid/pending split.
  Widget _paymentRow() {
    final state = _paymentState;
    final total = _total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _quickState('Unpaid', 'unpaid', total <= 0),
              const SizedBox(width: 8),
              _quickState('Half', 'partial', total <= 0),
              const SizedBox(width: 8),
              _quickState('Full', 'paid', total <= 0),
              const Spacer(),
              Text(
                LabourStyle.labelFor(state),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: LabourStyle.colorFor(state),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paidCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount paid',
              prefixText: 'KSh ',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null) return 'Enter a number';
              if (n < 0) return 'Cannot be negative';
              if (n > _total) return 'More than total';
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Paid',
                  formatKsh(_paid),
                  LabourStyle.paid,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat(
                  'Pending',
                  formatKsh(_pending),
                  _pending > 0 ? LabourStyle.partial : LabourStyle.paid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickState(String label, String state, bool disabled) {
    final active = state == 'partial'
        ? (_paid > 0 && _paid < _total)
        : _paymentState == state;
    final color = LabourStyle.colorFor(
      state == 'partial' ? 'partial' : state,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: disabled ? null : () => _setPaymentState(state),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? color : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Hero total card
// ===========================================================================
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.paid,
    required this.pending,
    required this.state,
    required this.days,
    required this.rate,
  });

  final double total;
  final double paid;
  final double pending;
  final String state;
  final double days;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final hasMath = days > 0 && rate > 0;
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LabourStyle.heroGradient,
        boxShadow: [
          BoxShadow(
            color: LabourStyle.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total wage',
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
                ? '${formatQuantity(days, 'day${days == 1 ? '' : 's'}')} × ${formatKsh(rate)} / day'
                : 'Enter days and rate to calculate',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _legend('Paid', formatKsh(paid)),
              ),
              _divider(),
              Expanded(
                child: _legend('Pending', formatKsh(pending)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      );

  Widget _divider() => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: Colors.white.withValues(alpha: 0.18),
      );
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