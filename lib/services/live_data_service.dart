import '../models/models.dart';
import 'database_service.dart';
import '../data/mock_data.dart';

/// Live data service backed by Supabase.
///
/// Exposes the same fields as [MockDataService] so screens can be swapped
/// in place. For data categories that do not yet have a clean Supabase
/// schema (POS, email campaigns, shipping rates, invoice line items,
/// storage zones/locations with nested refs), we fall back to the
/// [MockDataService] instance.
class LiveDataService {
  LiveDataService._internal();
  static final LiveDataService _instance = LiveDataService._internal();
  factory LiveDataService() => _instance;

  final _db = DatabaseService();
  final _mock = MockDataService();

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ─── Live (DB-backed) collections ──────────────────────────────
  List<Customer> customers = [];
  List<Package> packages = [];
  List<Shipment> shipments = [];
  List<Branch> branches = [];
  List<StaffMember> staff = [];
  List<PreAlert> preAlerts = [];

  // ─── Fallback (still mock) ─────────────────────────────────────
  List<Invoice> get invoices => _mock.invoices;
  List<WarehouseEntry> get warehouseEntries => _mock.warehouseEntries;
  List<StorageZone> get storageZones => _mock.storageZones;
  List<StorageLocation> get storageLocations => _mock.storageLocations;
  List<PosItem> get posItems => _mock.posItems;
  List<PosTransaction> get posTransactions => _mock.posTransactions;
  List<ShippingRate> get shippingRates => _mock.shippingRates;
  List<EmailCampaign> get campaigns => _mock.campaigns;

  // ─── Computed stats ─────────────────────────────────────────────
  List<Map<String, dynamic>> get packageChartData => _mock.packageChartData;

  Map<String, int> get packageStatusCounts {
    final counts = <String, int>{};
    for (final p in packages) {
      counts[p.status.label] = (counts[p.status.label] ?? 0) + 1;
    }
    return counts;
  }

  double get totalRevenue => invoices.fold(0, (sum, inv) => sum + inv.total);
  double get paidRevenue => invoices
      .where((i) => i.status == InvoiceStatus.paid)
      .fold(0, (sum, inv) => sum + inv.total);
  double get overdueAmount => invoices
      .where((i) => i.status == InvoiceStatus.overdue)
      .fold(0, (sum, inv) => sum + inv.total);

  // ─── Loader ─────────────────────────────────────────────────────
  Future<void> load() async {
    final results = await Future.wait([
      _db.getCustomers(),
      _db.getPackages(),
      _db.getShipments(),
      _db.getBranches(),
      _db.getStaff(),
      _db.getPreAlerts(),
    ]);

    final branchRows = List<Map<String, dynamic>>.from(results[3]);
    branches = branchRows.map(_branchFromRow).toList();
    final branchById = {for (final b in branches) b.id: b};

    customers = List<Map<String, dynamic>>.from(
      results[0],
    ).map(_customerFromRow).toList();
    packages = List<Map<String, dynamic>>.from(
      results[1],
    ).map(_packageFromRow).toList();
    shipments = List<Map<String, dynamic>>.from(
      results[2],
    ).map(_shipmentFromRow).toList();
    staff = List<Map<String, dynamic>>.from(
      results[4],
    ).map((r) => _staffFromRow(r, branchById)).toList();
    preAlerts = List<Map<String, dynamic>>.from(
      results[5],
    ).map(_preAlertFromRow).toList();

    _loaded = true;
  }

  // ═══════════════ Row → Model mappers ═══════════════

  Customer _customerFromRow(Map<String, dynamic> r) {
    final addrParts = (r['address'] as String? ?? '').split(',');
    String city = '';
    String country = '';
    if (addrParts.length >= 2) {
      city = addrParts[addrParts.length - 2].trim();
      country = addrParts.last.trim();
    }
    return Customer(
      id: r['id'] as String,
      name: r['name'] as String? ?? '',
      email: r['email'] as String? ?? '',
      phone: r['phone'] as String? ?? '',
      address: r['address'] as String? ?? '',
      city: city,
      country: country,
      joinedAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      totalPackages: 0,
      balance: 0,
      isActive: (r['status'] as String? ?? 'active') == 'active',
    );
  }

