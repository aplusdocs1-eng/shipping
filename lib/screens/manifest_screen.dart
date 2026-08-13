import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ManifestScreen extends StatefulWidget {
  const ManifestScreen({super.key});

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> {
  final _db = DatabaseService();
  Shipment? _selectedShipment;
  DateTime? _dateFilter;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  List<Shipment> _allShipments = [];
  List<Package> _allPackages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getShipments(),
        _db.getPackages(),
      ]);
      if (!mounted) return;
      final shipments = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(Shipment.fromMap)
          .toList();
      final packages = (results[1] as List)
          .cast<Map<String, dynamic>>()
          .map(Package.fromMap)
          .toList();
      setState(() {
        _allShipments = shipments;
        _allPackages = packages;
        final filtered = _filteredShipmentsFrom(shipments);
        if (_selectedShipment != null) {
          final match = filtered.where((s) => s.id == _selectedShipment!.id);
          _selectedShipment = match.isEmpty ? null : match.first;
        }
        if (_selectedShipment == null && filtered.isNotEmpty) {
          _selectedShipment = filtered.first;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Shipment> _filteredShipmentsFrom(List<Shipment> source) {
    final date = _dateFilter;
    if (date == null) return source;
    return source.where((s) => _isSameDay(s.departureDate, date)).toList();
  }

  List<Shipment> get _filteredShipments => _filteredShipmentsFrom(_allShipments);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      helpText: 'Select manifest date',
    );
    if (picked == null) return;
    setState(() {
      _dateFilter = picked;
      final filtered = _filteredShipments;
      final stillMatches =
          _selectedShipment != null &&
          filtered.any((s) => s.id == _selectedShipment!.id);
      if (!stillMatches) {
        _selectedShipment = filtered.isNotEmpty ? filtered.first : null;
      }
    });
  }

  void _clearDateFilter() {
    setState(() {
      _dateFilter = null;
      if (_selectedShipment == null && _allShipments.isNotEmpty) {
        _selectedShipment = _allShipments.first;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Package> get _manifestPackages {
    // A date filter that matches no shipment means the manifest for that
    // date is empty — must never fall back to "no shipment selected"
    // below, which intentionally shows every package system-wide (the
    // sane default when there simply are no shipments yet at all).
    // Without this, picking a date with nothing scheduled would silently
    // show unrelated packages from every other date instead of "none".
    if (_dateFilter != null && _selectedShipment == null) return const [];
    return _allPackages.where((p) {
      final matchesShipment =
          _selectedShipment == null || p.shipmentId == _selectedShipment!.id;
      final matchesQuery =
          _query.isEmpty ||
          p.trackingNumber.toLowerCase().contains(_query.toLowerCase()) ||
          p.customerName.toLowerCase().contains(_query.toLowerCase()) ||
          p.description.toLowerCase().contains(_query.toLowerCase());
      return matchesShipment && matchesQuery;
    }).toList();
  }

  List<Package> get _unassignedPackages =>
      _allPackages.where((p) => p.shipmentId == null).toList();

  Future<void> _addPackageToManifest() async {
    if (_selectedShipment == null) return;
    final picked = await showDialog<Package>(
      context: context,
      builder: (ctx) => _PickPackageDialog(packages: _unassignedPackages),
    );
    if (picked == null) return;
    try {
      await _db.updatePackage(picked.id, {'shipment_id': _selectedShipment!.id});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add package: $e')),
      );
    }
  }

  double get _totalWeight =>
      _manifestPackages.fold(0.0, (s, p) => s + p.weight);
  double get _totalValue =>
      _manifestPackages.fold(0.0, (s, p) => s + p.declaredValue);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final shipments = _filteredShipments;
    final df = DateFormat('MMM d, yyyy');

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manifest',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Asycuda customs manifest by shipment',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _ActionBtn(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Export PDF',
                onTap: _exportPdf,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.table_chart_outlined,
                label: 'Export CSV',
                onTap: _exportCsv,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.print_outlined,
                label: 'Print',
                onTap: _printManifest,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Shipment selector
          Row(
            children: [
              const Text(
                'Shipment:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Shipment>(
                    value: _selectedShipment,
                    hint: Text(
                      _dateFilter != null
                          ? 'No shipments on ${df.format(_dateFilter!)}'
                          : 'All Packages (no shipments yet)',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    items: shipments
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Icon(
                                  s.type == ShipmentType.air
                                      ? Icons.flight
                                      : Icons.directions_boat,
                                  size: 14,
                                  color: s.type == ShipmentType.air
                                      ? AppTheme.accent
                                      : AppTheme.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${s.shipmentNumber} — ${s.origin} → ${s.destination}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedShipment = v),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Date:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: _dateFilter != null ? AppTheme.primary : AppTheme.border,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: _dateFilter != null ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dateFilter == null ? 'Any date' : df.format(_dateFilter!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _dateFilter != null ? FontWeight.w600 : FontWeight.normal,
                          color: _dateFilter != null ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      if (_dateFilter != null) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _clearDateFilter,
                          borderRadius: BorderRadius.circular(10),
                          child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selected shipment info + actions
          Row(
            children: [
              if (_selectedShipment != null) ...[
                StatusBadge(
                  label: _selectedShipment!.status.label,
                  color: _selectedShipment!.status.color,
                ),
                const SizedBox(width: 14),
                Text(
                  'Departs: ${df.format(_selectedShipment!.departureDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (_selectedShipment!.arrivalDate != null) ...[
                  const Text(
                    ' · ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  Text(
                    'Arrives: ${df.format(_selectedShipment!.arrivalDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ] else
                Text(
                  _dateFilter != null
                      ? 'No shipments depart on ${df.format(_dateFilter!)}.'
                      : 'No shipment selected.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              const Spacer(),
              if (_selectedShipment != null)
                OutlinedButton.icon(
                  onPressed: _addPackageToManifest,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Package'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary stats
          if (_selectedShipment != null)
            Row(
              children: [
                _ManStat(
                  'Total Packages',
                  _manifestPackages.length.toString(),
                  Icons.inventory_2_outlined,
                  AppTheme.primary,
                ),
                const SizedBox(width: 12),
                _ManStat(
                  'Total Weight',
                  '${_totalWeight.toStringAsFixed(1)} lbs',
                  Icons.scale_outlined,
                  AppTheme.accent,
                ),
                const SizedBox(width: 12),
                _ManStat(
                  'Declared Value',
                  '\$${_totalValue.toStringAsFixed(2)}',
                  Icons.attach_money_outlined,
                  AppTheme.success,
                ),
                const SizedBox(width: 12),
                _ManStat(
                  'Shipment #',
                  _selectedShipment!.shipmentNumber,
                  Icons.tag_outlined,
                  AppTheme.textSecondary,
                ),
              ],
            ),
          const SizedBox(height: 20),

          // Search
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Filter by tracking #, customer, description...',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
          const SizedBox(height: 16),

          // Manifest table
          Expanded(
            child: Card(
              child: Column(
                children: [
                  _ManifestTableHead(),
                  Expanded(
                    child: _manifestPackages.isEmpty
                        ? EmptyState(
                            icon: Icons.description_outlined,
                            title: 'No packages',
                            subtitle: _dateFilter != null && _selectedShipment == null
                                ? 'No shipments depart on ${df.format(_dateFilter!)}, so there\'s nothing to manifest.'
                                : 'No packages match this shipment',
                          )
                        : ListView.builder(
                            itemCount: _manifestPackages.length,
                            itemBuilder: (context, i) {
                              final p = _manifestPackages[i];
                              return _ManifestRow(index: i + 1, package: p);
                            },
                          ),
                  ),
                  // Footer totals
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(top: BorderSide(color: AppTheme.border)),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        const Expanded(child: SizedBox()),
                        const Expanded(child: SizedBox()),
                        const Expanded(child: SizedBox()),
                        Expanded(
                          child: Text(
                            '${_totalWeight.toStringAsFixed(1)} lbs',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '\$${_totalValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _manifestHeaders =>
      const ['#', 'Tracking #', 'Customer', 'Description', 'Weight', 'Value', 'Status'];

  List<List<String>> get _manifestRows => [
    for (var i = 0; i < _manifestPackages.length; i++)
      [
        (i + 1).toString(),
        _manifestPackages[i].trackingNumber,
        _manifestPackages[i].customerName,
        _manifestPackages[i].description,
        '${_manifestPackages[i].weight} lbs',
        '\$${_manifestPackages[i].declaredValue.toStringAsFixed(2)}',
        _manifestPackages[i].status.label,
      ],
  ];

  Map<String, String> get _manifestSummary => {
    'Total Packages': _manifestPackages.length.toString(),
    'Total Weight': '${_totalWeight.toStringAsFixed(1)} lbs',
    'Declared Value': '\$${_totalValue.toStringAsFixed(2)}',
  };

  Future<void> _exportPdf() async {
    await ExportService.downloadPdf(
      filename: 'manifest-${_selectedShipment?.shipmentNumber ?? 'all'}.pdf',
      title: 'Manifest — ${_selectedShipment?.shipmentNumber ?? 'All Packages'}',
      subtitle: _selectedShipment != null
          ? '${_selectedShipment!.origin} → ${_selectedShipment!.destination}'
          : null,
      headers: _manifestHeaders,
      rows: _manifestRows,
      summary: _manifestSummary,
    );
  }

  void _exportCsv() {
    ExportService.downloadCsv(
      filename: 'manifest-${_selectedShipment?.shipmentNumber ?? 'all'}.csv',
      headers: _manifestHeaders,
      rows: _manifestRows,
    );
  }

  Future<void> _printManifest() async {
    await ExportService.printPdf(
      title: 'Manifest — ${_selectedShipment?.shipmentNumber ?? 'All Packages'}',
      subtitle: _selectedShipment != null
          ? '${_selectedShipment!.origin} → ${_selectedShipment!.destination}'
          : null,
      headers: _manifestHeaders,
      rows: _manifestRows,
      summary: _manifestSummary,
    );
  }
}

class _ManifestTableHead extends StatelessWidget {
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
        SizedBox(width: 32, child: _MHead('#')),
        Expanded(flex: 2, child: _MHead('Tracking #')),
        Expanded(flex: 2, child: _MHead('Customer')),
        Expanded(flex: 2, child: _MHead('Description')),
        Expanded(child: _MHead('Weight')),
        Expanded(child: _MHead('Value')),
        Expanded(child: _MHead('Tariff Code')),
        Expanded(child: _MHead('Status')),
      ],
    ),
  );
}

class _MHead extends StatelessWidget {
  final String text;
  const _MHead(this.text);
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

class _ManifestRow extends StatelessWidget {
  final int index;
  final Package package;
  const _ManifestRow({required this.index, required this.package});

  // Simple tariff code generator for demo
  String get _tariffCode {
    final codes = [
      '6302.21.00',
      '8471.30.10',
      '6110.20.90',
      '8523.49.00',
      '4901.99.00',
      '8516.79.00',
      '6109.10.00',
      '9503.00.00',
    ];
    return codes[index % codes.length];
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            index.toString(),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            package.trackingNumber,
            style: const TextStyle(
              fontSize: 11,
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
            package.description,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Text(
            '${package.weight} lbs',
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
        ),
        Expanded(
          child: Text(
            '\$${package.declaredValue.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
        ),
        Expanded(
          child: Text(
            _tariffCode,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: StatusBadge(
            label: package.status.label,
            color: package.status.color,
          ),
        ),
      ],
    ),
  );
}

class _ManStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ManStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

class _PickPackageDialog extends StatefulWidget {
  final List<Package> packages;
  const _PickPackageDialog({required this.packages});

  @override
  State<_PickPackageDialog> createState() => _PickPackageDialogState();
}

class _PickPackageDialogState extends State<_PickPackageDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.packages.where((p) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return p.trackingNumber.toLowerCase().contains(q) ||
          p.customerName.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: const Text('Add Package to Manifest'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by tracking # or customer...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No unassigned packages found.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            p.trackingNumber,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${p.customerName} · ${p.description}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
