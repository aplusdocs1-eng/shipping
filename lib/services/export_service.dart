import 'dart:convert';
import 'dart:html' as html;

import 'package:csv/csv.dart';
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

  /// Each label map should have: trackingNumber, customerName, origin,
  /// destination, weight, description.
  static pw.Document _buildLabelsDocument(List<Map<String, String>> labels) {
    final doc = pw.Document();
    for (final label in labels) {
      final safe = label.map((k, v) => MapEntry(k, _pdfSafe(v)));
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch),
          margin: const pw.EdgeInsets.all(16),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ONE VILLAGE SHIPPING & FREIGHT',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 8),
              pw.Text(
                safe['trackingNumber'] ?? '',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Text('TO:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(safe['customerName'] ?? '', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Text('FROM:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(safe['origin'] ?? '', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Text('DESTINATION:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(safe['destination'] ?? '', style: const pw.TextStyle(fontSize: 12)),
              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(safe['description'] ?? '', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('${safe['weight'] ?? '0'} lbs', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return doc;
  }

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
