import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Real PDF/CSV generation and download for admin export & print
/// actions (invoices, manifests, labels). This app is web-only, so
/// CSV downloads use dart:html directly; PDF share/print goes
/// through `printing`, which drives the browser download/print
/// dialog on Flutter web.
class ExportService {
  ExportService._();

  /// The default PDF fonts (Helvetica) only support codepoints 0x00-0xFF,
  /// so any smart-typography or non-Latin1 character throws a PdfException
  /// during layout. Map the common ones to ASCII and drop the rest, since
  /// bundling a Unicode font just for this is not worth the added weight.
  static String _pdfSafe(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      switch (rune) {
        case 0x2013: // en dash
        case 0x2014: // em dash
          buffer.write('-');
          break;
        case 0x2192: // right arrow
          buffer.write('->');
          break;
        case 0x2190: // left arrow
          buffer.write('<-');
          break;
        case 0x2018:
        case 0x2019:
          buffer.write("'");
          break;
        case 0x201c:
        case 0x201d:
          buffer.write('"');
          break;
        case 0x2022: // bullet
          buffer.write('-');
          break;
        case 0x2026: // ellipsis
          buffer.write('...');
          break;
        default:
          buffer.writeCharCode(rune <= 0xff ? rune : 0x3f);
      }
    }
    return buffer.toString();
  }

  static List<String> _pdfSafeList(List<String> input) => input.map(_pdfSafe).toList();

  static List<List<String>> _pdfSafeRows(List<List<String>> input) =>
      input.map(_pdfSafeList).toList();

  static Map<String, String>? _pdfSafeMap(Map<String, String>? input) =>
      input?.map((k, v) => MapEntry(_pdfSafe(k), _pdfSafe(v)));

  static Future<void> downloadPdf({
    required String filename,
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String>? summary,
  }) async {
    final doc = _buildTableDocument(
      title: title,
      subtitle: subtitle,
      headers: headers,
      rows: rows,
      summary: summary,
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  static Future<void> printPdf({
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String>? summary,
  }) async {
    final doc = _buildTableDocument(
      title: title,
      subtitle: subtitle,
      headers: headers,
      rows: rows,
      summary: summary,
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static const _navy = PdfColor.fromInt(0xFF071B33);

  /// A 4x6" shipping label — the standard thermal label size, matching
  /// what a real warehouse label printer takes. Modeled on real carrier
  /// labels (Amazon, UPS, etc.): a genuine scannable Code128 barcode (not
  /// a decorative stripe pattern), a prominent recipient block, and a
  /// compact metadata footer with a secondary QR code. Deliberately
  /// monochrome-first (navy reads as solid black on thermal printers) so
  /// it stays legible and scannable regardless of what it's printed on.
  ///
  /// Each label map: trackingNumber (required — encoded in both codes),
  /// to/toDetail (recipient + address/location line), from/fromDetail
  /// (sender + its detail line, defaults to "One Village Shipping &
  /// Freight"), description, weight, zone (storage location, shown as a
  /// small badge if present), date (defaults to today). All optional
  /// fields are simply omitted from the label when blank.
  static pw.Document _buildLabelsDocument(List<Map<String, String>> labels) {
    final doc = pw.Document();
    for (final label in labels) {
      final safe = label.map((k, v) => MapEntry(k, _pdfSafe(v)));
      final tracking = safe['trackingNumber'] ?? '';
      final to = safe['to'] ?? safe['customerName'] ?? '';
      final toDetail = safe['toDetail'] ?? safe['destination'] ?? '';
      final from = safe['from']?.isNotEmpty == true
          ? safe['from']!
          : 'One Village Shipping & Freight';
      final fromDetail = safe['fromDetail'] ?? safe['origin'] ?? '';
      final description = safe['description'] ?? '';
      final weight = safe['weight'] ?? '';
      final zone = safe['zone'] ?? '';
      final date = safe['date']?.isNotEmpty == true
          ? safe['date']!
          : DateFormat('MMM d, yyyy').format(DateTime.now());

      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch),
          margin: const pw.EdgeInsets.all(18),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'ONE VILLAGE SHIPPING & FREIGHT',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (zone.isNotEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _navy, width: 0.75),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        zone,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy),
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(height: 2, color: _navy),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: tracking,
                      width: 220,
                      height: 58,
                      drawText: false,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      tracking,
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(height: 0.75, color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              pw.Text(
                'DELIVER TO',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 1),
              ),
              pw.SizedBox(height: 3),
              pw.Text(to, style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)),
              if (toDetail.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(toDetail, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
              ],
              pw.SizedBox(height: 12),
              pw.Text(
                'FROM',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 1),
              ),
              pw.SizedBox(height: 3),
              pw.Text(from, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (fromDetail.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(fromDetail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
              ],
              pw.Spacer(),
              pw.Container(height: 0.75, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _metaRow('WEIGHT', weight.isEmpty ? '—' : '$weight lbs'),
                        pw.SizedBox(height: 4),
                        _metaRow('DATE', date),
                        if (description.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          _metaRow('CONTENTS', description),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: tracking,
                    width: 42,
                    height: 42,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return doc;
  }

  static pw.Widget _metaRow(String label, String value) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 55,
        child: pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.5),
        ),
      ),
      pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
    ],
  );

  static Future<void> printLabels(List<Map<String, String>> labels) async {
    final doc = _buildLabelsDocument(labels);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static Future<void> downloadLabels({
    required String filename,
    required List<Map<String, String>> labels,
  }) async {
    final doc = _buildLabelsDocument(labels);
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  /// Raw PDF bytes for a live preview (e.g. via the `printing` package's
  /// PdfPreview widget) — kept separate from printLabels/downloadLabels so
  /// the preview is guaranteed to show exactly the same document that
  /// prints, rather than a hand-maintained lookalike that can drift out of
  /// sync with it.
  static Future<Uint8List> labelsPdfBytes(List<Map<String, String>> labels) {
    return _buildLabelsDocument(labels).save();
  }

  static pw.Document _buildTableDocument({
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String>? summary,
  }) {
    final safeTitle = _pdfSafe(title);
    final safeSubtitle = subtitle == null ? null : _pdfSafe(subtitle);
    final safeHeaders = _pdfSafeList(headers);
    final safeRows = _pdfSafeRows(rows);
    final safeSummary = _pdfSafeMap(summary);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(safeTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (safeSubtitle != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(safeSubtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: safeHeaders,
            data: safeRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          if (safeSummary != null && safeSummary.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Divider(),
            for (final entry in safeSummary.entries)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(entry.key, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      entry.value,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    return doc;
  }

  /// Triggers a CSV file download in the browser.
  static void downloadCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final csv = const ListToCsvConverter().convert([headers, ...rows]);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
