import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../data/farm_payment_info.dart';
import '../providers/farm_provider.dart';

class PaymentInfoScreen extends ConsumerStatefulWidget {
  const PaymentInfoScreen({super.key});

  @override
  ConsumerState<PaymentInfoScreen> createState() => _PaymentInfoScreenState();
}

class _PaymentInfoScreenState extends ConsumerState<PaymentInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankCtrl = TextEditingController();
  final _paybillCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _signatureCtrl = TextEditingController();

  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _paybillCtrl.dispose();
    _accountCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _signatureCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_loaded || !mounted) return;
    final info = ref.read(farmPaymentInfoProvider).value;
    if (info == null) return;
    _loaded = true;
    _bankCtrl.text = info.bankName;
    _paybillCtrl.text = info.paybill;
    _accountCtrl.text = info.account;
    _phoneCtrl.text = info.phone;
    _emailCtrl.text = info.email;
    _signatureCtrl.text = info.signature;
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
      final info = FarmPaymentInfo(
        bankName: _bankCtrl.text.trim(),
        paybill: _paybillCtrl.text.trim(),
        account: _accountCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        signature: _signatureCtrl.text.trim(),
      );
      await ref.read(farmRepositoryProvider).savePaymentInfo(farmId, info);
      if (mounted) {
        _snack('Payment details saved — they will appear on every invoice.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Could not save: $e', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade600 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(farmPaymentInfoProvider, (_, __) {
      if (!_loaded) _prefill();
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
              context.go('/settings');
            }
          },
        ),
        title: const Text('Payment Information'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _infoBanner(),
            const SizedBox(height: 24),

            _sectionLabel('Bank / M-Pesa Details'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Bank name',
                hintText: 'e.g. Equity Bank',
                prefixIcon: Icon(Icons.account_balance_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paybillCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Paybill / Till number',
                hintText: 'e.g. 247247',
                prefixIcon: Icon(Icons.numbers_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Account number',
                hintText: 'e.g. 0110123456789',
                prefixIcon: Icon(Icons.credit_card_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel('Contact Information'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. 0712 345 678',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'e.g. james@farm.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel('Signature'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signatureCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Authorized signature name',
                hintText: 'e.g. James Mwangi',
                prefixIcon: Icon(Icons.draw_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This name will appear above "Authorized Signature" on every invoice.',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black.withValues(alpha: 0.5),
                height: 1.4,
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
                    : const Text(
                        'Save Payment Details',
                        style: TextStyle(
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

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fill these once — they will automatically appear on every '
              'invoice you generate from now on.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.black.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
          letterSpacing: 1.2,
        ),
      );
}