import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../farms/data/farm_model.dart';
import '../../farms/data/farm_payment_info.dart';
import '../data/sale_model.dart';

class InvoicePdfService {
  InvoicePdfService._();

  static const _accent     = PdfColor.fromInt(0xFF14532D);
  static const _ink        = PdfColor.fromInt(0xFF111827);
  static const _muted      = PdfColor.fromInt(0xFF6B7280);
  static const _faint      = PdfColor.fromInt(0xFF9CA3AF);
  static const _line       = PdfColor.fromInt(0xFFE5E7EB);
  static const _surface    = PdfColor.fromInt(0xFFF9FAFB);
  static const _accentSoft = PdfColor.fromInt(0xFFF0FDF4);
  static const _pending    = PdfColor.fromInt(0xFFEF6C00);

  // -------------------------------------------------------------------------
  // Public API — the only three things sale_invoice_screen.dart calls
  // -------------------------------------------------------------------------
  static String invoiceNumber(Sale sale) {
    final id = (sale.id ?? '').replaceAll('-', '');
    final short = id.length >= 8 ? id.substring(0, 8) : id.padRight(8, '0');
    final d = sale.saleDate ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'INV-$y$m$day-${short.toUpperCase()}';
  }

  static Future<void> printInvoice({
    required Sale sale,
    Farm? farm,
    FarmPaymentInfo? payment,
  }) async {
    final bytes = await _build(sale: sale, farm: farm, payment: payment);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> downloadInvoice({
    required Sale sale,
    Farm? farm,
    FarmPaymentInfo? payment,
  }) async {
    final bytes = await _build(sale: sale, farm: farm, payment: payment);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${invoiceNumber(sale)}.pdf',
    );
  }

  // -------------------------------------------------------------------------
  // PDF construction — mirrors the on-screen _InvoicePreview
  // -------------------------------------------------------------------------
  static Future<Uint8List> _build({
    required Sale sale,
    Farm? farm,
    FarmPaymentInfo? payment,
  }) async {
    final doc = pw.Document();
    final isPending = sale.status == 'pending';

    pw.Widget kv(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 60,
                child: pw.Text(label,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ),
              pw.Expanded(
                child: pw.Text(value,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    )),
              ),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          // ---- Header ---------------------------------------------------
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _accent,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 44,
                  height: 44,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    (farm?.farmName.isNotEmpty == true
                            ? farm!.farmName.substring(0, 1)
                            : 'G')
                        .toUpperCase(),
                    style: pw.TextStyle(
                      color: _accent,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        farm?.farmName.isNotEmpty == true
                            ? farm!.farmName
                            : 'GreenHarvest',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (farm?.location.isNotEmpty == true)
                        pw.Text(
                          farm!.location,
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFCBD5E1),
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 3,
                        )),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      invoiceNumber(sale),
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ---- Meta strip -----------------------------------------------
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _surface,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                _metaCell('DATE', _dateStr(sale.saleDate)),
                _metaDivider(),
                _metaCell('TIME', _timeStr(sale.saleDate)),
                _metaDivider(),
                _metaCell(
                  'STATUS',
                  isPending ? 'Pending' : 'Completed',
                  color: isPending ? _pending : _accent,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ---- Bill to + amount -----------------------------------------
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILLED TO',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: _faint,
                          letterSpacing: 1.2,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      sale.buyer.isEmpty ? '(no buyer)' : sale.buyer,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    if (sale.location.isNotEmpty)
                      pw.Text(
                        sale.location,
                        style: const pw.TextStyle(fontSize: 10, color: _muted),
                      ),
                  ],
                ),
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: _accentSoft,
                  borderRadius: pw.BorderRadius.circular(5),
                  border: pw.Border.all(color: _accent, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      isPending ? 'AMOUNT DUE' : 'AMOUNT PAID',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: isPending ? _pending : _accent,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _ksh(sale.totalAmount),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: isPending ? _pending : _accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ---- Line item header -----------------------------------------
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _ink)),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text('DESCRIPTION',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text('QTY',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink)),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text('AMOUNT',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink)),
                ),
              ],
            ),
          ),

          // ---- Line item row --------------------------------------------
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        sale.cropName.isEmpty ? 'Produce' : sale.cropName,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      pw.Text(
                        [
                          if (sale.location.isNotEmpty) sale.location,
                          '${_ksh(sale.pricePerUnit)} / ${sale.unit}',
                        ].join('  ·  '),
                        style: const pw.TextStyle(fontSize: 9, color: _muted),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    '${_num(sale.quantity)} ${sale.unit}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 10, color: _ink),
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    _ksh(sale.totalAmount),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- Totals ---------------------------------------------------
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Spacer(),
              pw.SizedBox(
                width: 200,
                child: pw.Column(
                  children: [
                    _totalLine('Subtotal', _ksh(sale.totalAmount)),
                    pw.SizedBox(height: 4),
                    _totalLine('Tax', '—'),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: pw.BoxDecoration(
                        color: _accent,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            isPending ? 'AMOUNT DUE' : 'AMOUNT PAID',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Spacer(),
                          pw.Text(
                            _ksh(sale.totalAmount),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
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

          // ---- Payment instructions ------------------------------------
          if (payment != null && !payment.isEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _accentSoft,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _accent, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PAYMENT INSTRUCTIONS',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _accent,
                        letterSpacing: 1.2,
                      )),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (payment.bankName.isNotEmpty)
                              kv('Bank', payment.bankName),
                            if (payment.paybill.isNotEmpty)
                              kv('Paybill', payment.paybill),
                            if (payment.account.isNotEmpty)
                              kv('Account', payment.account),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (payment.phone.isNotEmpty)
                              kv('Phone', payment.phone),
                            if (payment.email.isNotEmpty)
                              kv('Email', payment.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (payment.signature.isNotEmpty) ...[
                    pw.SizedBox(height: 18),
                    pw.Row(
                      children: [
                        pw.Spacer(),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(payment.signature,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _ink,
                                )),
                            pw.SizedBox(height: 3),
                            pw.Container(
                                width: 150, height: 0.7, color: _ink),
                            pw.SizedBox(height: 3),
                            pw.Text('AUTHORIZED SIGNATURE',
                                style: const pw.TextStyle(
                                  fontSize: 7,
                                  color: _faint,
                                  letterSpacing: 1.2,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ---- Footer ---------------------------------------------------
          pw.SizedBox(height: 20),
          pw.Divider(color: _line, height: 1),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Thank you for your business',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _accent,
                        )),
                    pw.Text(
                      'Generated by ${farm?.farmName ?? 'GreenHarvest'} · GreenHarvest Farm Management',
                      style: const pw.TextStyle(fontSize: 8, color: _faint),
                    ),
                  ],
                ),
              ),
              pw.Text(
                invoiceNumber(sale),
                style: const pw.TextStyle(fontSize: 8, color: _faint),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // -------------------------------------------------------------------------
  // Small helpers
  // -------------------------------------------------------------------------
  static pw.Widget _metaCell(String label, String value, {PdfColor? color}) =>
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: _faint,
                  letterSpacing: 1,
                )),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: color ?? _ink,
                )),
          ],
        ),
      );

  static pw.Widget _metaDivider() => pw.Container(
        width: 1,
        height: 20,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8),
        color: _line,
      );

  static pw.Widget _totalLine(String label, String value) => pw.Row(
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 10, color: _muted)),
          pw.Spacer(),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              )),
        ],
      );

  static String _ksh(double v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return 'KSh $b';
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _dateStr(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _timeStr(DateTime? d) {
    if (d == null) return '—';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}