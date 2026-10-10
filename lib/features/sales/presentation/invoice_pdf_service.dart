import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../farms/data/farm_model.dart';
import '../../farms/data/farm_payment_info.dart';
import '../data/sale_model.dart';

class InvoicePdfService {
  static Future<void> downloadInvoice({
    required Sale sale,
    Farm? farm,
    FarmPaymentInfo? payment,
  }) async {
    final bytes = await buildInvoicePdf(
      sale: sale,
      farm: farm,
      payment: payment,
    );
    final number = invoiceNumber(sale);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${number}_${sale.buyer.isEmpty ? 'invoice' : _slug(sale.buyer)}.pdf',
    );
  }

  static Future<void> printInvoice({
    required Sale sale,
    Farm? farm,
    FarmPaymentInfo? payment,
  }) async {
    final bytes = await buildInvoicePdf(
      sale: sale,
      farm: farm,
      payment: payment,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: invoiceNumber(sale),
    );
  }

  static Future<Uint8List> buildInvoicePdf({
    required Sale sale,
    Farm? farm,
    FarmPaymentInfo? payment,
  }) async {
    final doc = pw.Document(
      title: 'Invoice ${invoiceNumber(sale)}',
      author: farm?.farmName ?? 'GreenHarvest',
      creator: 'GreenHarvest Farm Management',
    );

    const ink = PdfColor.fromInt(0xFF1F2937);
    const muted = PdfColor.fromInt(0xFF6B7280);
    const line = PdfColor.fromInt(0xFFE5E7EB);
    const accent = PdfColor.fromInt(0xFF14532D);
    const surface = PdfColor.fromInt(0xFFF9FAFB);

    pw.MemoryImage? logo;
    final logoUrl = farm?.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final resp = await http
            .get(Uri.parse(logoUrl))
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          logo = pw.MemoryImage(resp.bodyBytes);
        }
      } catch (_) {}
    }

    final saleDate = sale.saleDate ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy').format(saleDate);
    final timeStr = DateFormat('HH:mm').format(saleDate);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          // ============ HEADER ============
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 56,
                    height: 56,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      image: pw.DecorationImage(
                        image: logo,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  )
                else
                  pw.Container(
                    width: 56,
                    height: 56,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      'GH',
                      style: pw.TextStyle(
                        color: accent,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (farm?.farmName.isNotEmpty ?? false)
                            ? farm!.farmName
                            : 'GreenHarvest',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (farm?.location.isNotEmpty == true)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(
                            farm!.location,
                            style: const pw.TextStyle(
                              color: PdfColors.grey300,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Farm Management System',
                          style: const pw.TextStyle(
                            color: PdfColors.grey400,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ============ BILL-TO + META ============
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILL TO',
                      style: pw.TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      sale.buyer.isEmpty ? '(no buyer)' : sale.buyer,
                      style: pw.TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (sale.location.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        sale.location,
                        style: const pw.TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _metaRow('Invoice #', invoiceNumber(sale), ink, muted),
                  _metaRow('Date', dateStr, ink, muted),
                  _metaRow('Time', timeStr, ink, muted),
                  _metaRow('Status', sale.status.toUpperCase(), ink, muted),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ============ LINE ITEMS ============
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: line, width: 0.6),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: surface,
                    border: pw.Border(
                      bottom: pw.BorderSide(color: line, width: 0.6),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          'DESCRIPTION',
                          style: pw.TextStyle(
                            color: muted,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'QTY',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: muted,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'PRICE',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: muted,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          'TOTAL',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: muted,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              sale.cropName.isEmpty
                                  ? 'Produce'
                                  : sale.cropName,
                              style: pw.TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (sale.location.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                sale.location,
                                style: const pw.TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${_fmtNum(sale.quantity)} ${sale.unit}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(color: ink, fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          _ksh(sale.pricePerUnit),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(color: ink, fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          _ksh(sale.totalAmount),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ============ TOTALS ============
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: surface,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: line, width: 0.6),
                    ),
                    child: pw.Text(
                      sale.status == 'pending'
                          ? 'PAYMENT PENDING'
                          : 'PAYMENT RECEIVED',
                      style: pw.TextStyle(
                        color: sale.status == 'pending'
                            ? const PdfColor.fromInt(0xFFEF6C00)
                            : accent,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _totalLine('Subtotal', _ksh(sale.totalAmount), ink, muted),
                  pw.SizedBox(height: 4),
                  _totalLine('Tax', '—', ink, muted),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: pw.BoxDecoration(
                      color: accent,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Text(
                          _ksh(sale.totalAmount),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ============ PAYMENT INSTRUCTIONS + SIGNATURE ============
          if (payment != null && !payment.isEmpty) ...[
            pw.SizedBox(height: 28),
            _paymentBlock(payment, accent, muted, ink, line, surface),
          ],

          pw.SizedBox(height: 32),

          // ============ FOOTER ============
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: line, width: 0.6),
              ),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Thank you for your business',
                  style: pw.TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated by ${(farm?.farmName.isNotEmpty ?? false) ? farm!.farmName : "GreenHarvest"} · GreenHarvest Farm Management',
                  style: const pw.TextStyle(color: muted, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ===========================================================================
  // PAYMENT BLOCK
  // ===========================================================================
  static pw.Widget _paymentBlock(
    FarmPaymentInfo p,
    PdfColor accent,
    PdfColor muted,
    PdfColor ink,
    PdfColor line,
    PdfColor surface,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: line, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAYMENT INSTRUCTIONS',
            style: pw.TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 12),

          // ---- Bank details ----
          if (p.hasPayment) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (p.bankName.isNotEmpty)
                        _payRow('Bank', p.bankName, ink, muted),
                      if (p.paybill.isNotEmpty)
                        _payRow('Paybill / Till', p.paybill, ink, muted),
                      if (p.account.isNotEmpty)
                        _payRow('Account', p.account, ink, muted),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // ---- Contact ----
          if (p.hasContact) ...[
            if (p.hasPayment) pw.SizedBox(height: 12),
            pw.Text(
              'CONTACT',
              style: pw.TextStyle(
                color: muted,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 6),
            if (p.phone.isNotEmpty) _payRow('Phone', p.phone, ink, muted),
            if (p.email.isNotEmpty) _payRow('Email', p.email, ink, muted),
          ],

          // ---- Signature ----
          if (p.signature.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(flex: 3, child: pw.SizedBox()),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Signature line
                      pw.Container(
                        height: 32,
                        alignment: pw.Alignment.bottomCenter,
                        child: pw.Text(
                          p.signature,
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                      pw.Container(
                        width: double.infinity,
                        height: 0.8,
                        color: ink,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Authorized Signature',
                        style: pw.TextStyle(
                          color: muted,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(flex: 3, child: pw.SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _payRow(
    String label,
    String value,
    PdfColor ink,
    PdfColor muted,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================
  static String invoiceNumber(Sale s) {
    final id = s.id.isEmpty ? '00000000' : s.id;
    final tail = id.length > 8 ? id.substring(id.length - 8) : id;
    return 'INV-${tail.toUpperCase()}';
  }

  static pw.Widget _metaRow(
    String label,
    String value,
    PdfColor ink,
    PdfColor muted,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label  ',
            style: pw.TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalLine(
    String label,
    String value,
    PdfColor ink,
    PdfColor muted,
  ) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label  ',
          style: pw.TextStyle(color: muted, fontSize: 10),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static String _ksh(double v) {
    final n = NumberFormat('#,##0', 'en_KE');
    return 'KSh ${n.format(v)}';
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _slug(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}