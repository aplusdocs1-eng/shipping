import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/applizone_api.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final _db = DatabaseService();
  final _api = ApplizoneApi();
  late List<WarehouseEntry> _entries;
  String _searchQuery = '';
  WarehouseEntryStatus? _statusFilter;
  String? _zoneFilter;
  bool _loading = true;
  List<Package> _allPackages = [];
  List<StorageLocation> _storageLocations = [];
  List<StorageZone> _zones = [];
  List<ShippingPartner> _partners = [];
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _entries = [];
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getWarehouseEntries(),
        _db.getPackages(),
        _db.getStorageZones(),
        _db.getStorageLocations(),
        _db.getShippingPartners(),
        _db.getCustomers(),
      ]);
      if (!mounted) return;
      final zoneRows = (results[2] as List).cast<Map<String, dynamic>>();
      final locationRows = (results[3] as List).cast<Map<String, dynamic>>();
      final partners = (results[4] as List)
          .cast<Map<String, dynamic>>()
          .map(ShippingPartner.fromMap)
          .toList();
      final locations = locationRows.map((r) {
        final zone = r['storage_zones'] as Map<String, dynamic>?;
        return StorageLocation(
          id: r['id'] as String,
          zoneId: (zone?['code'] as String?) ?? '',
          zoneName: (zone?['name'] as String?) ?? '',
          shelf: r['shelf'] as String? ?? '',
          slot: r['bin'] as String? ?? '',
          branchId: '',
          branchName: '',
        );
      }).toList();
      final totalByZone = <String, int>{};
      for (final r in locationRows) {
        final zoneId = r['zone_id'] as String?;
        if (zoneId != null) {
          totalByZone[zoneId] = (totalByZone[zoneId] ?? 0) + 1;
        }
      }
      final entriesList = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(WarehouseEntry.fromMap)
          .toList();
      // storage_locations.is_occupied is never written by the app (occupancy
      // is derived live from warehouse_entries instead — see
      // _availableLocations below), so compute zone occupancy the same way
      // here rather than reading that always-false column. Zone label is
      // matched against both code and name since older entries stored the
      // raw zone code (e.g. "A") while newer ones store the full zone name
      // (e.g. "Zone A").
      final zoneIdByLabel = <String, String>{};
      for (final z in zoneRows) {
        final id = z['id'] as String?;
        if (id == null) continue;
        final code = z['code'] as String?;
        final name = z['name'] as String?;
        if (code != null) zoneIdByLabel[code] = id;
        if (name != null) zoneIdByLabel[name] = id;
      }
      final occupiedByZone = <String, int>{};
      for (final e in entriesList) {
        if (e.status == WarehouseEntryStatus.pickedUp) continue;
        final zoneLabel = e.storageLocation?.zoneName;
        final zoneId = zoneLabel == null ? null : zoneIdByLabel[zoneLabel];
        if (zoneId != null) {
          occupiedByZone[zoneId] = (occupiedByZone[zoneId] ?? 0) + 1;
        }
      }
      setState(() {
        _entries = entriesList;
        _allPackages = (results[1] as List)
            .cast<Map<String, dynamic>>()
            .map(Package.fromMap)
            .toList();
        _storageLocations = locations;
        _partners = partners;
        _customers = (results[5] as List)
            .cast<Map<String, dynamic>>()
            .map(Customer.fromMap)
            .toList();
        _zones = zoneRows
            .map(
              (z) => StorageZone(
                id: z['id'] as String,
                name: z['name'] as String? ?? (z['code'] as String? ?? ''),
                branchId: '',
                branchName: '',
                totalSlots: totalByZone[z['id']] ?? 0,
                usedSlots: occupiedByZone[z['id']] ?? 0,
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Occupied slots as "zoneName|shelf-slot" keys. Compared against real
  /// StorageLocation identity rather than displayLabel text, since the
  /// synthetic StorageLocation reconstructed by WarehouseEntry.fromMap
  /// (from the warehouse_entries.storage_zone/storage_location text
  /// columns) formats slightly differently than the real one joined from
  /// the storage_locations table.
  List<StorageLocation> get _availableLocations {
    final occupied = _entries
        .where((e) => e.status != WarehouseEntryStatus.pickedUp)
        .map((e) {
          final loc = e.storageLocation;
          if (loc == null) return null;
          return '${loc.zoneName}|${loc.shelf}';
        })
        .whereType<String>()
        .toSet();
    return _storageLocations
        .where((l) => !occupied.contains('${l.zoneName}|${l.shelf}-${l.slot}'))
        .toList();
  }

  List<WarehouseEntry> get _filteredEntries {
    var list = _entries;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (e) =>
                e.trackingNumber.toLowerCase().contains(q) ||
                e.customerName.toLowerCase().contains(q) ||
                e.description.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_statusFilter != null) {
      list = list.where((e) => e.status == _statusFilter).toList();
    }
    if (_zoneFilter != null) {
      list = list
          .where((e) => e.storageLocation?.zoneId == _zoneFilter)
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final counts = {
      for (var s in WarehouseEntryStatus.values)
        s: _entries.where((e) => e.status == s).length,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Warehouse Inventory',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan packages, assign storage locations, and manage pickups',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showScanInDialog(context),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan In Package'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status summary cards
          _StatusSummaryRow(counts: counts),
          const SizedBox(height: 20),

          // Zone overview
          if (!_loading) _ZoneOverview(zones: _zones),
          const SizedBox(height: 20),

          // Filters & search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText:
                              'Search by tracking #, customer, or description…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<WarehouseEntryStatus?>(
                        value: _statusFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        hint: const Text('All Statuses'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Statuses'),
                          ),
                          ...WarehouseEntryStatus.values.map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String?>(
                        value: _zoneFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        hint: const Text('All Zones'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Zones'),
                          ),
                          ..._entries
                              .map((e) => e.storageLocation?.zoneId)
                              .whereType<String>()
                              .toSet()
                              .map(
                                (z) =>
                                    DropdownMenuItem(value: z, child: Text(z)),
                              ),
                        ],
                        onChanged: (v) => setState(() => _zoneFilter = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Inventory table
                _InventoryTable(
                  entries: filtered,
                  onAssignLocation: _assignLocation,
                  onMarkReady: _markReadyForPickup,
                  onMarkPickedUp: _markPickedUp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Scan-In Dialog ──────────────────────────────────────────────────────

  void _showScanInDialog(BuildContext context) {
    final trackingController = TextEditingController();
    StorageLocation? selectedLocation;
    String? errorText;
    String? customerError;
    String? partnerError;
    Customer? selectedCustomer;
    ShippingPartner? selectedPartner = _ovsPartner();
    bool partnerManuallySet = false;
    bool syncing = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Scan In Package'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the tracking number, then select the customer '
                      'and courier this package is tied to.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: trackingController,
                      onChanged: (v) {
                        setDialogState(() {
                          errorText = null;
                          if (!partnerManuallySet) {
                            selectedPartner =
                                _matchPartnerByTracking(v.trim()) ??
                                _ovsPartner();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Tracking Number',
                        hintText: 'e.g. APS-20260411-001',
                        prefixIcon: const Icon(
                          Icons.local_shipping_outlined,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Customer>(
                      value: selectedCustomer,
                      isExpanded: true,
                      hint: const Text('Select customer'),
                      decoration: InputDecoration(
                        labelText: 'Customer',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: customerError,
                      ),
                      items: _customers
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.email.isNotEmpty
                                    ? '${c.name} · ${c.email}'
                                    : c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() {
                        selectedCustomer = v;
                        customerError = null;
                      }),
                    ),
                    if (_customers.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'No customers yet — add one from the Customers tab '
                        'first.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ShippingPartner>(
                      value: selectedPartner,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Courier',
                        prefixIcon: const Icon(
                          Icons.local_shipping_outlined,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: partnerError,
                      ),
                      items: _partners
                          .where((p) => p.isActive)
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.code == 'OVS' ? '${p.name} (Direct)' : p.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() {
                        selectedPartner = v;
                        partnerManuallySet = true;
                        partnerError = null;
                      }),
                    ),
                    if (selectedPartner != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            selectedPartner!.code == 'OVS'
                                ? Icons.home_work_outlined
                                : Icons.local_shipping,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedPartner!.code == 'OVS'
                                  ? 'In-house package — not tied to an '
                                        'external courier.'
                                  : '${selectedPartner!.region} · Code: '
                                        '${selectedPartner!.code}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (selectedPartner!.code != 'OVS')
                            if (_api.isConnected)
                              Icon(
                                Icons.sync,
                                size: 16,
                                color: AppTheme.success,
                              )
                            else
                              Tooltip(
                                message: 'Connect Applizone to auto-sync',
                                child: Icon(
                                  Icons.sync_disabled,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<StorageLocation>(
                      value: selectedLocation,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Storage Location',
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _availableLocations
                          .map(
                            (loc) => DropdownMenuItem(
                              value: loc,
                              child: Text(loc.displayLabel),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedLocation = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can also assign a location later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
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
                FilledButton(
                  onPressed: syncing
                      ? null
                      : () async {
                          final tracking = trackingController.text.trim();
                          final missingTracking = tracking.isEmpty;
                          final missingCustomer = selectedCustomer == null;
                          final missingPartner = selectedPartner == null;
                          if (missingTracking ||
                              missingCustomer ||
                              missingPartner) {
                            setDialogState(() {
                              errorText = missingTracking
                                  ? 'Enter a tracking number'
                                  : null;
                              customerError = missingCustomer
                                  ? 'Select a customer'
                                  : null;
                              partnerError = missingPartner
                                  ? 'Select a courier or One Village '
                                        'Shipping & Freight'
                                  : null;
                            });
                            return;
                          }

                          // Check if already scanned in
                          final existing = _entries.any(
                            (e) => e.trackingNumber == tracking,
                          );
                          if (existing) {
                            setDialogState(
                              () => errorText = 'Package already scanned in',
                            );
                            return;
                          }

                          // Look up the package from DB data for
                          // description/weight only — customer and courier
                          // always come from the explicit selections above,
                          // never inferred or defaulted to a placeholder.
                          final pkg = _allPackages.where(
                            (p) => p.trackingNumber == tracking,
                          );
                          final packageMatch = pkg.isNotEmpty
                              ? pkg.first
                              : null;
                          final customer = selectedCustomer!;
                          final partner = selectedPartner!;
                          final isThirdPartyCourier = partner.code != 'OVS';

                          setDialogState(() => syncing = true);

                          // Sync to Applizone only for a genuine external
                          // courier — an in-house OVS package has nothing
                          // external to sync to.
                          bool synced = false;
                          if (_api.isConnected && isThirdPartyCourier) {
                            final result = await _api.syncPackage(
                              trackingNumber: tracking,
                              description:
                                  packageMatch?.description ??
                                  'Scanned package',
                              weight: packageMatch?.weight ?? 0.0,
                              customerName: customer.name,
                              storageLocation: selectedLocation?.displayLabel,
                              shippingCompanyCode: partner.code,
                            );
                            synced = result.success;
                          }

                          try {
                            final row = await _db.insertWarehouseEntry(
                              trackingNumber: tracking,
                              customerName: customer.name,
                              customerId: customer.id,
                              description:
                                  packageMatch?.description ??
                                  'Scanned package',
                              weight: packageMatch?.weight ?? 0.0,
                              storageZone: selectedLocation?.zoneName,
                              storageLocation: selectedLocation == null
                                  ? null
                                  : '${selectedLocation!.shelf}-${selectedLocation!.slot}',
                              status: selectedLocation != null
                                  ? 'stored'
                                  : 'scanned_in',
                              scannedInBy: 'Admin Staff',
                              shippingPartnerCode: partner.code,
                              syncedToPartner: synced,
                            );
                            if (!mounted) return;
                            setState(() {
                              _entries.add(WarehouseEntry.fromMap(row));
                            });
                          } catch (e) {
                            setDialogState(
                              () => errorText = 'Failed to save: $e',
                            );
                            setDialogState(() => syncing = false);
                            return;
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          unawaited(_load());

                          final partnerMsg = ' · ${partner.name}';
                          final syncMsg = synced ? ' · Synced ✓' : '';

                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                selectedLocation != null
                                    ? 'Package $tracking scanned in → ${selectedLocation!.displayLabel}$partnerMsg$syncMsg'
                                    : 'Package $tracking scanned in$partnerMsg$syncMsg',
                              ),
                              backgroundColor: AppTheme.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Scan In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  void _assignLocation(WarehouseEntry entry) {
    StorageLocation? selectedLocation = entry.storageLocation;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Storage Location'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Package: ${entry.trackingNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${entry.description} · ${entry.weight} lbs',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<StorageLocation>(
                      value: selectedLocation,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Storage Location',
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: {
                        if (entry.storageLocation != null)
                          entry.storageLocation!,
                        ..._availableLocations,
                      }
                          .toList()
                          .map(
                            (loc) => DropdownMenuItem(
                              value: loc,
                              child: Text(loc.displayLabel),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedLocation = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedLocation == null) return;
                    try {
                      await _db.updateWarehouseEntry(entry.id, {
                        'storage_zone': selectedLocation!.zoneName,
                        'storage_location':
                            '${selectedLocation!.shelf}-${selectedLocation!.slot}',
                        'status': 'stored',
                      });
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to assign location: $e')),
                      );
                      return;
                    }
                    final idx = _entries.indexOf(entry);
                    if (idx != -1 && mounted) {
                      setState(() {
                        _entries[idx] = entry.copyWith(
                          storageLocation: selectedLocation,
                          status: WarehouseEntryStatus.stored,
                        );
                      });
                    }
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    unawaited(_load());
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Location assigned: ${selectedLocation!.displayLabel}',
                        ),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markReadyForPickup(WarehouseEntry entry) async {
    final idx = _entries.indexOf(entry);
    if (idx == -1) return;
    try {
      await _db.updateWarehouseEntry(entry.id, {'status': 'ready_for_pickup'});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _entries[idx] = entry.copyWith(
        status: WarehouseEntryStatus.readyForPickup,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.trackingNumber} marked ready for pickup'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _markPickedUp(WarehouseEntry entry) async {
    final idx = _entries.indexOf(entry);
    if (idx == -1) return;
    final now = DateTime.now();
    try {
      await _db.updateWarehouseEntry(entry.id, {
        'status': 'picked_up',
        'picked_up_at': now.toIso8601String(),
        'picked_up_by': entry.customerName,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _entries[idx] = entry.copyWith(
        status: WarehouseEntryStatus.pickedUp,
        pickedUpAt: now,
        pickedUpBy: entry.customerName,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.trackingNumber} picked up'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ShippingPartner? _matchPartnerByTracking(String tracking) {
    if (tracking.isEmpty) return null;
    final upper = tracking.toUpperCase();
    for (final p in _partners) {
      if (p.trackingPrefix.isNotEmpty && upper.startsWith(p.trackingPrefix.toUpperCase())) {
        return p;
      }
    }
    return null;
  }

  /// The seeded "One Village Shipping & Freight" partner row — the default
  /// courier selection for a package that isn't tied to an external courier.
  ShippingPartner? _ovsPartner() {
    for (final p in _partners) {
      if (p.code == 'OVS') return p;
    }
    return null;
  }
}

// ─── Status Summary Row ──────────────────────────────────────────────────────

class _StatusSummaryRow extends StatelessWidget {
  final Map<WarehouseEntryStatus, int> counts;
  const _StatusSummaryRow({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: WarehouseEntryStatus.values.map((status) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(status.icon, color: status.color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${counts[status] ?? 0}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      status.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Zone Overview ───────────────────────────────────────────────────────────

class _ZoneOverview extends StatelessWidget {
  final List<StorageZone> zones;
  const _ZoneOverview({required this.zones});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Storage Zones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: zones.map((zone) {
              final pct = zone.usedSlots / zone.totalSlots;
              final barColor = pct >= 0.9
                  ? const Color(0xFFEF4444)
                  : pct >= 0.6
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981);

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            zone.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            zone.branchName,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: AppTheme.border,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${zone.usedSlots} / ${zone.totalSlots} slots used  ·  ${zone.availableSlots} available',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Inventory Table ─────────────────────────────────────────────────────────

class _InventoryTable extends StatelessWidget {
  final List<WarehouseEntry> entries;
  final ValueChanged<WarehouseEntry> onAssignLocation;
  final ValueChanged<WarehouseEntry> onMarkReady;
  final ValueChanged<WarehouseEntry> onMarkPickedUp;

  const _InventoryTable({
    required this.entries,
    required this.onAssignLocation,
    required this.onMarkReady,
    required this.onMarkPickedUp,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No warehouse entries found.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final dateFmt = DateFormat('MMM d, yyyy h:mm a');

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1.2),
        6: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          children: const [
            _HeaderCell('Tracking #'),
            _HeaderCell('Customer'),
            _HeaderCell('Location'),
            _HeaderCell('Partner'),
            _HeaderCell('Scanned In'),
            _HeaderCell('Status'),
            _HeaderCell('Actions'),
          ],
        ),
        ...entries.map((entry) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.border, width: 0.5),
              ),
            ),
            children: [
              _BodyCell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.trackingNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      entry.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${entry.weight} lbs',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _BodyCell(
                child: Text(
                  entry.customerName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              _BodyCell(
                child: entry.storageLocation != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.storageLocation!.displayLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      )
                    : Text(
                        'Not assigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
              ),
              // ── Partner column ──
              _BodyCell(
                child: entry.shippingPartnerCode != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.shippingPartnerCode!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accent,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            entry.syncedToPartner
                                ? Icons.cloud_done
                                : Icons.cloud_off,
                            size: 14,
                            color: entry.syncedToPartner
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                          ),
                        ],
                      )
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
              ),
              _BodyCell(
                child: Text(
                  dateFmt.format(entry.scannedInAt),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              _BodyCell(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: entry.status.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entry.status.color,
                    ),
                  ),
                ),
              ),
              _BodyCell(
                child: _ActionsMenu(
                  entry: entry,
                  onAssignLocation: onAssignLocation,
                  onMarkReady: onMarkReady,
                  onMarkPickedUp: onMarkPickedUp,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final Widget child;
  const _BodyCell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: child,
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final WarehouseEntry entry;
  final ValueChanged<WarehouseEntry> onAssignLocation;
  final ValueChanged<WarehouseEntry> onMarkReady;
  final ValueChanged<WarehouseEntry> onMarkPickedUp;

  const _ActionsMenu({
    required this.entry,
    required this.onAssignLocation,
    required this.onMarkReady,
    required this.onMarkPickedUp,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        // Always allow reassigning location
        items.add(
          const PopupMenuItem(
            value: 'assign',
            child: ListTile(
              leading: Icon(Icons.location_on_outlined, size: 18),
              title: Text(
                'Assign / Change Location',
                style: TextStyle(fontSize: 13),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );

        // Mark ready if stored
        if (entry.status == WarehouseEntryStatus.stored) {
          items.add(
            const PopupMenuItem(
              value: 'ready',
              child: ListTile(
                leading: Icon(Icons.local_shipping_outlined, size: 18),
                title: Text(
                  'Mark Ready for Pickup',
                  style: TextStyle(fontSize: 13),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
        }

        // Mark picked up if ready
        if (entry.status == WarehouseEntryStatus.readyForPickup) {
          items.add(
            const PopupMenuItem(
              value: 'pickup',
              child: ListTile(
                leading: Icon(Icons.check_circle_outline, size: 18),
                title: Text('Mark Picked Up', style: TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
        }

        return items;
      },
      onSelected: (value) {
        switch (value) {
          case 'assign':
            onAssignLocation(entry);
          case 'ready':
            onMarkReady(entry);
          case 'pickup':
            onMarkPickedUp(entry);
        }
      },
    );
  }
}
