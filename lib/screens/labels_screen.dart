import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  final _db = DatabaseService();
  final Set<String> _selected = {};
  String _query = '';
  Package? _preview;
  bool _loading = true;
  List<Package> _allPackages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _db.getPackages();
      if (mounted)
        setState(() {
          _allPackages = rows.map(Package.fromMap).toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Package> get _filtered {
    return _allPackages.where((p) {
      return _query.isEmpty ||
          p.trackingNumber.toLowerCase().contains(_query.toLowerCase()) ||
          p.customerName.toLowerCase().contains(_query.toLowerCase()) ||
          p.origin.toLowerCase().contains(_query.toLowerCase()) ||
          p.destination.toLowerCase().contains(_query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Label Generation',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Generate and print shipping labels',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_selected.isNotEmpty) ...[
                      Text(
                        '${_selected.length} selected',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _selected.clear()),
                        icon: const Icon(Icons.deselect, size: 14),
                        label: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _printSelected(context),
                      icon: const Icon(Icons.print, size: 16),
                      label: Text(
                        _selected.isEmpty
                            ? 'Select to Print'
                            : 'Print ${_selected.length} Label${_selected.length > 1 ? 's' : ''}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText:
                              'Search by tracking #, sender, recipient...',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          prefixIconConstraints: BoxConstraints(
                            minWidth: 42,
                            minHeight: 42,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        if (_selected.length == _filtered.length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(_filtered.map((p) => p.id));
                        }
                      }),
                      icon: const Icon(Icons.select_all, size: 14),
                      label: Text(
                        _selected.length == _filtered.length
                            ? 'Deselect All'
                            : 'Select All',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    child: Column(
                      children: [
                        _TableHeader(),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _filtered.isEmpty
                              ? const EmptyState(
                                  icon: Icons.label_outline,
                                  title: 'No packages',
                                  subtitle: 'No packages match your search',
                                )
                              : ListView.builder(
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, i) {
                                    final p = _filtered[i];
                                    return _LabelRow(
                                      package: p,
                                      isChecked: _selected.contains(p.id),
                                      isPreview: _preview?.id == p.id,
                                      onCheck: (v) => setState(() {
                                        if (v == true) {
                                          _selected.add(p.id);
                                        } else {
                                          _selected.remove(p.id);
                                        }
                                      }),
                                      onPreview: () => setState(
                                        () => _preview = _preview?.id == p.id
                                            ? null
                                            : p,
                                      ),
                                      onPrint: () => _printOne(context, p),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_preview != null)
          _LabelPreview(
            package: _preview!,
            onClose: () => setState(() => _preview = null),
          ),
      ],
    );
  }

  Future<void> _printOne(BuildContext context, Package p) async {
    await ExportService.printLabels([_labelDataFor(p)]);
  }

  Future<void> _printSelected(BuildContext context) async {
    final labels = _allPackages
        .where((p) => _selected.contains(p.id))
        .map(_labelDataFor)
        .toList();
    if (labels.isEmpty) return;
    await ExportService.printLabels(labels);
  }
}

/// Shared by the list's print actions and the live preview panel, so both
/// always build a label from exactly the same fields.
Map<String, String> _labelDataFor(Package p) => {
  'trackingNumber': p.trackingNumber,
  'to': p.customerName,
  'toDetail': p.destination,
  'fromDetail': p.origin,
  'description': p.description,
  'weight': p.weight.toString(),
};

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(
      color: AppTheme.surface,
      border: Border(bottom: BorderSide(color: AppTheme.border)),
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    child: const Row(
      children: [
        SizedBox(width: 44),
        Expanded(flex: 2, child: _Head('Tracking #')),
        Expanded(flex: 2, child: _Head('Customer')),
        Expanded(flex: 2, child: _Head('Origin')),
        Expanded(flex: 2, child: _Head('Destination')),
        Expanded(child: _Head('Weight')),
        Expanded(child: _Head('Description')),
        Expanded(child: _Head('Status')),
        SizedBox(width: 120, child: _Head('Actions')),
      ],
    ),
  );
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
      letterSpacing: 0.4,
    ),
  );
}

class _LabelRow extends StatelessWidget {
  final Package package;
  final bool isChecked;
  final bool isPreview;
  final ValueChanged<bool?> onCheck;
  final VoidCallback onPreview;
  final VoidCallback onPrint;
  const _LabelRow({
    required this.package,
    required this.isChecked,
    required this.isPreview,
    required this.onCheck,
    required this.onPreview,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 100),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: isPreview
          ? AppTheme.primary.withOpacity(0.03)
          : isChecked
          ? AppTheme.success.withOpacity(0.02)
          : Colors.transparent,
      border: Border(
        bottom: const BorderSide(color: AppTheme.border, width: 0.5),
        left: isPreview
            ? const BorderSide(color: AppTheme.primary, width: 3)
            : BorderSide.none,
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          child: Checkbox(
            value: isChecked,
            onChanged: onCheck,
            activeColor: AppTheme.primary,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            package.trackingNumber,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppTheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            package.customerName,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            package.origin,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            package.destination,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Text(
            '${package.weight} lbs',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            package.description,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: StatusBadge(
            label: package.status.label,
            color: package.status.color,
          ),
        ),
        SizedBox(
          width: 120,
          child: Row(
            children: [
              InkWell(
                onTap: onPreview,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: isPreview
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onPrint,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.print_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
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

/// Renders the *actual* PDF that would print (via PdfPreview, from the
/// `printing` package) rather than a hand-built lookalike — so what's
/// shown here can never drift out of sync with what comes out of the
/// printer. PdfPreview's own toolbar provides zoom plus print/share
/// actions already wired to the same bytes.
class _LabelPreview extends StatelessWidget {
  final Package package;
  final VoidCallback onClose;
  const _LabelPreview({required this.package, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Text(
                  'Label Preview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              key: ValueKey(package.id),
              build: (format) => ExportService.labelsPdfBytes([_labelDataFor(package)]),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: '${package.trackingNumber}-label.pdf',
              actionBarTheme: const PdfActionBarTheme(iconColor: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