  Package _packageFromRow(Map<String, dynamic> r) {
    return Package(
      id: r['id'] as String,
      trackingNumber: r['tracking_number'] as String? ?? '',
      description: r['description'] as String? ?? '',
      customerId: r['customer_id'] as String? ?? '',
      customerName: r['customer_name'] as String? ?? '',
      origin: r['origin'] as String? ?? '',
      destination: r['destination'] as String? ?? '',
      weight: (r['weight'] as num?)?.toDouble() ?? 0,
      status: _packageStatus(r['status'] as String?),
      createdAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      declaredValue: (r['declared_value'] as num?)?.toDouble() ?? 0,
    );
  }

  Shipment _shipmentFromRow(Map<String, dynamic> r) {
    final carrier = r['carrier'] as String? ?? '';
    final isSea =
        carrier.toLowerCase().contains('sea') ||
        (r['shipment_number'] as String? ?? '').toUpperCase().startsWith('SEA');
    return Shipment(
      id: r['id'] as String,
      shipmentNumber: r['shipment_number'] as String? ?? '',
      type: isSea ? ShipmentType.sea : ShipmentType.air,
      status: _shipmentStatus(r['status'] as String?),
      origin: r['origin'] as String? ?? '',
      destination: r['destination'] as String? ?? '',
      departureDate:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      arrivalDate: DateTime.tryParse(r['estimated_arrival'] as String? ?? ''),
      packageCount: (r['total_packages'] as num?)?.toInt() ?? 0,
      totalWeight: (r['total_weight'] as num?)?.toDouble() ?? 0,
      flightNumber: isSea ? null : carrier,
      vesselName: isSea ? carrier : null,
    );
  }

  Branch _branchFromRow(Map<String, dynamic> r) {
    return Branch(
      id: r['id'] as String,
      name: r['name'] as String? ?? '',
      address: r['address'] as String? ?? '',
      city: '',
      phone: r['phone'] as String? ?? '',
      email: r['email'] as String? ?? '',
      isMainBranch: (r['name'] as String? ?? '').toLowerCase().contains('head'),
      isActive: r['is_active'] as bool? ?? true,
      staffCount: 0,
      packagesThisMonth: 0,
    );
  }

  StaffMember _staffFromRow(
    Map<String, dynamic> r,
    Map<String, Branch> branchById,
  ) {
    final branchId = r['branch_id'] as String? ?? '';
    final branch = branchById[branchId];
    return StaffMember(
      id: r['id'] as String,
      name: r['name'] as String? ?? '',
      email: r['email'] as String? ?? '',
      phone: r['phone'] as String? ?? '',
      role: _staffRole(r['role'] as String?),
      branchId: branchId,
      branchName: branch?.name ?? '',
      isActive: r['is_active'] as bool? ?? true,
      joinedAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  PreAlert _preAlertFromRow(Map<String, dynamic> r) {
    return PreAlert(
      id: r['id'] as String,
      customerId: r['customer_id'] as String? ?? '',
      customerName: r['customer_name'] as String? ?? '',
      trackingNumber: r['tracking_number'] as String? ?? '',
      carrier: r['carrier'] as String? ?? '',
      description: r['description'] as String? ?? '',
      weight: 0,
      declaredValue: 0,
      freightType: 'air',
      status: _preAlertStatus(r['status'] as String?),
      submittedAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // ─── Enum helpers ───────────────────────────────────────────────
  PackageStatus _packageStatus(String? s) {
    switch (s) {
      case 'in_transit':
        return PackageStatus.inTransit;
      case 'out_for_delivery':
        return PackageStatus.outForDelivery;
      case 'delivered':
        return PackageStatus.delivered;
      case 'exception':
        return PackageStatus.exception;
      case 'returned':
        return PackageStatus.returned;
      default:
        return PackageStatus.pending;
    }
  }

  ShipmentStatus _shipmentStatus(String? s) {
    switch (s) {
      case 'in_transit':
        return ShipmentStatus.inTransit;
      case 'arrived':
        return ShipmentStatus.arrived;
      case 'cleared':
        return ShipmentStatus.cleared;
      case 'closed':
        return ShipmentStatus.closed;
      default:
        return ShipmentStatus.preparing;
    }
  }

  StaffRole _staffRole(String? s) {
    switch (s) {
      case 'admin':
        return StaffRole.admin;
      case 'manager':
        return StaffRole.manager;
      case 'driver':
        return StaffRole.driver;
      default:
        return StaffRole.agent;
    }
  }

  PreAlertStatus _preAlertStatus(String? s) {
    switch (s) {
      case 'received':
        return PreAlertStatus.received;
      case 'processing':
        return PreAlertStatus.processing;
      case 'ready':
        return PreAlertStatus.ready;
      case 'completed':
        return PreAlertStatus.completed;
      default:
        return PreAlertStatus.pending;
    }
  }
}
