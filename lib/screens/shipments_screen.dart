import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _db = DatabaseService();
  ShipmentType? _filterType;
  ShipmentStatus? _filterStatus;
  Shipment? _selected;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  List<Shipment> _allShipments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _db.getShipments();
      if (mounted)
        setState(() {
          _allShipments = rows.map(Shipment.fromMap).toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Shipment> get _filtered {
    return _allShipments.where((s) {
      final matchQ =
          _query.isEmpty ||
          s.shipmentNumber.toLowerCase().contains(_query.toLowerCase()) ||
          s.origin.toLowerCase().contains(_query.toLowerCase()) ||
          s.destination.toLowerCase().contains(_query.toLowerCase()) ||
          ((s.flightNumber ?? s.vesselName)?.toLowerCase().contains(
                _query.toLowerCase(),
              ) ??
              false);
      final matchType = _filterType == null || s.type == _filterType;
      final matchStatus = _filterStatus == null || s.status == _filterStatus;
      return matchQ && matchType && matchStatus;
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
                          'Shipments',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Air & Sea freight shipments',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showNewShipmentDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Shipment'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ShipmentSummaryRow(shipments: _allShipments),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search shipments...',
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
                    _DropFilter<ShipmentType?>(
                      hint: 'All Types',
                      value: _filterType,
                      items: [null, ...ShipmentType.values],
                      itemLabel: (v) => v == null
                          ? 'All Types'
                          : v == ShipmentType.air
                          ? '✈ Air'
                          : '🚢 Sea',
                      onChanged: (v) => setState(() => _filterType = v),
                    ),
                    const SizedBox(width: 8),
                    _DropFilter<ShipmentStatus?>(
                      hint: 'All Statuses',
                      value: _filterStatus,
                      items: [null, ...ShipmentStatus.values],
                      itemLabel: (v) => v == null ? 'All Statuses' : v.label,
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.local_shipping_outlined,
                          title: 'No shipments found',
                          subtitle: 'No shipments match your filters',
                        )
                      : ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, i) {
                            final s = _filtered[i];
                            return _ShipmentCard(
                              shipment: s,
                              isSelected: _selected?.id == s.id,
                              onTap: () => setState(
                                () => _selected = _selected?.id == s.id
                                    ? null
                                    : s,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_selected != null)
          _ShipmentDetail(
            shipment: _selected!,
            onClose: () => setState(() => _selected = null),
          ),
      ],
    );
  }

  void _showNewShipmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
                    'New Shipment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _DField('Shipment #', 'e.g. AIR-2025-001')),
                  const SizedBox(width: 12),
                  Expanded(child: _DDrop('Type', ['Air', 'Sea'])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _DField('Origin', 'Departure city')),
                  const SizedBox(width: 12),
                  Expanded(child: _DField('Destination', 'Arrival city')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DField(
                      'Vessel / Flight',
                      'Flight # or vessel name',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _DField('Master BL/AWB', 'Bill of lading #')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _DField('Departure Date', 'YYYY-MM-DD')),
                  const SizedBox(width: 12),
                  Expanded(child: _DField('Arrival Date', 'YYYY-MM-DD')),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Create Shipment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShipmentSummaryRow extends StatelessWidget {
  final List<Shipment> shipments;
  const _ShipmentSummaryRow({required this.shipments});

  @override
  Widget build(BuildContext context) {
    final airCount = shipments.where((s) => s.type == ShipmentType.air).length;
    final seaCount = shipments.where((s) => s.type == ShipmentType.sea).length;
    final inTransit = shipments
        .where((s) => s.status == ShipmentStatus.inTransit)
        .length;
    final totalPkgs = shipments.fold(0, (sum, s) => sum + s.packageCount);
    return Row(
      children: [
        _ShipStat(
          'Air Shipments',
          airCount.toString(),
          Icons.flight,
          AppTheme.accent,
        ),
        const SizedBox(width: 12),
        _ShipStat(
          'Sea Shipments',
          seaCount.toString(),
          Icons.directions_boat,
          AppTheme.success,
        ),
        const SizedBox(width: 12),
        _ShipStat(
          'In Transit',
          inTransit.toString(),
          Icons.local_shipping,
          AppTheme.warning,
        ),
        const SizedBox(width: 12),
        _ShipStat(
          'Total Packages',
          totalPkgs.toString(),
          Icons.inventory_2_outlined,
          AppTheme.primary,
        ),
      ],
    );
  }
}

class _ShipStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ShipStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ShipmentCard extends StatelessWidget {
  final Shipment shipment;
  final bool isSelected;
  final VoidCallback onTap;
  const _ShipmentCard({
    required this.shipment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isAir = shipment.type == ShipmentType.air;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        color: isSelected ? AppTheme.primary.withOpacity(0.03) : Colors.white,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isAir ? AppTheme.accent : AppTheme.success).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAir ? Icons.flight : Icons.directions_boat,
                color: isAir ? AppTheme.accent : AppTheme.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shipment.shipmentNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (shipment.type == ShipmentType.air
                            ? shipment.flightNumber
                            : shipment.vesselName) ??
                        'No vessel/flight',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shipment.origin,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_downward,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                  Text(
                    shipment.destination,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Departs: ${dateFormat.format(shipment.departureDate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (shipment.arrivalDate != null)
                    Text(
                      'Arrives: ${dateFormat.format(shipment.arrivalDate!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  shipment.packageCount.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Text(
                  'packages',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Text(
              '${shipment.totalWeight.toStringAsFixed(0)} lbs',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 20),
            StatusBadge(
              label: shipment.status.label,
              color: shipment.status.color,
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.description_outlined, size: 14),
              label: const Text('Manifest', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipmentDetail extends StatelessWidget {
  final Shipment shipment;
  final VoidCallback onClose;
  const _ShipmentDetail({required this.shipment, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    final isAir = shipment.type == ShipmentType.air;
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
                  'Shipment Details',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isAir ? AppTheme.accent : AppTheme.success)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isAir ? Icons.flight : Icons.directions_boat,
                          color: isAir ? AppTheme.accent : AppTheme.success,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      isAir ? 'Air Freight' : 'Sea Freight',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isAir ? AppTheme.accent : AppTheme.success,
                      ),
                    ),
                  ),
                  Center(
                    child: StatusBadge(
                      label: shipment.status.label,
                      color: shipment.status.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DKV('Shipment #', shipment.shipmentNumber),
                  _DKV('Origin', shipment.origin),
                  _DKV('Destination', shipment.destination),
                  if (isAir && shipment.flightNumber != null)
                    _DKV('Flight #', shipment.flightNumber!),
                  if (!isAir && shipment.vesselName != null)
                    _DKV('Vessel', shipment.vesselName!),
                  _DKV('Departure', df.format(shipment.departureDate)),
                  if (shipment.arrivalDate != null)
                    _DKV('Arrival', df.format(shipment.arrivalDate!)),
                  _DKV('Packages', shipment.packageCount.toString()),
                  _DKV(
                    'Total Weight',
                    '${shipment.totalWeight.toStringAsFixed(1)} lbs',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.description_outlined, size: 14),
                      label: const Text('View Manifest'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                      label: const Text('Export PDF'),
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

class _DKV extends StatelessWidget {
  final String k;
  final String v;
  const _DKV(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            v,
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
  Widget build(BuildContext context) => Container(
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
                child: Text(itemLabel(i), style: const TextStyle(fontSize: 13)),
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

class _DField extends StatelessWidget {
  final String label;
  final String hint;
  const _DField(this.label, this.hint);
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

class _DDrop extends StatelessWidget {
  final String label;
  final List<String> items;
  const _DDrop(this.label, this.items);
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
            hint: Text(items.first, style: const TextStyle(fontSize: 13)),
            items: items
                .map(
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(i, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (_) {},
          ),
        ),
      ),
    ],
  );
}
