import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/models.dart';
import '../models/shipping_label_data.dart';
import '../services/customer_match_service.dart';
import '../services/database_service.dart';
import '../services/live_data_service.dart';
import '../services/ocr_service.dart';
import '../services/offline_scan_queue.dart';
import '../services/shipping_label_parser.dart';
import '../theme/app_theme.dart';

/// Warehouse package receiving: scan a barcode, capture the shipping
/// label, run OCR, match the package to a customer (or file it as an
/// Unknown Package if no confident match exists — never discarded, never
/// a fake customer), and receive it. See ShippingLabelParser /
/// CustomerMatchService for the extraction/matching logic this screen
/// orchestrates, and supabase/functions/process-package-scan for the
/// authoritative server-side half of every submission.
class WarehouseScannerScreen extends StatefulWidget {
  const WarehouseScannerScreen({super.key});

  @override
  State<WarehouseScannerScreen> createState() => _WarehouseScannerScreenState();
}

enum _ScanStep { scanning, review, success }

class _WarehouseScannerScreenState extends State<WarehouseScannerScreen> {
  final _db = DatabaseService();
  final _parser = const ShippingLabelParser();
  final _ocr = TesseractOcrEngine();
  final _picker = ImagePicker();
  MobileScannerController? _controller;

  _ScanStep _step = _ScanStep.scanning;
  bool _paused = false;
  bool _rapidScanMode = true;
  bool _processing = false;
  String? _processingMessage;
  String? _error;

  String? _barcodeValue;
  String? _barcodeType;
  Uint8List? _labelImageBytes;
  ShippingLabelData? _labelData;
  CustomerMatchResult? _matchResult;
  Map<String, dynamic>? _lastResult; // last processPackageScan response, for the success screen
  int _pendingOfflineCount = 0;

