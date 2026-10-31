import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/dashboard_palette.dart' show DPalette;

class RegisterCustomerScreen extends ConsumerStatefulWidget {
  const RegisterCustomerScreen({super.key});

  @override
  ConsumerState<RegisterCustomerScreen> createState() =>
      _RegisterCustomerScreenState();
}

class _RegisterCustomerScreenState
    extends ConsumerState<RegisterCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final tempApp = await Firebase.initializeApp(
        name: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final cred = await tempAuth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': 'customer',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await tempApp.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Customer registered successfully',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: DPalette.profit,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: DPalette.alert,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const _AccessDenied();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        if (isDesktop) return _buildDesktop(context);
        return _buildMobile(context);
      },
    );
  }

  // ===========================================================================
  // MOBILE
  // ===========================================================================
  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: DPalette.canvas,
      appBar: AppBar(
        backgroundColor: DPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Register Customer',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: DPalette.ink,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 20),
                _form(),
              ],
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _desktopHeader(),
                const SizedBox(height: 24),
                _header(isDesktop: true),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _form(isDesktop: true),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: _previewPanel(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register Customer',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: DPalette.ink,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Create an account for a farm owner on the platform.',
                style: TextStyle(fontSize: 14, color: DPalette.inkMuted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: DPalette.chipGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined,
                  size: 13, color: DPalette.leaf),
              SizedBox(width: 6),
              Text(
                'ADMIN ONLY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: DPalette.leaf,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================
  Widget _header({bool isDesktop = false}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF14532D),
            Color(0xFF2F855A),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 22 : 18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14532D).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 54 : 46,
            height: isDesktop ? 54 : 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(
              Icons.person_add_alt_1,
              color: Colors.white,
              size: isDesktop ? 26 : 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Customer',
                  style: TextStyle(
                    fontSize: isDesktop ? 19 : 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Create an account for a farm owner',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FORM
  // ===========================================================================
  Widget _form({bool isDesktop = false}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 24),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DPalette.hairline),
        boxShadow: [
          BoxShadow(
            color: DPalette.leaf.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Identity section ----
            _sectionLabel('IDENTITY'),
            const SizedBox(height: 16),
            _fieldLabel('Full name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. James Mwangi',
                prefixIcon: Icon(Icons.person_outline,
                    size: 18, color: DPalette.leaf),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'james@farm.com',
                prefixIcon: Icon(Icons.alternate_email,
                    size: 18, color: DPalette.leaf),
              ),
              validator: (v) =>
                  !v!.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Phone (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !_loading,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '0712 345 678',
                prefixIcon: Icon(Icons.phone_outlined,
                    size: 18, color: DPalette.leaf),
              ),
            ),

            const SizedBox(height: 24),

            // ---- Credentials section ----
            _sectionLabel('LOGIN CREDENTIALS'),
            const SizedBox(height: 16),
            _fieldLabel('Temporary password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              enabled: !_loading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Minimum 6 characters',
                prefixIcon: const Icon(Icons.lock_outline,
                    size: 18, color: DPalette.leaf),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: DPalette.inkFaint,
                  ),
                  onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  v!.length < 6 ? 'At least 6 characters' : null,
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DPalette.leaf,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Register customer',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The customer will be able to sign in immediately with these credentials.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: DPalette.inkMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP PREVIEW PANEL
  // ===========================================================================
  Widget _previewPanel() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: DPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DPalette.hairline),
        boxShadow: [
          BoxShadow(
            color: DPalette.leaf.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DPalette.leaf.withValues(alpha: 0.22),
                      DPalette.leaf.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_outlined,
                    size: 20, color: DPalette.leaf),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What they get',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DPalette.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Everything they need to start farming.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: DPalette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _previewItem(
            icon: Icons.login_rounded,
            title: 'Instant sign-in',
            subtitle: 'The credentials you set work right away.',
          ),
          const SizedBox(height: 16),
          _previewItem(
            icon: Icons.space_dashboard_outlined,
            title: 'Personal workspace',
            subtitle: 'Their own farms, crops, and records.',
          ),
          const SizedBox(height: 16),
          _previewItem(
            icon: Icons.insights_outlined,
            title: 'Full features',
            subtitle: 'Harvesting, sales, expenses, and reports.',
          ),

          const SizedBox(height: 24),
          const Divider(color: DPalette.hairline, height: 1),
          const SizedBox(height: 16),

          // Security note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DPalette.chipGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DPalette.leaf.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_outlined,
                    size: 16, color: DPalette.leaf),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'You can pause or delete this account at any time from User Management.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: DPalette.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DPalette.leaf.withValues(alpha: 0.18),
                DPalette.leaf.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: DPalette.leaf),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: DPalette.ink,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: DPalette.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SMALL HELPERS
  // ===========================================================================
  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: DPalette.leaf,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: DPalette.inkMuted,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: DPalette.ink,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ===========================================================================
// Access denied
// ===========================================================================
class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DPalette.canvas,
      appBar: AppBar(
        backgroundColor: DPalette.surface,
        elevation: 0,
        title: const Text(
          'Access Denied',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: DPalette.ink,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DPalette.alert.withValues(alpha: 0.18),
                      DPalette.alert.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 30, color: DPalette.alert),
              ),
              const SizedBox(height: 18),
              const Text(
                'Administrators only',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: DPalette.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Only administrators can register new customers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: DPalette.inkMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}