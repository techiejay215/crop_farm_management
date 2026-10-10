import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/expense_model.dart';
import '../expense_format.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_category_style.dart';

// =============================================================================
// INPUT FORMATTER — digits + single decimal, max 2 decimals.
// =============================================================================
class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final cleaned = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    final parts = cleaned.split('.');
    if (parts.length > 2) return oldValue;
    if (parts.length == 2 && parts[1].length > 2) return oldValue;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  final String? expenseId;
  const AddEditExpenseScreen({super.key, this.expenseId});

  @override
  ConsumerState<AddEditExpenseScreen> createState() =>
      _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  static const _paymentMethods = ['Cash', 'M-Pesa', 'Bank', 'Credit'];

  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _cropCtrl = TextEditingController();

  String _category = 'seeds';
  String? _paymentMethod;
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadedExisting = false;
  bool _showAllCategories = false;

  bool get _isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _locationCtrl.dispose();
    _cropCtrl.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final cleaned =
        _amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _prefill() {
    if (_loadedExisting || !mounted) return;
    final list = ref.read(expensesStreamProvider).value;
    if (list == null) return;

    Expense? existing;
    for (final e in list) {
      if (e.id == widget.expenseId) {
        existing = e;
        break;
      }
    }
    if (existing == null) return;

    _loadedExisting = true;
    setState(() {
      _descCtrl.text = existing!.description;
      _amountCtrl.text = _fmtInput(existing.amount);
      _locationCtrl.text = existing.location ?? '';
      _cropCtrl.text = existing.cropName ?? '';
      _category = existing.category;
      _paymentMethod = existing.paymentMethod;
      _date = existing.date ?? DateTime.now();
    });
  }

  String _fmtInput(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

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
      _snack('Select a farm first.', error: true);
      return;
    }

    final amount = _parsedAmount;
    if (amount == null || amount <= 0) {
      _snack('Enter a valid amount.', error: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final expense = Expense(
        id: widget.expenseId ?? '',
        farmId: farmId,
        category: _category,
        description: _descCtrl.text.trim(),
        amount: amount,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        cropName:
            _cropCtrl.text.trim().isEmpty ? null : _cropCtrl.text.trim(),
        date: _date,
        paymentMethod: _paymentMethod,
      );

      final repo = ref.read(expenseRepositoryProvider);

      if (!_isEditing) {
        await repo.addExpense(farmId, expense);
      } else {
        final data = expense.toFirestore()
          ..['location'] = expense.location
          ..['cropName'] = expense.cropName
          ..['paymentMethod'] = expense.paymentMethod;
        await repo.updateExpense(farmId, widget.expenseId!, data);
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
    if (farmId == null || widget.expenseId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(expenseRepositoryProvider)
          .deleteExpense(farmId, widget.expenseId!);
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
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade600 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(expensesStreamProvider, (_, __) {
      if (_isEditing && !_loadedExisting) _prefill();
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/expenses');
            }
          },
        ),
        title: Text(_isEditing ? 'Edit Expense' : 'New Expense'),
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
          padding: EdgeInsets.zero,
          children: [
            // ================= HERO WITH BACKGROUND IMAGE =================
            _Hero(
              amountText: _amountCtrl.text,
              category: _category,
              isEditing: _isEditing,
            ),

            // ================= FORM BODY =================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- Amount ----
                      _Label('Amount'),
                      const SizedBox(height: 6),
                      _amountField(),
                      const SizedBox(height: 20),

                      // ---- Category ----
                      Row(
                        children: [
                          _Label('Category'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(
                                () => _showAllCategories = !_showAllCategories),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: const Size(0, 28),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              _showAllCategories
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: AppTheme.primaryGreen,
                            ),
                            label: Text(
                              _showAllCategories
                                  ? 'Show less'
                                  : 'Show all',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _categoryGrid(),
                      const SizedBox(height: 20),

                      // ---- Description ----
                      _Label('Description'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Bought 2 bags of DAP',
                          prefixIcon: Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // ---- Location + Crop ----
                      _locationCropRow(),
                      const SizedBox(height: 20),

                      // ---- Date ----
                      _Label('Date'),
                      const SizedBox(height: 6),
                      _dateField(),
                      const SizedBox(height: 20),

                      // ---- Payment ----
                      _Label('Payment method (optional)'),
                      const SizedBox(height: 6),
                      _paymentRow(),
                      const SizedBox(height: 28),

                      // ---- Save button ----
                      _saveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO — background image + live amount preview
  // ===========================================================================
  Widget _Hero({
    required String amountText,
    required String category,
    required bool isEditing,
  }) {
    final amount = _parsedAmount ?? 0;
    final cat = ExpenseCategories.of(category);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(24),
      ),
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/hero_crop.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(
                'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.expenseOrange,
                ),
              ),
            ),
          ),
          // Tint overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF7A3000).withValues(alpha: 0.85),
                    AppTheme.expenseOrange.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEditing ? 'EDITING' : 'NEW EXPENSE',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amountText.isEmpty ? 'KSh 0' : formatKsh(amount),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      height: 1.05,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            cat.shortLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            fullDate(_date),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LABEL
  // ===========================================================================
  Widget _Label(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
          letterSpacing: 1.1,
        ),
      );

  // ===========================================================================
  // AMOUNT FIELD — compact, single-line, comfortable
  // ===========================================================================
  Widget _amountField() {
    return TextFormField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        _DecimalInputFormatter(),
      ],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppTheme.expenseOrange,
        letterSpacing: -0.2,
      ),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        prefixText: 'KSh  ',
        prefixStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black.withValues(alpha: 0.45),
        ),
        hintText: '0',
        hintStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black.withValues(alpha: 0.15),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.expenseOrange,
            width: 1.6,
          ),
        ),
      ),
      validator: (_) {
        final n = _parsedAmount;
        if (n == null) return 'Enter a valid amount';
        if (n <= 0) return 'Amount must be greater than zero';
        return null;
      },
    );
  }

  // ===========================================================================
  // CATEGORY GRID — 4 visible by default, "Show all" expands to 10
  // ===========================================================================
  Widget _categoryGrid() {
    final all = ExpenseCategories.all;
    final visible =
        _showAllCategories ? all : _visibleCategories(all);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = w >= 500 ? 4 : (w >= 340 ? 3 : 2);
        final spacing = 8.0;
        final itemW = (w - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: visible
              .map((c) => SizedBox(
                    width: itemW,
                    child: _categoryTile(c),
                  ))
              .toList(),
        );
      },
    );
  }

  /// Show the selected category plus the first N most-likely others.
  List<ExpenseCategoryStyle> _visibleCategories(
      List<ExpenseCategoryStyle> all) {
    const defaultCount = 5;
    if (all.length <= defaultCount) return all;

    // Always include the currently selected category.
    final selected = all.where((c) => c.value == _category).firstOrNull;
    final defaults = all.take(defaultCount).toList();

    if (selected != null && !defaults.any((c) => c.value == selected.value)) {
      // Replace the last default with the selected one to keep count consistent.
      defaults[defaults.length - 1] = selected;
    }
    return defaults;
  }

  Widget _categoryTile(ExpenseCategoryStyle c) {
    final selected = _category == c.value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _category = c.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? c.color.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? c.color
                  : Colors.black.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                c.icon,
                size: 20,
                color: selected ? c.color : Colors.black54,
              ),
              const SizedBox(height: 6),
              Text(
                c.shortLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? c.color : Colors.black87,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LOCATION + CROP
  // ===========================================================================
  Widget _locationCropRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 420;

        final location = TextFormField(
          controller: _locationCtrl,
          decoration: const InputDecoration(
            labelText: 'Location',
            hintText: 'Greenhouse 1',
            prefixIcon: Icon(Icons.place_outlined),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );
        final crop = TextFormField(
          controller: _cropCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Crop',
            hintText: 'Tomatoes',
            prefixIcon: Icon(Icons.grass_outlined),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );

        if (wide) {
          return Row(
            children: [
              Expanded(child: location),
              const SizedBox(width: 12),
              Expanded(child: crop),
            ],
          );
        }
        return Column(
          children: [
            location,
            const SizedBox(height: 12),
            crop,
          ],
        );
      },
    );
  }

  // ===========================================================================
  // DATE FIELD
  // ===========================================================================
  Widget _dateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fullDate(_date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              'Change',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PAYMENT CHIPS
  // ===========================================================================
  Widget _paymentRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _paymentMethods.map(_paymentChip).toList(),
    );
  }

  Widget _paymentChip(String method) {
    final selected = _paymentMethod == method;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      label: Text(method),
      selectedColor: AppTheme.primaryGreen,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: AppTheme.primaryGreen
            .withValues(alpha: selected ? 1 : 0.25),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppTheme.primaryGreen,
      ),
      onSelected: (_) =>
          setState(() => _paymentMethod = selected ? null : method),
    );
  }

  // ===========================================================================
  // SAVE BUTTON
  // ===========================================================================
  Widget _saveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_rounded, size: 20),
        label: Text(
          _isEditing ? 'Save Changes' : 'Record Expense',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}