  // Editable copies shown on the review screen — staff corrections never
  // silently overwrite the OCR-derived ShippingLabelData; they're applied
  // only when Receive Package is pressed.
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final _carrierCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.itf,
        BarcodeFormat.qrCode,
        BarcodeFormat.dataMatrix,
      ],
    );
    OfflineScanQueue().startWatching();
    OfflineScanQueue().statusStream.listen((s) {
      if (!mounted) return;
      setState(() {});
    });
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final n = await OfflineScanQueue().pendingCount();
    if (mounted) setState(() => _pendingOfflineCount = n);
  }

  @override
  void dispose() {
    _controller?.dispose();
    for (final c in [
      _nameCtrl, _companyCtrl, _addr1Ctrl, _addr2Ctrl, _cityCtrl,
      _stateCtrl, _postalCtrl, _countryCtrl, _phoneCtrl, _trackingCtrl, _carrierCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_paused || _barcodeValue != null || _processing) return;
    if (capture.barcodes.isEmpty) return;
    if (capture.barcodes.length > 1) {
      setState(() => _error =
          'Multiple barcodes detected in view — move so only one package barcode is visible.');
      return;
    }
    final barcode = capture.barcodes.first;
    final value = barcode.rawValue;
    if (value == null || value.trim().isEmpty) {
      setState(() => _error = 'Barcode detected but could not be read clearly. Try again.');
      return;
    }
    setState(() {
      _error = null;
      _barcodeValue = value.trim();
      _barcodeType = barcode.format.name;
    });
  }

  Future<void> _captureLabel({required ImageSource source}) async {
    setState(() => _error = null);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _labelImageBytes = bytes);
      await _runOcrAndParse(bytes);
    } catch (e) {
      setState(() => _error = 'Could not access the camera. Check permissions and try again.');
    }
  }

  Future<void> _runOcrAndParse(Uint8List imageBytes) async {
    setState(() {
      _processing = true;
      _processingMessage = 'Reading shipping label…';
    });
    try {
      final ocrResult = await _ocr.recognize(imageBytes);
      final label = _parser.parse(
        rawOcrText: ocrResult.text,
        barcodeValue: _barcodeValue,
        barcodeType: _barcodeType,
      );
      setState(() {
        _processingMessage = 'Matching customer…';
      });
      final customers = LiveDataService().customers;
      final matchService = await _matchServiceFromSettings();
      final matchResult = matchService.match(label: label, customers: customers);

      _populateEditableFields(label, matchResult);

      setState(() {
        _labelData = label;
        _matchResult = matchResult;
        _processing = false;
        _step = _ScanStep.review;
      });
    } on OcrException catch (e) {
      setState(() {
        _processing = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _processing = false;
        _error = 'Something went wrong reading this label. You can try again or enter the '
            'tracking number manually.';
      });
    }
  }

  Future<CustomerMatchService> _matchServiceFromSettings() async {
    try {
      final s = await _db.getScannerSettings();
      return CustomerMatchService(
        autoMatchThreshold: (s['auto_match_threshold'] as num?)?.toDouble() ?? 90,
        manualReviewThreshold: (s['manual_review_threshold'] as num?)?.toDouble() ?? 70,
      );
    } catch (_) {
      return const CustomerMatchService();
    }
  }

  void _populateEditableFields(ShippingLabelData label, CustomerMatchResult match) {
    _nameCtrl.text = label.recipientName ?? '';
    _companyCtrl.text = label.recipientCompany ?? '';
    _addr1Ctrl.text = label.addressLine1 ?? '';
    _addr2Ctrl.text = label.addressLine2 ?? '';
    _cityCtrl.text = label.city ?? '';
    _stateCtrl.text = label.state ?? '';
    _postalCtrl.text = label.postalCode ?? '';
    _countryCtrl.text = label.country ?? '';
    _phoneCtrl.text = label.phone ?? '';
    _trackingCtrl.text = label.trackingNumber ?? _barcodeValue ?? '';
    _carrierCtrl.text = label.carrier ?? '';
  }

  Future<void> _enterTrackingManually() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Enter Tracking Number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 1Z999AA10123456784',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      _barcodeValue = value.trim();
      _barcodeType = 'MANUAL_ENTRY';
    });
  }

  CustomerMatchCandidate? _selectedCandidate;

  Future<void> _showManualMatchPicker() async {
    final customers = LiveDataService().customers;
    final query = TextEditingController();
    List<Customer> filtered = _matchResult?.candidates.map((c) => c.customer).toList() ?? [];
    final picked = await showDialog<Customer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Match Customer'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: query,
                    decoration: const InputDecoration(
                      hintText: 'Search by name, email, or customer ID',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (q) {
                      setDialogState(() {
                        filtered = q.trim().isEmpty
                            ? (_matchResult?.candidates.map((c) => c.customer).toList() ?? [])
                            : customers
                                  .where(
                                    (c) =>
                                        c.name.toLowerCase().contains(q.toLowerCase()) ||
                                        c.email.toLowerCase().contains(q.toLowerCase()) ||
                                        c.mailboxNumber.toLowerCase().contains(q.toLowerCase()),
                                  )
                                  .take(20)
                                  .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No matches — search above', style: TextStyle(color: AppTheme.textSecondary)),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final c = filtered[i];
                              final candidate = _matchResult?.candidates
                                  .where((m) => m.customer.id == c.id);
                              final score = candidate != null && candidate.isNotEmpty
                                  ? candidate.first.score
                                  : null;
                              return ListTile(
                                title: Text(c.name),
                                subtitle: Text(
                                  [
                                    if (c.mailboxNumber.isNotEmpty) c.mailboxNumber,
                                    c.address,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: score != null
                                    ? Text('${score.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700))
                                    : null,
                                onTap: () => Navigator.of(context).pop(c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ],
          );
        },
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedCandidate = CustomerMatchCandidate(
        customer: picked,
        score: 100,
        reason: 'Manually selected by warehouse staff',
      );
    });
  }

  Future<void> _receivePackage({bool asUnknown = false, bool allowDuplicate = false}) async {
    final label = _labelData;
    if (label == null) return;
    setState(() {
      _processing = true;
      _processingMessage = 'Receiving package…';
      _error = null;
    });

    final trackingNumber = _trackingCtrl.text.trim().isNotEmpty
        ? _trackingCtrl.text.trim()
        : (label.trackingNumber ?? _barcodeValue ?? '');
    final idempotencyKey = generatePackageIdempotencyKey(
      trackingOrBarcode: trackingNumber.isNotEmpty ? trackingNumber : (_barcodeValue ?? DateTime.now().toIso8601String()),
    );

    String? labelImagePath;
    try {
      final settings = await _db.getScannerSettings();
      if ((settings['save_label_images'] as bool? ?? true) && _labelImageBytes != null) {
        labelImagePath = await _db.uploadPackageLabel(
          warehouseEntryId: idempotencyKey.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_'),
          bytes: _labelImageBytes!,
        );
      }
    } catch (_) {
      // Storage failure shouldn't block receiving the package — the OCR
      // data and match are far more important than the photo.
    }

    final candidate = asUnknown ? null : (_selectedCandidate ?? _matchResult?.best);
    final matchStatus = asUnknown
        ? 'unknown'
        : _selectedCandidate != null
        ? 'matched'
        : switch (_matchResult?.status) {
            MatchStatus.autoMatched => 'auto_matched',
            MatchStatus.needsReview => 'needs_review',
            _ => 'unknown',
          };

    final editedLabel = label.copyWith(
      recipientName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      recipientCompany: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      addressLine1: _addr1Ctrl.text.trim().isEmpty ? null : _addr1Ctrl.text.trim(),
      addressLine2: _addr2Ctrl.text.trim().isEmpty ? null : _addr2Ctrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      postalCode: _postalCtrl.text.trim().isEmpty ? null : _postalCtrl.text.trim(),
      country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      trackingNumber: trackingNumber,
      carrier: _carrierCtrl.text.trim().isEmpty ? null : _carrierCtrl.text.trim(),
    );

    final payload = {
      'trackingNumber': trackingNumber,
      'barcodeValue': _barcodeValue,
      'barcodeType': _barcodeType,
      'parsedFields': editedLabel.toJson()
        ..['rawOcrText'] = editedLabel.rawOcrText
        ..['normalizedOcrText'] = editedLabel.normalizedOcrText,
      'matchCandidates': _matchResult?.candidates.map((c) => c.toJson()).toList(),
      'decision': {
        'customerId': candidate?.customer.id,
        'matchScore': candidate?.score ?? 0,
        'matchStatus': matchStatus,
        'reason': candidate?.reason,
      },
      'scanSource': _labelImageBytes != null ? 'camera_ocr' : 'manual_entry',
      'idempotencyKey': idempotencyKey,
      'labelImagePath': labelImagePath,
      'allowDuplicate': allowDuplicate,
      'ocrConfidence': null,
    };

    try {
      final online = await OfflineScanQueue().isOnline();
      if (!online) {
        await OfflineScanQueue().enqueue(payload);
        await _refreshPendingCount();
        setState(() {
          _processing = false;
          _lastResult = {'offline': true};
          _step = _ScanStep.success;
        });
        return;
      }

      final result = await _db.processPackageScan(payload);
      if (result['duplicate'] == true) {
        setState(() => _processing = false);
        if (!mounted) return;
        _showDuplicateDialog(result);
        return;
      }
      setState(() {
        _processing = false;
        _lastResult = result;
        _step = _ScanStep.success;
      });
      if (_rapidScanMode) {
        await Future.delayed(const Duration(milliseconds: 1600));
        if (mounted) _resetToScanning();
      }
    } catch (e) {
      // Network failure mid-submission — queue it rather than losing the
      // scan. This is exactly the offline path even though connectivity
      // *looked* fine a moment ago (flaky warehouse Wi-Fi).
      await OfflineScanQueue().enqueue(payload);
      await _refreshPendingCount();
      setState(() {
        _processing = false;
        _lastResult = {'offline': true};
        _step = _ScanStep.success;
      });
    }
  }

  void _showDuplicateDialog(Map<String, dynamic> result) {
    final existing = result['existing'] as Map<String, dynamic>?;
    final canOverride = result['canOverride'] == true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
            const SizedBox(width: 8),
            const Expanded(child: Text('Package Already Received')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Tracking Number', existing?['tracking_number']?.toString() ?? '—'),
            _kv('Customer', existing?['customer_name']?.toString() ?? 'Unknown'),
            _kv('Received', existing?['scanned_in_at']?.toString() ?? '—'),
            _kv('Received By', existing?['scanned_in_by']?.toString() ?? '—'),
            const SizedBox(height: 10),
            const Text(
              'Do not create another package unless you are certain this is a '
              'genuinely separate shipment.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          if (canOverride)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () {
                Navigator.of(context).pop();
                _receivePackage(allowDuplicate: true);
              },
              child: const Text('Receive Anyway (Admin Override)'),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
        children: [
          TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: v),
        ],
      ),
    ),
  );

  void _resetToScanning() {
    setState(() {
      _step = _ScanStep.scanning;
      _barcodeValue = null;
      _barcodeType = null;
      _labelImageBytes = null;
      _labelData = null;
      _matchResult = null;
      _selectedCandidate = null;
      _lastResult = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Warehouse Receiving'),
        actions: [
          if (_pendingOfflineCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Chip(
                  backgroundColor: Colors.white,
                  label: Text('$_pendingOfflineCount pending sync'),
                  avatar: const Icon(Icons.cloud_off, size: 16, color: AppTheme.warning),
                ),
              ),
            ),
          Row(
            children: [
              const Text('Rapid Scan', style: TextStyle(fontSize: 12)),
              Switch(
                value: _rapidScanMode,
                onChanged: (v) => setState(() => _rapidScanMode = v),
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (_step) {
        _ScanStep.scanning => _buildScanningStep(),
        _ScanStep.review => _buildReviewStep(),
        _ScanStep.success => _buildSuccessStep(),
      },
    );
  }

  Widget _buildScanningStep() {
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            color: AppTheme.danger.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!kIsWeb || true)
                MobileScanner(controller: _controller, onDetect: _onBarcodeDetected),
              if (_paused)
                Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_circle_outline, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text('Scanning Paused', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 260,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_barcodeValue != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Barcode detected\n✓ $_barcodeValue',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_processing)
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 12),
                      Text(_processingMessage ?? 'Processing…', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _barcodeValue == null || _processing
                    ? null
                    : () => _captureLabel(source: ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Capture Label'),
              ),
              OutlinedButton.icon(
                onPressed: _barcodeValue == null || _processing
                    ? null
                    : () => _captureLabel(source: ImageSource.gallery),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Upload Label'),
              ),
              OutlinedButton.icon(
                onPressed: _processing ? null : _enterTrackingManually,
                icon: const Icon(Icons.keyboard_outlined, size: 18),
                label: const Text('Enter Tracking Number'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _paused = !_paused),
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 18),
                label: Text(_paused ? 'Resume Scanning' : 'Pause Scanning'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final match = _matchResult;
    final best = _selectedCandidate ?? match?.best;
    final status = _selectedCandidate != null
        ? MatchStatus.autoMatched
        : (match?.status ?? MatchStatus.unknown);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PACKAGE DETECTED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            if (_labelImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_labelImageBytes!, height: 160, fit: BoxFit.cover, width: double.infinity),
              ),
            const SizedBox(height: 16),
            _sectionCard('Tracking & Carrier', [
              _editField('Tracking Number', _trackingCtrl),
              _editField('Carrier', _carrierCtrl),
            ]),
            _sectionCard('Recipient', [
              _editField('Name', _nameCtrl),
              _editField('Company', _companyCtrl),
              _editField('Address Line 1', _addr1Ctrl),
              _editField('Address Line 2', _addr2Ctrl),
              Row(
                children: [
                  Expanded(child: _editField('City', _cityCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _editField('State/Province', _stateCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _editField('Postal Code', _postalCtrl)),
                ],
              ),
              _editField('Country', _countryCtrl),
              _editField('Phone', _phoneCtrl),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: best != null ? AppTheme.success.withValues(alpha: 0.08) : AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: best != null ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CUSTOMER MATCH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
                  const SizedBox(height: 8),
                  if (best != null) ...[
                    Text(best.customer.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (best.customer.mailboxNumber.isNotEmpty)
                      Text('Customer ID: ${best.customer.mailboxNumber}', style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Text('Match Confidence: ${best.score.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(best.reason, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text(
                      status == MatchStatus.autoMatched ? 'STATUS: READY TO RECEIVE' : 'STATUS: NEEDS REVIEW',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: status == MatchStatus.autoMatched ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                  ] else ...[
                    const Text('No confident customer match found.', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Text(
                      'This will be received as an Unknown Package — every field extracted is still '
                      'saved, and it goes into the Unknown Packages queue for staff to resolve.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ],
                  if (match != null && match.candidates.length > 1) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    const Text('Other possible matches:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    for (final c in match.candidates.skip(best == _selectedCandidate ? 0 : 1).take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${c.customer.name} — ${c.score.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _processing ? null : () => _receivePackage(asUnknown: best == null),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(best == null ? 'Receive as Unknown Package' : 'Receive Package'),
                ),
                OutlinedButton.icon(
                  onPressed: _processing ? null : _showManualMatchPicker,
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('Manual Match'),
                ),
                OutlinedButton.icon(
                  onPressed: _processing ? null : () => _labelImageBytes == null ? null : _runOcrAndParse(_labelImageBytes!),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Re-run OCR'),
                ),
                TextButton.icon(
                  onPressed: _processing ? null : _resetToScanning,
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                  label: const Text('Reject', style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ),
            if (_processing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _editField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSuccessStep() {
    final offline = _lastResult?['offline'] == true;
    final unknown = !offline && _selectedCandidate == null && (_matchResult?.best == null);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            offline ? Icons.cloud_off : Icons.check_circle,
            color: offline ? AppTheme.warning : AppTheme.success,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            offline
                ? 'SAVED OFFLINE — WILL SYNC AUTOMATICALLY'
                : unknown
                ? 'PACKAGE RECEIVED — CUSTOMER NOT FOUND'
                : '✓ PACKAGE RECEIVED',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (_trackingCtrl.text.isNotEmpty) Text(_trackingCtrl.text),
          if (_nameCtrl.text.isNotEmpty) Text(_nameCtrl.text, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          if (_rapidScanMode)
            const Text('Ready for next scan…', style: TextStyle(color: AppTheme.textSecondary))
          else
            FilledButton(onPressed: _resetToScanning, child: const Text('Scan Next Package')),
        ],
      ),
    );
  }
}
