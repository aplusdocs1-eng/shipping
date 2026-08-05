import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class PreAlertsScreen extends StatefulWidget {
  const PreAlertsScreen({super.key});

  @override
  State<PreAlertsScreen> createState() => _PreAlertsScreenState();
}

class _PreAlertsScreenState extends State<PreAlertsScreen> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  PreAlertStatus? _filterStatus;
  String? _filterType;
  PreAlert? _selected;
  bool _loading = true;
  List<PreAlert> _allAlerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _db.getPreAlerts();
      if (mounted)
        setState(() {
          _allAlerts = rows.map(PreAlert.fromMap).toList();
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

  List<PreAlert> get _filtered {
    return _allAlerts.where((p) {
      final matchSearch =
          _searchQuery.isEmpty ||
          p.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.trackingNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchStatus = _filterStatus == null || p.status == _filterStatus;
      final matchType = _filterType == null || p.freightType == _filterType;
      return matchSearch && matchStatus && matchType;
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
                          'Pre-Alerts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Customer pre-declared incoming packages',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showNewPreAlertDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Pre-Alert'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Summary
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 700 ? 5 : 3;
                    return GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: PreAlertStatus.values.map((s) {
                        final count = _allAlerts
                            .where((p) => p.status == s)
                            .length;
                        return _PreAlertStatCard(status: s, count: count);
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Filter row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText:
                              'Search by customer, tracking #, description...',
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
                    _DropFilter<PreAlertStatus?>(
                      hint: 'All Statuses',
                      value: _filterStatus,
                      items: [null, ...PreAlertStatus.values],
                      itemLabel: (v) => v == null ? 'All Statuses' : v.label,
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                    const SizedBox(width: 8),
                    _DropFilter<String?>(
                      hint: 'All Types',
                      value: _filterType,
                      items: [null, 'air', 'sea'],
                      itemLabel: (v) => v == null
                          ? 'All Types'
                          : v == 'air'
                          ? '✈ Air'
                          : '🚢 Sea',
                      onChanged: (v) => setState(() => _filterType = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table
                Expanded(
                  child: Card(
                    child: Column(
                      children: [
                        _TableHead(
                          cols: const [
                            'Customer',
                            'Tracking #',
                            'Carrier',
                            'Description',
                            'Weight',
                            'Value',
                            'Type',
                            'Date',
                            'Status',
                          ],
                        ),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _filtered.isEmpty
                              ? const EmptyState(
                                  icon: Icons.notification_add_outlined,
                                  title: 'No pre-alerts',
                                  subtitle: 'No pre-alerts match your filters',
                                )
                              : ListView.builder(
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, i) {
                                    final p = _filtered[i];
                                    return _PreAlertRow(
                                      preAlert: p,
                                      isSelected: _selected?.id == p.id,
                                      onTap: () => setState(
                                        () => _selected = _selected?.id == p.id
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

        if (_selected != null)
          _PreAlertDetail(
            preAlert: _selected!,
            onClose: () => setState(() => _selected = null),
            onStatusChange: _updateStatus,
          ),
      ],
    );
  }

  Future<void> _updateStatus(PreAlert alert, PreAlertStatus status) async {
    final dbValue = switch (status) {
      PreAlertStatus.pending => 'pending',
      PreAlertStatus.received => 'received',
      PreAlertStatus.processing => 'processing',
      PreAlertStatus.ready => 'ready',
      PreAlertStatus.completed => 'completed',
    };
    try {
      await _db.updatePreAlert(alert.id, {'status': dbValue});
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final matches = _allAlerts.where((a) => a.id == alert.id);
      setState(() {
        _selected = matches.isEmpty ? null : matches.first;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _showNewPreAlertDialog(BuildContext context) async {
    final customerName = TextEditingController();
    final tracking = TextEditingController();
    final carrier = TextEditingController();
    final description = TextEditingController();
    final weight = TextEditingController();
    final declaredValue = TextEditingController();
    String freightType = 'Air';
    bool saving = false;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 540,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'New Pre-Alert',
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
                _DialogField('Customer', 'Full name', controller: customerName),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DialogField(
                        'Tracking Number',
                        'e.g. 1Z999AA10123...',
                        controller: tracking,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogField('Carrier', 'UPS, FedEx, USPS...', controller: carrier),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DialogField('Description', 'What is in the package?', controller: description),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DialogField(
                        'Weight (lbs)',
                        '0.0',
                        controller: weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogField(
                        'Declared Value (\$)',
                        '0.00',
                        controller: declaredValue,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogDropdown(
                        'Freight Type',
                        const ['Air', 'Sea'],
                        value: freightType,
                        onChanged: (v) => setDialogState(() => freightType = v ?? 'Air'),
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (customerName.text.trim().isEmpty ||
                                  tracking.text.trim().isEmpty) {
                                setDialogState(
                                  () => error = 'Customer and tracking number are required.',
                                );
                                return;
                              }
                              setDialogState(() {
                                saving = true;
                                error = null;
                              });
                              try {
                                await _db.insertPreAlert({
                                  'customer_name': customerName.text.trim(),
                                  'tracking_number': tracking.text.trim(),
                                  'carrier': carrier.text.trim(),
                                  'description': description.text.trim(),
                                  'weight': double.tryParse(weight.text.trim()) ?? 0,
                                  'declared_value':
                                      double.tryParse(declaredValue.text.trim()) ?? 0,
                                  'freight_type': freightType.toLowerCase(),
                                  'status': 'pending',
                                });
                                if (!context.mounted) return;
                                Navigator.pop(context, true);
                              } catch (e) {
                                setDialogState(() {
                                  saving = false;
                                  error = 'Failed to submit: $e';
                                });
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit Pre-Alert'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (created == true) _load();
  }
}

class _PreAlertStatCard extends StatelessWidget {
  final PreAlertStatus status;
  final int count;
  const _PreAlertStatCard({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  final List<String> cols;
  const _TableHead({required this.cols});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: cols
            .map(
              (c) => Expanded(
                child: Text(
                  c,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DropFilter<T> extends StatelessWidget {
  final String hint;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  const _DropFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          items: items
              .map(
                (i) => DropdownMenuItem<T>(
                  value: i,
                  child: Text(
                    itemLabel(i),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null || null is T) onChanged(v as T);
          },
        ),
      ),
    );
  }
}

class _PreAlertRow extends StatelessWidget {
  final PreAlert preAlert;
  final bool isSelected;
  final VoidCallback onTap;

  const _PreAlertRow({
    required this.preAlert,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.04)
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
              child: Text(
                preAlert.customerName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                preAlert.trackingNumber,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppTheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                preAlert.carrier,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                preAlert.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                '${preAlert.weight} lbs',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '\$${preAlert.declaredValue.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(child: _TypeBadge(type: preAlert.freightType)),
            Expanded(
              child: Text(
                dateFormat.format(preAlert.submittedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: StatusBadge(
                label: preAlert.status.label,
                color: preAlert.status.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isAir = type == 'air';
    return Row(
      children: [
        Icon(
          isAir ? Icons.flight : Icons.directions_boat,
          size: 13,
          color: isAir ? AppTheme.accent : AppTheme.success,
        ),
        const SizedBox(width: 4),
        Text(
          isAir ? 'Air' : 'Sea',
          style: TextStyle(
            fontSize: 12,
            color: isAir ? AppTheme.accent : AppTheme.success,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PreAlertDetail extends StatelessWidget {
  final PreAlert preAlert;
  final VoidCallback onClose;
  final void Function(PreAlert, PreAlertStatus) onStatusChange;

  const _PreAlertDetail({
    required this.preAlert,
    required this.onClose,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Text(
                  'Pre-Alert Details',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: StatusBadge(
                      label: preAlert.status.label,
                      color: preAlert.status.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _KV('Customer', preAlert.customerName),
                  _KV('Tracking #', preAlert.trackingNumber),
                  _KV('Carrier', preAlert.carrier),
                  _KV('Description', preAlert.description),
                  _KV('Weight', '${preAlert.weight} lbs'),
                  _KV(
                    'Value',
                    '\$${preAlert.declaredValue.toStringAsFixed(2)}',
                  ),
                  _KV(
                    'Freight Type',
                    preAlert.freightType == 'air' ? '✈ Air' : '🚢 Sea',
                  ),
                  _KV(
                    'Submitted',
                    DateFormat('MMM d, yyyy').format(preAlert.submittedAt),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Update Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PreAlertStatus.values
                        .map(
                          (s) => GestureDetector(
                            onTap: () => onStatusChange(preAlert, s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: s == preAlert.status
                                    ? s.color.withOpacity(0.15)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: s == preAlert.status
                                      ? s.color
                                      : AppTheme.border,
                                ),
                              ),
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: s == preAlert.status
                                      ? s.color
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.send_outlined, size: 14),
                      label: const Text('Notify Customer'),
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
}

class _KV extends StatelessWidget {
  final String key2;
  final String value;
  const _KV(this.key2, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            key2,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DialogField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  const _DialogField(this.label, this.hint, {this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) => Column(
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

class _DialogDropdown extends StatelessWidget {
  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  const _DialogDropdown(this.label, this.items, {this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
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
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            hint: Text(items.first, style: const TextStyle(fontSize: 13)),
            items: items
                .map(
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(i, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}
