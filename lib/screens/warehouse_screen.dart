import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final _db = DatabaseService();
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
  List<Map<String, dynamic>> _partnerAccounts = [];
  // Real company name from Settings -> Company Profile, printed as the
  // sender on every label — falls back to the platform default until
  // settings load (or if the admin has never customized it).
  String _companyName = 'One Village Shipping & Freight';

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
        _db.getAllPartnerAccounts(),
        _db.getCompanySettings(),
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
        _partnerAccounts = (results[6] as List)
            .cast<Map<String, dynamic>>()
            .where((p) => p['status'] == 'approved')
            .toList();
        final settings = results[7] as Map<String, dynamic>?;
        final loadedCompanyName = settings?['companyName'] as String?;
        if (loadedCompanyName != null && loadedCompanyName.trim().isNotEmpty) {
          _companyName = loadedCompanyName.trim();
        }
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

  /// Occupied slots as "zoneName|rawLocationText" keys. The two sides of
  /// this comparison start from different shapes of the same physical
  /// location, so they're deliberately built with different formulas:
  ///
  /// - A real StorageLocation (from _storageLocations, i.e. the
  ///   storage_locations table) keeps shelf and slot/bin as separate
  ///   columns, e.g. shelf="1", slot="1".
  /// - An entry's StorageLocation is synthesized by WarehouseEntry.fromMap
  ///   from the single warehouse_entries.storage_location TEXT column, so
  ///   its .shelf holds that *whole* raw string (e.g. "1-1") and .slot is
  ///   always ''.
  ///
  /// _assignLocation writes that column as '${shelf}-${slot}', so
  /// reconstructing the same join on the real side, and using the raw
  /// text as-is (no slot suffix) on the entry side, gives both a matching
  /// key for the same physical location. Appending "-${slot}" on the
  /// entry side too (slot is always '') would tack on a phantom trailing
  /// "-" that was never written, so the two sides would never match —
  /// which is exactly what silently made every location look available
  /// before this fix.
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

  /// Finds the real StorageLocation (separate shelf/slot, from
  /// _storageLocations) that a synthetic one — reconstructed by
  /// WarehouseEntry.fromMap from the raw warehouse_entries.storage_location
  /// text — actually refers to. _assignLocation uses this so re-opening it
  /// for an already-stored entry and saving without touching the dropdown
  /// re-writes the same clean 'shelf-slot' text instead of joining the
  /// already-combined synthetic text a second time (how a couple of
  /// entries ended up with a stray trailing "-" in storage_location).
  StorageLocation? _resolveRealLocation(StorageLocation? synthetic) {
    if (synthetic == null) return null;
    for (final l in _storageLocations) {
      if (l.zoneName == synthetic.zoneName &&
          '${l.shelf}-${l.slot}' == synthetic.shelf) {
        return l;
      }
    }
    return null;
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
              OutlinedButton.icon(
                onPressed: () => _showScanOutDialog(context),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Confirm Pickup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                  onBillCourier: _billCourier,
                  onPrintLabel: _printLabel,
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
    final billAmountController = TextEditingController();
    final billNoteController = TextEditingController();
    StorageLocation? selectedLocation;
    String? errorText;
    String? customerError;
    String? partnerError;
    String? billError;
    String? scanFeedback;
    bool scanFeedbackIsMatch = false;
    Customer? selectedCustomer;
    ShippingPartner? selectedPartner = _ovsPartner();
    Map<String, dynamic>? selectedCourierTenant = _defaultCourierTenant();
    bool partnerManuallySet = false;
    bool courierManuallySet = false;
    bool syncing = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCustomers = selectedCourierTenant == null
                ? const <Customer>[]
                : _customers
                      .where(
                        (c) => c.partnerId == selectedCourierTenant!['id'],
                      )
                      .toList();

            // Fired by the scanner's Enter keystroke, the manual lookup
            // button, or pressing Enter after typing by hand — finds any
            // existing package for this tracking number and fills in
            // everything it can: customer (and therefore courier, since a
            // customer belongs to exactly one), carrier, description, and
            // weight, so a scan alone can carry the whole form.
            void applyScanLookup(String tracking) {
              if (tracking.isEmpty) return;
              final matches = _allPackages.where(
                (p) => p.trackingNumber == tracking,
              );
              if (matches.isEmpty) {
                setDialogState(() {
                  scanFeedback =
                      'No existing package record for this tracking number '
                      '— enter the rest below manually.';
                  scanFeedbackIsMatch = false;
                });
                return;
              }
              final pkg = matches.first;
              setDialogState(() {
                errorText = null;
                if (!partnerManuallySet) {
                  selectedPartner =
                      _matchPartnerByTracking(tracking) ?? _ovsPartner();
                }
                final custMatches = _customers.where(
                  (c) => c.id == pkg.customerId,
                );
                if (custMatches.isNotEmpty) {
                  final cust = custMatches.first;
                  final tenantMatches = _partnerAccounts.where(
                    (p) => p['id'] == cust.partnerId,
                  );
                  if (tenantMatches.isNotEmpty) {
                    selectedCourierTenant = tenantMatches.first;
                    // An exact package match beats a tracking-prefix
                    // guess — settle it so later edits to the field don't
                    // silently override what was just looked up.
                    courierManuallySet = true;
                    // Only select the customer once its courier is
                    // actually the one now selected — the Customer
                    // dropdown's items are filtered to selectedCourierTenant,
                    // so setting a customer whose courier isn't in
                    // _partnerAccounts (e.g. not currently approved) would
                    // leave `value` pointing at something not in `items`,
                    // which Flutter's dropdown treats as a crash, not a
                    // graceful no-op.
                    selectedCustomer = cust;
                    customerError = null;
                    scanFeedback =
                        'Matched an existing package — customer, courier, '
                        'description, and weight filled in below.';
                  } else {
                    selectedCustomer = null;
                    scanFeedback =
                        "Matched an existing package, but its courier "
                        "isn't currently available to select — pick the "
                        'courier and customer manually.';
                  }
                } else {
                  selectedCustomer = null;
                  scanFeedback =
                      'Matched an existing package, but its customer '
                      "record couldn't be found — select one manually.";
                }
                scanFeedbackIsMatch = true;
              });
            }

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
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Connect a barcode scanner and scan the package — or "
                      'type the tracking number manually — then confirm the '
                      'details below.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: trackingController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (v) {
                        setDialogState(() {
                          errorText = null;
                          scanFeedback = null;
                          if (!partnerManuallySet) {
                            selectedPartner =
                                _matchPartnerByTracking(v.trim()) ??
                                _ovsPartner();
                          }
                          if (!courierManuallySet) {
                            final matched =
                                _matchPartnerAccountByTracking(v.trim()) ??
                                _defaultCourierTenant();
                            if (matched?['id'] != selectedCourierTenant?['id']) {
                              selectedCourierTenant = matched;
                              // A courier change can invalidate whichever
                              // customer was picked under the old courier.
                              selectedCustomer = null;
                            }
                          }
                        });
                      },
                      // A handheld/USB scanner types the barcode then sends
                      // Enter — same signal as a person finishing manual
                      // entry, so both trigger the same lookup here.
                      onSubmitted: (v) => applyScanLookup(v.trim()),
                      decoration: InputDecoration(
                        labelText: 'Tracking Number',
                        hintText: 'Scan barcode or type e.g. APS-20260411-001',
                        prefixIcon: const Icon(
                          Icons.qr_code_scanner,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.manage_search, size: 20),
                          tooltip: 'Look up this tracking number',
                          onPressed: () =>
                              applyScanLookup(trackingController.text.trim()),
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: errorText,
                      ),
                    ),
                    if (scanFeedback != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            scanFeedbackIsMatch
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 14,
                            color: scanFeedbackIsMatch
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              scanFeedback!,
                              style: TextStyle(
                                fontSize: 12,
                                color: scanFeedbackIsMatch
                                    ? AppTheme.success
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedCourierTenant,
                      isExpanded: true,
                      hint: const Text('Select courier'),
                      decoration: InputDecoration(
                        labelText: 'Courier',
                        prefixIcon: const Icon(
                          Icons.storefront_outlined,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _partnerAccounts
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                (p['company_name'] as String?) ?? 'Unnamed',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() {
                        selectedCourierTenant = v;
                        courierManuallySet = true;
                        if (selectedCustomer != null &&
                            selectedCustomer!.partnerId != v?['id']) {
                          selectedCustomer = null;
                        }
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choosing a courier narrows the customer list below '
                      'to that courier\'s own customers.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Customer>(
                      value: selectedCustomer,
                      isExpanded: true,
                      hint: Text(
                        selectedCourierTenant == null
                            ? 'Select a courier first'
                            : 'Select customer',
                      ),
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
                      items: filteredCustomers
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
                      onChanged: selectedCourierTenant == null
                          ? null
                          : (v) => setDialogState(() {
                              selectedCustomer = v;
                              customerError = null;
                            }),
                    ),
                    if (selectedCourierTenant != null &&
                        filteredCustomers.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'No customers for this courier yet — add one from '
                        'the Customers tab first.',
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
                        labelText: 'Carrier',
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
                                        'external carrier.'
                                  : '${selectedPartner!.region} · Code: '
                                        '${selectedPartner!.code}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
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
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Bill Courier (optional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedCourierTenant == null
                          ? 'Leave blank to bill this package later from '
                                'its row menu instead.'
                          : 'Charges ${selectedCourierTenant!['company_name']} '
                                'for this package immediately — leave blank '
                                'to bill it later from its row menu instead.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: billAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        if (billError != null) {
                          setDialogState(() => billError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Amount (USD)',
                        prefixText: '\$ ',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: billError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: billNoteController,
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'e.g. Storage + handling',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  ),
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
                                  ? 'Select a carrier or One Village '
                                        'Shipping & Freight'
                                  : null;
                            });
                            return;
                          }

                          // The bill amount is optional — only validate it
                          // (and block submission) if something was
                          // actually typed into it.
                          final billAmountText = billAmountController.text
                              .trim();
                          double? billAmount;
                          if (billAmountText.isNotEmpty) {
                            billAmount = double.tryParse(billAmountText);
                            if (billAmount == null || billAmount <= 0) {
                              setDialogState(
                                () => billError =
                                    'Enter a valid amount or leave blank',
                              );
                              return;
                            }
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

                          bool billApplied = false;
                          String? billFailure;
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
                            );
                            if (!mounted) return;
                            setState(() {
                              _entries.add(WarehouseEntry.fromMap(row));
                            });

                            // Bill the courier tenant in the same action,
                            // right on the row that was just created —
                            // this never blocks the scan-in itself from
                            // succeeding; a billing failure here just
                            // means it still needs billing later from the
                            // row's own menu.
                            if (billAmount != null) {
                              try {
                                await _db.updateWarehouseEntry(
                                  row['id'] as String,
                                  {
                                    'partner_charge_amount': billAmount,
                                    'partner_charge_status': 'billed',
                                    'partner_charge_note':
                                        billNoteController.text
                                            .trim()
                                            .isEmpty
                                        ? null
                                        : billNoteController.text.trim(),
                                    'partner_charged_at': DateTime.now()
                                        .toIso8601String(),
                                  },
                                );
                                billApplied = true;
                              } catch (e) {
                                billFailure = e.toString();
                              }
                            }
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

                          // A package isn't actually stored until its label
                          // is printed and physically attached to it — so
                          // scanning in opens the print dialog immediately
                          // rather than waiting for a separate click.
                          unawaited(
                            ExportService.printLabels(
                              [
                                {
                                  'trackingNumber': tracking,
                                  'to': customer.name,
                                  'toDetail': selectedLocation?.displayLabel ?? '',
                                  'fromDetail': isThirdPartyCourier
                                      ? 'Received via ${partner.name}'
                                      : 'Direct / in-house',
                                  'description':
                                      packageMatch?.description ?? 'Scanned package',
                                  'weight': (packageMatch?.weight ?? 0.0).toString(),
                                  'zone': selectedLocation != null
                                      ? '${selectedLocation!.shelf}-${selectedLocation!.slot}'
                                      : '',
                                },
                              ],
                              companyName: _companyName,
                            ),
                          );

                          final partnerMsg = ' · ${partner.name}';
                          final billMsg = billApplied
                              ? ' · Billed \$${billAmount!.toStringAsFixed(2)}'
                              : billFailure != null
                              ? ' · Billing failed — bill it from the row '
                                    'menu instead'
                              : '';

                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                selectedLocation != null
                                    ? 'Package $tracking scanned in → ${selectedLocation!.displayLabel}$partnerMsg$billMsg · printing label…'
                                    : 'Package $tracking scanned in$partnerMsg$billMsg · printing label…',
                              ),
                              backgroundColor: billFailure != null
                                  ? AppTheme.warning
                                  : AppTheme.primary,
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

  /// Reprints a label for an already-scanned-in entry — for a jammed
  /// printer, a torn label, or a duplicate for a second box. The scan-in
  /// dialog itself triggers the same ExportService.printLabels call
  /// automatically the moment a package is saved.
  void _printLabel(WarehouseEntry entry) {
    final carrier = _matchPartnerByTracking(entry.trackingNumber);
    final isThirdParty =
        entry.shippingPartnerCode != null && entry.shippingPartnerCode != 'OVS';
    final loc = entry.storageLocation;
    unawaited(
      ExportService.printLabels(
        [
          {
            'trackingNumber': entry.trackingNumber,
            'to': entry.customerName,
            'toDetail': loc?.displayLabel ?? '',
            'fromDetail': isThirdParty
                ? 'Received via ${carrier?.name ?? entry.shippingPartnerCode}'
                : 'Direct / in-house',
            'description': entry.description,
            'weight': entry.weight.toString(),
            'zone': loc != null ? '${loc.shelf}-${loc.slot}' : '',
          },
        ],
        companyName: _companyName,
      ),
    );
  }

  void _billCourier(WarehouseEntry entry) {
    final courier = _matchPartnerAccountByTracking(entry.trackingNumber);
    final amountCtl = TextEditingController(
      text: entry.partnerChargeAmount?.toStringAsFixed(2) ?? '',
    );
    final noteCtl = TextEditingController(text: entry.partnerChargeNote ?? '');
    String? error;
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Bill Courier'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Package: ${entry.trackingNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${entry.description} · ${entry.customerName}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (courier == null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'This tracking number doesn\'t match any courier '
                          'tenant\'s prefix — nobody to bill.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: 16,
                              color: AppTheme.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Courier: ${courier['company_name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount (USD)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: error,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtl,
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'e.g. Storage + handling',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (entry.partnerChargeStatus == 'paid') ...[
                      const SizedBox(height: 10),
                      Text(
                        'Already marked paid'
                        '${entry.partnerPaidAt != null ? ' on ${DateFormat('MMM d, y').format(entry.partnerPaidAt!)}' : ''}. '
                        'Saving a new amount will not undo that.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: courier == null || saving
                      ? null
                      : () async {
                          final amount = double.tryParse(
                            amountCtl.text.trim(),
                          );
                          if (amount == null || amount <= 0) {
                            setDialogState(
                              () => error = 'Enter a valid amount',
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            await _db.updateWarehouseEntry(entry.id, {
                              'partner_charge_amount': amount,
                              'partner_charge_status': 'billed',
                              'partner_charge_note': noteCtl.text.trim().isEmpty
                                  ? null
                                  : noteCtl.text.trim(),
                              'partner_charged_at': DateTime.now()
                                  .toIso8601String(),
                            });
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            unawaited(_load());
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Billed ${courier['company_name']} '
                                  '\$${amount.toStringAsFixed(2)} for '
                                  '${entry.trackingNumber}',
                                ),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              error = 'Failed to save: $e';
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          entry.partnerChargeStatus == 'unbilled'
                              ? 'Bill Courier'
                              : 'Update Charge',
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// A fast, scan-driven pickup queue: every matched tracking number is
  /// confirmed picked up immediately (no separate confirm click), so a
  /// courier rep can clear a stack of packages scan-scan-scan. A "Picked up
  /// by" name applies to the whole session instead of being re-typed per
  /// item, and each confirmation gets an inline Undo for mis-scans.
  void _showScanOutDialog(BuildContext context) {
    final trackingController = TextEditingController();
    final pickedUpByController = TextEditingController();
    // Explicitly managed (not just autofocus:true) so focus can be put
    // straight back after every scan — success or failure — without the
    // operator needing to click the field again before the next scan.
    final trackingFocusNode = FocusNode();
    String? scanFeedback;
    bool scanFeedbackIsError = false;
    bool busy = false;
    final List<_PickupLogEntry> confirmed = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // requestFocus() called synchronously right after a
            // setState-triggered rebuild can race that rebuild — the new
            // frame (and the fresh platform text-input connection that
            // comes with it) isn't necessarily ready yet, so the next
            // keystroke (the next scan) can silently go nowhere even
            // though the field looks focused. Deferring to a post-frame
            // callback runs it once the rebuild has actually landed.
            void refocusTracking() {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                trackingFocusNode.requestFocus();
              });
            }

            // Fired by the scanner's Enter keystroke, the arrow button, or
            // pressing Enter after typing by hand.
            Future<void> confirmPickup(String raw) async {
              final tracking = raw.trim();
              if (tracking.isEmpty || busy) return;
              WarehouseEntry? found;
              for (final e in _entries) {
                if (e.trackingNumber.toUpperCase() ==
                    tracking.toUpperCase()) {
                  found = e;
                  break;
                }
              }
              if (found == null) {
                setDialogState(() {
                  scanFeedback = 'No package found for "$tracking".';
                  scanFeedbackIsError = true;
                });
                trackingController.clear();
                refocusTracking();
                return;
              }
              final previous = found;
              if (previous.status == WarehouseEntryStatus.pickedUp) {
                final when = previous.pickedUpAt;
                setDialogState(() {
                  scanFeedback =
                      '${previous.trackingNumber} was already picked up'
                      '${when != null ? ' at ${DateFormat('h:mm a').format(when)}' : ''}'
                      '${previous.pickedUpBy != null ? ' by ${previous.pickedUpBy}' : ''}.';
                  scanFeedbackIsError = true;
                });
                trackingController.clear();
                refocusTracking();
                return;
              }

              final idx = _entries.indexOf(previous);
              final now = DateTime.now();
              // If this package belongs to a courier tenant (by tracking
              // prefix), default "picked up by" to that courier's name
              // rather than the customer — it's the courier's rep signing
              // for it, not the end customer.
              final courierTenant = _matchPartnerAccountByTracking(
                previous.trackingNumber,
              );
              final pickedUpByName =
                  pickedUpByController.text.trim().isNotEmpty
                  ? pickedUpByController.text.trim()
                  : (courierTenant?['company_name'] as String?) ??
                        previous.customerName;

              setDialogState(() => busy = true);
              try {
                await _db.updateWarehouseEntry(previous.id, {
                  'status': 'picked_up',
                  'picked_up_at': now.toIso8601String(),
                  'picked_up_by': pickedUpByName,
                });
              } catch (e) {
                setDialogState(() {
                  busy = false;
                  scanFeedback = 'Failed to confirm pickup: $e';
                  scanFeedbackIsError = true;
                });
                refocusTracking();
                return;
              }
              if (!mounted) return;
              if (idx != -1) {
                setState(() {
                  _entries[idx] = previous.copyWith(
                    status: WarehouseEntryStatus.pickedUp,
                    pickedUpAt: now,
                    pickedUpBy: pickedUpByName,
                  );
                });
              }
              setDialogState(() {
                busy = false;
                confirmed.insert(
                  0,
                  _PickupLogEntry(
                    previous: previous,
                    pickedUpByName: pickedUpByName,
                    pickedUpAt: now,
                  ),
                );
                scanFeedback =
                    '${previous.trackingNumber} confirmed picked up.';
                scanFeedbackIsError = false;
              });
              trackingController.clear();
              refocusTracking();
            }

            // Reverses a mis-scan: restores the entry's exact prior state
            // (status, picked_up_at, picked_up_by) in the database and on
            // screen, and drops it from the session log.
            Future<void> undoPickup(_PickupLogEntry log) async {
              if (busy) return;
              setDialogState(() => busy = true);
              try {
                await _db.updateWarehouseEntry(log.previous.id, {
                  'status': _statusDbValue(log.previous.status),
                  'picked_up_at': log.previous.pickedUpAt?.toIso8601String(),
                  'picked_up_by': log.previous.pickedUpBy,
                });
              } catch (e) {
                setDialogState(() {
                  busy = false;
                  scanFeedback = 'Failed to undo: $e';
                  scanFeedbackIsError = true;
                });
                refocusTracking();
                return;
              }
              if (!mounted) return;
              final idx = _entries.indexWhere(
                (e) => e.id == log.previous.id,
              );
              if (idx != -1) {
                setState(() => _entries[idx] = log.previous);
              }
              setDialogState(() {
                busy = false;
                confirmed.remove(log);
                scanFeedback = '${log.previous.trackingNumber} pickup undone.';
                scanFeedbackIsError = false;
              });
              refocusTracking();
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Confirm Pickup'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan each package as the courier takes it — every '
                      'match is confirmed picked up immediately, no extra '
                      'click needed.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: pickedUpByController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Picked up by (optional)',
                        hintText: "Courier rep's name for this batch",
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: trackingController,
                      focusNode: trackingFocusNode,
                      autofocus: true,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      onSubmitted: confirmPickup,
                      decoration: InputDecoration(
                        labelText: 'Tracking Number',
                        hintText: 'Scan barcode or type tracking number',
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: busy
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: () =>
                                    confirmPickup(trackingController.text),
                              ),
                      ),
                    ),
                    if (scanFeedback != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scanFeedbackIsError
                              ? AppTheme.danger.withValues(alpha: 0.08)
                              : AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              scanFeedbackIsError
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: scanFeedbackIsError
                                  ? AppTheme.danger
                                  : AppTheme.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                scanFeedback!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scanFeedbackIsError
                                      ? AppTheme.danger
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Confirmed this session (${confirmed.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: confirmed.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: Text(
                                'Nothing scanned yet.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: confirmed.length,
                              itemBuilder: (context, i) {
                                final log = confirmed[i];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.check_circle,
                                    color: AppTheme.success,
                                    size: 20,
                                  ),
                                  title: Text(
                                    log.previous.trackingNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${log.previous.customerName} • by '
                                    '${log.pickedUpByName} • '
                                    '${DateFormat('h:mm a').format(log.pickedUpAt)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => undoPickup(log),
                                    child: const Text('Undo'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _assignLocation(WarehouseEntry entry) {
    // Resolve to the real storage_locations row (separate shelf/slot) up
    // front, not the synthetic one on `entry` — see _resolveRealLocation.
    StorageLocation? selectedLocation =
        _resolveRealLocation(entry.storageLocation) ?? entry.storageLocation;

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
                        // The resolved *real* current location (not
                        // entry.storageLocation directly — see
                        // _resolveRealLocation) so re-saving without
                        // touching the dropdown writes clean shelf/slot
                        // text instead of re-joining the synthetic one.
                        if (selectedLocation != null) selectedLocation!,
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

  // Both helpers below only consider active partners — the Carrier
  // dropdown's own items list is filtered to _partners.where((p) =>
  // p.isActive), so returning an inactive one here would hand
  // DropdownButtonFormField a `value` that isn't among its `items`, which
  // is a hard Flutter assertion failure, not a graceful fallback.
  ShippingPartner? _matchPartnerByTracking(String tracking) {
    if (tracking.isEmpty) return null;
    final upper = tracking.toUpperCase();
    for (final p in _partners) {
      if (p.isActive &&
          p.trackingPrefix.isNotEmpty &&
          upper.startsWith(p.trackingPrefix.toUpperCase())) {
        return p;
      }
    }
    return null;
  }

  /// The seeded "One Village Shipping & Freight" partner row — the default
  /// courier selection for a package that isn't tied to an external courier.
  ShippingPartner? _ovsPartner() {
    for (final p in _partners) {
      if (p.code == 'OVS' && p.isActive) return p;
    }
    return null;
  }

  /// Which courier tenant (partner_accounts — e.g. Howdidship) a package
  /// belongs to, by tracking-number prefix. Distinct from _matchPartnerByTracking
  /// above, which matches the delivery carrier (shipping_partners — e.g.
  /// DHL); a tenant's own customers' packages carry the tenant's prefix
  /// regardless of which carrier physically delivered them.
  Map<String, dynamic>? _matchPartnerAccountByTracking(String tracking) {
    if (tracking.isEmpty) return null;
    final upper = tracking.toUpperCase();
    for (final p in _partnerAccounts) {
      final prefix = (p['tracking_prefix'] as String?) ?? '';
      if (prefix.isNotEmpty && upper.startsWith(prefix.toUpperCase())) {
        return p;
      }
    }
    return null;
  }

  /// The seeded "One Village Shipping & Freight" courier tenant — default
  /// when a tracking number doesn't match any other courier's own prefix,
  /// mirroring how the Carrier field itself defaults to _ovsPartner().
  Map<String, dynamic>? _defaultCourierTenant() {
    for (final p in _partnerAccounts) {
      if (((p['tracking_prefix'] as String?) ?? '').toUpperCase() == 'OVS-') {
        return p;
      }
    }
    return null;
  }
}

/// One pickup confirmed during a Confirm Pickup scan session — keeps the
/// entry's exact state from just before the scan, so an Undo can put it
/// straight back rather than guess at what it used to be.
class _PickupLogEntry {
  final WarehouseEntry previous;
  final String pickedUpByName;
  final DateTime pickedUpAt;

  _PickupLogEntry({
    required this.previous,
    required this.pickedUpByName,
    required this.pickedUpAt,
  });
}

/// Reverse of the status switch in [WarehouseEntry.fromMap] — needed to
/// write the exact prior status back to the database when a scan is undone.
String _statusDbValue(WarehouseEntryStatus status) {
  switch (status) {
    case WarehouseEntryStatus.scannedIn:
      return 'scanned_in';
    case WarehouseEntryStatus.stored:
      return 'stored';
    case WarehouseEntryStatus.readyForPickup:
      return 'ready_for_pickup';
    case WarehouseEntryStatus.pickedUp:
      return 'picked_up';
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
                  ? AppTheme.danger
                  : pct >= 0.6
                  ? AppTheme.warning
                  : AppTheme.success;

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
  final ValueChanged<WarehouseEntry> onBillCourier;
  final ValueChanged<WarehouseEntry> onPrintLabel;

  const _InventoryTable({
    required this.entries,
    required this.onAssignLocation,
    required this.onMarkReady,
    required this.onMarkPickedUp,
    required this.onBillCourier,
    required this.onPrintLabel,
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
        4: FlexColumnWidth(1.5),
        5: FlexColumnWidth(1),
        6: FlexColumnWidth(1.2),
        7: FlexColumnWidth(1.5),
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
            _HeaderCell('Courier Charge'),
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
                    ? Container(
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
                      )
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
              ),
              // ── Courier Charge column ──
              _BodyCell(
                child: entry.partnerChargeStatus == 'unbilled'
                    ? Text(
                        'Not billed',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${entry.partnerChargeAmount?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (entry.partnerChargeStatus == 'paid'
                                          ? AppTheme.success
                                          : AppTheme.warning)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.partnerChargeStatus == 'paid'
                                  ? 'Paid'
                                  : 'Billed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: entry.partnerChargeStatus == 'paid'
                                    ? AppTheme.success
                                    : AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
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
                  onBillCourier: onBillCourier,
                  onPrintLabel: onPrintLabel,
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
  final ValueChanged<WarehouseEntry> onBillCourier;
  final ValueChanged<WarehouseEntry> onPrintLabel;

  const _ActionsMenu({
    required this.entry,
    required this.onAssignLocation,
    required this.onMarkReady,
    required this.onMarkPickedUp,
    required this.onBillCourier,
    required this.onPrintLabel,
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

        // Reprint the label — printer jams, torn labels, or a duplicate
        // for a second box all happen; scan-in shouldn't be the only
        // chance to get one.
        items.add(
          const PopupMenuItem(
            value: 'print',
            child: ListTile(
              leading: Icon(Icons.print_outlined, size: 18),
              title: Text('Print Label', style: TextStyle(fontSize: 13)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );

        // Bill (or update the charge on) the courier this package belongs to
        items.add(
          PopupMenuItem(
            value: 'bill',
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined, size: 18),
              title: Text(
                entry.partnerChargeStatus == 'unbilled'
                    ? 'Bill Courier'
                    : 'Update Courier Charge',
                style: const TextStyle(fontSize: 13),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );

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
          case 'bill':
            onBillCourier(entry);
          case 'print':
            onPrintLabel(entry);
        }
      },
    );
  }
}
