import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../crops/providers/crop_provider.dart' show selectedFarmIdProvider;
import '../../expenses/expense_format.dart';
import '../../farms/data/farm_model.dart';
import '../../farms/data/farm_payment_info.dart';
import '../../farms/providers/farm_provider.dart';
import '../data/sale_model.dart';
import '../data/sale_style.dart';
import '../providers/sale_provider.dart';
import '../services/invoice_pdf_service.dart';

// =============================================================================
// PALETTE — matches the PDF.
// =============================================================================
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _faint = Color(0xFF9CA3AF);
const Color _line = Color(0xFFE5E7EB);
const Color _accent = Color(0xFF14532D);
const Color _accentSoft = Color(0xFFF0FDF4);
const Color _surface = Color(0xFFF9FAFB);
const Color _pending = Color(0xFFEF6C00);

class SaleInvoiceScreen extends ConsumerStatefulWidget {
  final String saleId;
  const SaleInvoiceScreen({super.key, required this.saleId});

  @override
  ConsumerState<SaleInvoiceScreen> createState() => _SaleInvoiceScreenState();
}

class _SaleInvoiceScreenState extends ConsumerState<SaleInvoiceScreen> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('Select a farm first')));
    }

    final salesAsync = ref.watch(salesStreamProvider);
    final farmsAsync = ref.watch(farmsStreamProvider);
    final paymentAsync = ref.watch(farmPaymentInfoProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/sales');
            }
          },
        ),
        title: const Text('Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy details',
            onPressed: () {
              salesAsync.whenData((sales) {
                final sale =
                    sales.where((s) => s.id == widget.saleId).firstOrNull;
                if (sale != null) _copyInvoice(context, sale);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: _downloading
                ? null
                : () async {
                    final sale = salesAsync.value
                        ?.where((s) => s.id == widget.saleId)
                        .firstOrNull;
                    if (sale == null) return;
                    final farm = farmsAsync.value
                        ?.where((f) => f.id == farmId)
                        .firstOrNull;
                    final payment = paymentAsync.value;
                    setState(() => _downloading = true);
                    try {
                      await InvoicePdfService.printInvoice(
                        sale: sale,
                        farm: farm,
                        payment: payment,
                      );
                    } catch (e) {
                      if (mounted) _snack('Print failed: $e');
                    } finally {
                      if (mounted) setState(() => _downloading = false);
                    }
                  },
          ),
        ],
      ),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sales) {
          final sale =
              sales.where((s) => s.id == widget.saleId).firstOrNull;
          if (sale == null) {
            return const Center(child: Text('Sale not found.'));
          }

          return farmsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (farms) {
              final farm = farms.where((f) => f.id == farmId).firstOrNull;
              final payment = paymentAsync.value;
              return Column(
                children: [
                  Expanded(
                    child: _InvoicePreview(
                      sale: sale,
                      farm: farm,
                      payment: payment,
                      onEditPayment: () =>
                          context.push('/settings/payment-info'),
                    ),
                  ),
                  _DownloadBar(
                    loading: _downloading,
                    onDownload: () => _download(sale, farm, payment),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _download(
    Sale sale,
    Farm? farm,
    FarmPaymentInfo? payment,
  ) async {
    setState(() => _downloading = true);
    try {
      await InvoicePdfService.downloadInvoice(
        sale: sale,
        farm: farm,
        payment: payment,
      );
      if (mounted) _snack('Invoice ready — choose where to save');
    } catch (e) {
      if (mounted) _snack('Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _copyInvoice(BuildContext context, Sale s) {
    final b = StringBuffer()
      ..writeln('INVOICE ${InvoicePdfService.invoiceNumber(s)}')
      ..writeln('Date: ${s.saleDate != null ? fullDate(s.saleDate!) : '—'}')
      ..writeln()
      ..writeln('Bill To:')
      ..writeln(s.buyer.isEmpty ? '(no buyer)' : s.buyer)
      ..writeln()
      ..writeln('Item:')
      ..writeln(
          '${s.cropName}  ${s.quantity.toStringAsFixed(0)} ${s.unit}  ×  ${formatKsh(s.pricePerUnit)}')
      ..writeln()
      ..writeln('Total: ${formatKsh(s.totalAmount)}')
      ..writeln('Status: ${SaleStyle.statusLabel(s.status).toUpperCase()}');

    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice details copied')),
    );
  }
}

// ===========================================================================
// DOWNLOAD BAR
// ===========================================================================
class _DownloadBar extends StatelessWidget {
  final bool loading;
  final VoidCallback onDownload;

  const _DownloadBar({required this.loading, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined, size: 20),
            label: Text(
              loading ? 'Preparing PDF…' : 'Download PDF',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// INVOICE PREVIEW
// ===========================================================================
class _InvoicePreview extends StatelessWidget {
  final Sale sale;
  final Farm? farm;
  final FarmPaymentInfo? payment;
  final VoidCallback onEditPayment;

  const _InvoicePreview({
    required this.sale,
    this.farm,
    this.payment,
    required this.onEditPayment,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  _metaStrip(),
                  _billTo(),
                  _lineItems(),
                  _totals(),
                  if (payment != null && !payment!.isEmpty) ...[
                    _paymentSection(payment!, onEditPayment),
                    _signatureBlock(payment!),
                  ] else
                    _emptyPaymentPrompt(onEditPayment),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------------------
  Widget _header() {
    final hasLogo = farm?.logoUrl != null && farm!.logoUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      color: _accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ---- Logo ----
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              image: hasLogo
                  ? DecorationImage(
                      image: NetworkImage(farm!.logoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: hasLogo
                ? null
                : const Text(
                    'GH',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          // ---- Farm details ----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farm?.farmName.isNotEmpty == true
                      ? farm!.farmName
                      : 'GreenHarvest',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                if (farm?.location.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    farm!.location,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                const Text(
                  'Farm Management',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          // ---- INVOICE wordmark ----
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'INVOICE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  InvoicePdfService.invoiceNumber(sale),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // META STRIP
  // -------------------------------------------------------------------------
  Widget _metaStrip() {
    final d = sale.saleDate;
    final isPending = sale.status == 'pending';
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _metaCell(
            'ISSUE DATE',
            d != null ? fullDate(d) : '—',
          ),
          _metaDivider(),
          _metaCell(
            'ISSUE TIME',
            d != null ? _timeOf(d) : '—',
          ),
          _metaDivider(),
          _metaCell(
            'PAYMENT STATUS',
            isPending ? 'Pending' : 'Completed',
            valueColor: isPending ? _pending : _accent,
          ),
          _metaDivider(),
          _metaCell(
            'AMOUNT',
            formatKsh(sale.totalAmount),
            alignEnd: true,
          ),
        ],
      ),
    );
  }

  Widget _metaCell(
    String label,
    String value, {
    bool alignEnd = false,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: _faint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? _ink,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaDivider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: _line,
      );

  // -------------------------------------------------------------------------
  // BILL TO
  // -------------------------------------------------------------------------
  Widget _billTo() {
    final isPending = sale.status == 'pending';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BILLED TO',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: _faint,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sale.buyer.isEmpty ? '(no buyer)' : sale.buyer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                if (sale.location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sale.location,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ---- Summary pill ----
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isPending
                  ? _pending.withValues(alpha: 0.08)
                  : _accentSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPending
                    ? _pending.withValues(alpha: 0.25)
                    : _accent.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isPending ? 'AMOUNT DUE' : 'AMOUNT PAID',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isPending ? _pending : _accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatKsh(sale.totalAmount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isPending ? _pending : _accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // LINE ITEMS
  // -------------------------------------------------------------------------
  Widget _lineItems() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Table header ----
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _ink, width: 1),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'QUANTITY',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'UNIT PRICE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'AMOUNT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ---- Item row ----
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _line, width: 0.8),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.cropName.isEmpty ? 'Produce' : sale.cropName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (sale.location.isNotEmpty) sale.location,
                          'Grade A',
                          'Harvest batch',
                        ].join('  ·  '),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${_fmtNum(sale.quantity)} ${sale.unit}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatKsh(sale.pricePerUnit),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _ink,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    formatKsh(sale.totalAmount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
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

  // -------------------------------------------------------------------------
  // TOTALS
  // -------------------------------------------------------------------------
  Widget _totals() {
    final isPending = sale.status == 'pending';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _totalLine('Subtotal', formatKsh(sale.totalAmount)),
                const SizedBox(height: 6),
                _totalLine('Tax', '—'),
                const SizedBox(height: 6),
                _totalLine('Shipping', '—'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isPending ? 'AMOUNT DUE' : 'AMOUNT PAID',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatKsh(sale.totalAmount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // PAYMENT SECTION
  // -------------------------------------------------------------------------
  Widget _paymentSection(FarmPaymentInfo p, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _accentSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _accent.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PAYMENT INSTRUCTIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                    letterSpacing: 1.6,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined,
                            size: 12, color: _accent),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Two-column grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: p.hasPayment
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('BANK DETAILS'),
                            const SizedBox(height: 8),
                            if (p.bankName.isNotEmpty)
                              _kv('Bank', p.bankName),
                            if (p.paybill.isNotEmpty)
                              _kv('Paybill / Till', p.paybill),
                            if (p.account.isNotEmpty)
                              _kv('Account', p.account),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: p.hasContact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('CONTACT US'),
                            const SizedBox(height: 8),
                            if (p.phone.isNotEmpty)
                              _kv('Phone', p.phone),
                            if (p.email.isNotEmpty)
                              _kv('Email', p.email),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          color: _faint,
          letterSpacing: 1.4,
        ),
      );

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SIGNATURE
  // -------------------------------------------------------------------------
  Widget _signatureBlock(FarmPaymentInfo p) {
    if (p.signature.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: 220,
            child: Column(
              children: [
                SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      p.signature,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: _ink,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: _ink,
                ),
                const SizedBox(height: 6),
                const Text(
                  'AUTHORIZED SIGNATURE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: _faint,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // EMPTY PAYMENT PROMPT
  // -------------------------------------------------------------------------
  Widget _emptyPaymentPrompt(VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _line,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                size: 17,
                color: _accent,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add payment instructions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bank, paybill, contact and signature — shown on every invoice.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // FOOTER
  // -------------------------------------------------------------------------
  Widget _footer() {
    final farmName = farm?.farmName ?? 'GreenHarvest';
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thank you for your business',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Generated by $farmName · GreenHarvest Farm Management',
                  style: const TextStyle(fontSize: 9.5, color: _faint),
                ),
              ],
            ),
          ),
          Text(
            InvoicePdfService.invoiceNumber(sale),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: _faint,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------------------
  static String _timeOf(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}