import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart' hide SearchBar;

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  PackageStatus? _filterStatus;
  String _searchQuery = '';
  Package? _selectedPackage;
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Package> get _filtered {
    return _allPackages.where((p) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          p.trackingNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.destination.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _filterStatus == null || p.status == _filterStatus;
      return matchesSearch && matchesStatus;
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
                          'Packages',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track and manage all shipments',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showNewPackageDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Package'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Search and filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText:
                              'Search by tracking #, customer, destination...',
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
                    _FilterDropdown(
                      value: _filterStatus,
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table
                Expanded(
                  child: Card(
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            color: AppTheme.surface,
                            border: Border(
                              bottom: BorderSide(color: AppTheme.border),
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _TableHeader('Tracking #'),
                              ),
                              Expanded(
                                flex: 2,
                                child: _TableHeader('Customer'),
                              ),
                              Expanded(flex: 2, child: _TableHeader('Route')),
                              Expanded(flex: 1, child: _TableHeader('Weight')),
                              Expanded(flex: 1, child: _TableHeader('Value')),
                              Expanded(flex: 1, child: _TableHeader('Date')),
                              Expanded(flex: 1, child: _TableHeader('Status')),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _filtered.isEmpty
                              ? const EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'No packages found',
                                  subtitle: 'Try adjusting your filters',
                                )
                              : ListView.builder(
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    final p = _filtered[index];
                                    final isSelected =
                                        _selectedPackage?.id == p.id;
                                    return _PackageRow(
                                      package: p,
                                      isSelected: isSelected,
                                      onTap: () => setState(
                                        () => _selectedPackage = isSelected
                                            ? null
                                            : p,
                                      ),
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

        // Side detail panel
        if (_selectedPackage != null)
          _PackageDetailPanel(
            package: _selectedPackage!,
            onClose: () => setState(() => _selectedPackage = null),
          ),
      ],
    );
  }

  Future<void> _showNewPackageDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const _NewPackageDialog(),
    );
    if (result != null) _load();
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final PackageStatus? value;
  final ValueChanged<PackageStatus?> onChanged;

  const _FilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PackageStatus?>(
          value: value,
          hint: const Text(
            'All Statuses',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('All Statuses', style: TextStyle(fontSize: 13)),
            ),
            ...PackageStatus.values.map(
              (s) => DropdownMenuItem(
                value: s,
                child: Row(
                  children: [
                    Icon(s.icon, size: 14, color: s.color),
                    const SizedBox(width: 6),
                    Text(s.label, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  final Package package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageRow({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.05)
              : Colors.transparent,
          border: Border(
            bottom: const BorderSide(color: AppTheme.border, width: 0.5),
            left: isSelected
                ? const BorderSide(color: AppTheme.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                package.trackingNumber,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 2, child: _rowText(package.customerName)),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.origin,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    package.destination,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(flex: 1, child: _rowText('${package.weight} kg')),
            Expanded(
              flex: 1,
              child: _rowText('\$${package.declaredValue.toStringAsFixed(0)}'),
            ),
            Expanded(
              flex: 1,
              child: _rowText(dateFormat.format(package.createdAt)),
            ),
            Expanded(
              flex: 1,
              child: StatusBadge(
                label: package.status.label,
                color: package.status.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PackageDetailPanel extends StatelessWidget {
  final Package package;
  final VoidCallback onClose;

  const _PackageDetailPanel({required this.package, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Text(
                  'Package Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: package.status.color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            package.status.icon,
                            color: package.status.color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(
                          label: package.status.label,
                          color: package.status.color,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tracking number
                  _DetailRow(
                    label: 'Tracking #',
                    value: package.trackingNumber,
                    mono: true,
                  ),
                  _DetailRow(label: 'Description', value: package.description),
                  _DetailRow(label: 'Customer', value: package.customerName),
                  _DetailRow(label: 'Origin', value: package.origin),
                  _DetailRow(label: 'Destination', value: package.destination),
                  _DetailRow(label: 'Weight', value: '${package.weight} kg'),
                  _DetailRow(
                    label: 'Declared Value',
                    value: '\$${package.declaredValue.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Created',
                    value: DateFormat('MMM d, yyyy').format(package.createdAt),
                  ),
                  if (package.estimatedDelivery != null)
                    _DetailRow(
                      label: 'Est. Delivery',
                      value: DateFormat(
                        'MMM d, yyyy',
                      ).format(package.estimatedDelivery!),
                    ),
                  if (package.notes != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.danger.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppTheme.danger,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              package.notes!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (package.events.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Tracking History',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...package.events.reversed.map(
                      (e) => _TrackingEventTile(event: e),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingEventTile extends StatelessWidget {
  final TrackingEvent event;
  const _TrackingEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 1, height: 40, color: AppTheme.border),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.location,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(event.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewPackageDialog extends StatefulWidget {
  const _NewPackageDialog();

  @override
  State<_NewPackageDialog> createState() => _NewPackageDialogState();
}

class _NewPackageDialogState extends State<_NewPackageDialog> {
  final _db = DatabaseService();
  final _customerName = TextEditingController();
  final _description = TextEditingController();
  final _origin = TextEditingController();
  final _destination = TextEditingController();
  final _weight = TextEditingController();
  final _declaredValue = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _customerName.dispose();
    _description.dispose();
    _origin.dispose();
    _destination.dispose();
    _weight.dispose();
    _declaredValue.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_customerName.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'Customer name and description are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final trackingNumber =
          'PKG-${DateTime.now().millisecondsSinceEpoch}';
      final row = await _db.insertPackage({
        'tracking_number': trackingNumber,
        'customer_name': _customerName.text.trim(),
        'description': _description.text.trim(),
        'origin': _origin.text.trim().isEmpty ? null : _origin.text.trim(),
        'destination':
            _destination.text.trim().isEmpty ? null : _destination.text.trim(),
        'weight': double.tryParse(_weight.text.trim()) ?? 0,
        'declared_value': double.tryParse(_declaredValue.text.trim()) ?? 0,
        'status': 'pending',
        'service_type': 'standard',
      });
      if (!mounted) return;
      Navigator.pop(context, row);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to create package: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'New Package',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _FormRow(
              children: [
                _FormField(
                  label: 'Customer Name',
                  hint: 'e.g. John Doe',
                  controller: _customerName,
                ),
                _FormField(
                  label: 'Description',
                  hint: 'Package contents',
                  controller: _description,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormRow(
              children: [
                _FormField(
                  label: 'Origin',
                  hint: 'City, Country',
                  controller: _origin,
                ),
                _FormField(
                  label: 'Destination',
                  hint: 'City, Country',
                  controller: _destination,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormRow(
              children: [
                _FormField(
                  label: 'Weight (kg)',
                  hint: '0.0',
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _FormField(
                  label: 'Declared Value (\$)',
                  hint: '0.00',
                  controller: _declaredValue,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _create,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Package'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final List<Widget> children;
  const _FormRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          children
              .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
              .toList()
            ..removeLast(),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  const _FormField({
    required this.label,
    required this.hint,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
