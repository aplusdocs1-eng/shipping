import 'package:flutter/material.dart';

enum PackageStatus {
  pending,
  inTransit,
  outForDelivery,
  delivered,
  exception,
  returned,
}

extension PackageStatusExt on PackageStatus {
  String get label {
    switch (this) {
      case PackageStatus.pending:
        return 'Pending';
      case PackageStatus.inTransit:
        return 'In Transit';
      case PackageStatus.outForDelivery:
        return 'Out for Delivery';
      case PackageStatus.delivered:
        return 'Delivered';
      case PackageStatus.exception:
        return 'Exception';
      case PackageStatus.returned:
        return 'Returned';
    }
  }

  Color get color {
    switch (this) {
      case PackageStatus.pending:
        return const Color(0xFFF59E0B);
      case PackageStatus.inTransit:
        return const Color(0xFF0EA5E9);
      case PackageStatus.outForDelivery:
        return const Color(0xFF8B5CF6);
      case PackageStatus.delivered:
        return const Color(0xFF10B981);
      case PackageStatus.exception:
        return const Color(0xFFEF4444);
      case PackageStatus.returned:
        return const Color(0xFF6B7280);
    }
  }

  IconData get icon {
    switch (this) {
      case PackageStatus.pending:
        return Icons.schedule;
      case PackageStatus.inTransit:
        return Icons.local_shipping;
      case PackageStatus.outForDelivery:
        return Icons.delivery_dining;
      case PackageStatus.delivered:
        return Icons.check_circle;
      case PackageStatus.exception:
        return Icons.warning;
      case PackageStatus.returned:
        return Icons.keyboard_return;
    }
  }
}

class Package {
  final String id;
  final String trackingNumber;
  final String description;
  final String customerId;
  final String customerName;
  final String origin;
  final String destination;
  final double weight;
  final PackageStatus status;
  final DateTime createdAt;
  final DateTime? estimatedDelivery;
  final double declaredValue;
  final String? notes;
  final String? shipmentId;
  final List<TrackingEvent> events;

  Package({
    required this.id,
    required this.trackingNumber,
    required this.description,
    required this.customerId,
    required this.customerName,
    required this.origin,
    required this.destination,
    required this.weight,
    required this.status,
    required this.createdAt,
    this.estimatedDelivery,
    required this.declaredValue,
    this.notes,
    this.shipmentId,
    this.events = const [],
  });

  factory Package.fromMap(Map<String, dynamic> m) {
    PackageStatus st = PackageStatus.pending;
    switch (m['status']?.toString()) {
      case 'in_transit':
        st = PackageStatus.inTransit;
        break;
      case 'out_for_delivery':
        st = PackageStatus.outForDelivery;
        break;
      case 'delivered':
        st = PackageStatus.delivered;
        break;
      case 'ready_for_pickup':
        st = PackageStatus.delivered;
        break;
      case 'exception':
        st = PackageStatus.exception;
        break;
      case 'returned':
        st = PackageStatus.returned;
        break;
    }
    return Package(
      id: m['id']?.toString() ?? '',
      trackingNumber: m['tracking_number']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      customerId: m['customer_id']?.toString() ?? '',
      customerName: m['customer_name']?.toString() ?? '',
      origin: m['origin']?.toString() ?? '',
      destination: m['destination']?.toString() ?? '',
      weight: double.tryParse(m['weight']?.toString() ?? '0') ?? 0.0,
      status: st,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
      declaredValue:
          double.tryParse(m['declared_value']?.toString() ?? '0') ?? 0.0,
      notes: m['notes']?.toString(),
      shipmentId: m['shipment_id']?.toString(),
    );
  }
}

class TrackingEvent {
  final String description;
  final String location;
  final DateTime timestamp;

  TrackingEvent({
    required this.description,
    required this.location,
    required this.timestamp,
  });
}

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String country;
  final DateTime joinedAt;
  final int totalPackages;
  final double balance;
  final bool isActive;
  // partner_accounts.id this customer belongs to — the "courier" (reseller
  // tenant) sense used throughout the app, e.g. Howdidship, not the
  // shipping_partners delivery-carrier sense. Every customer has one
  // (direct/One Village customers carry the seeded OVS tenant id), but
  // it's nullable here defensively in case of legacy/unscoped rows.
  final String? partnerId;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.country,
    required this.joinedAt,
    required this.totalPackages,
    required this.balance,
    required this.isActive,
    this.partnerId,
  });

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    email: m['email']?.toString() ?? '',
    phone: m['phone']?.toString() ?? '',
    address: m['address']?.toString() ?? '',
    city: '',
    country: '',
    joinedAt:
        DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
    totalPackages: 0,
    balance: 0.0,
    isActive: (m['status']?.toString() ?? 'active') != 'inactive',
    partnerId: m['partner_id']?.toString(),
  );

  Customer copyWith({int? totalPackages, double? balance}) => Customer(
    id: id,
    name: name,
    email: email,
    phone: phone,
    address: address,
    city: city,
    country: country,
    joinedAt: joinedAt,
    totalPackages: totalPackages ?? this.totalPackages,
    balance: balance ?? this.balance,
    isActive: isActive,
    partnerId: partnerId,
  );
}

enum InvoiceStatus { draft, sent, paid, overdue, cancelled }

extension InvoiceStatusExt on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case InvoiceStatus.draft:
        return const Color(0xFF6B7280);
      case InvoiceStatus.sent:
        return const Color(0xFF0EA5E9);
      case InvoiceStatus.paid:
        return const Color(0xFF10B981);
      case InvoiceStatus.overdue:
        return const Color(0xFFEF4444);
      case InvoiceStatus.cancelled:
        return const Color(0xFF9CA3AF);
    }
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final List<InvoiceLineItem> lineItems;
  final InvoiceStatus status;
  final DateTime createdAt;
  final DateTime? dueAt;
  final double subtotal;
  final double tax;
  final double total;
  final String? notes;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.lineItems,
    required this.status,
    required this.createdAt,
    this.dueAt,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.notes,
  });

  factory Invoice.fromMap(Map<String, dynamic> m) {
    InvoiceStatus st = InvoiceStatus.sent;
    switch (m['status']?.toString()) {
      case 'draft':
        st = InvoiceStatus.draft;
        break;
      case 'paid':
        st = InvoiceStatus.paid;
        break;
      case 'overdue':
        st = InvoiceStatus.overdue;
        break;
      case 'cancelled':
        st = InvoiceStatus.cancelled;
        break;
    }
    return Invoice(
      id: m['id']?.toString() ?? '',
      invoiceNumber: m['invoice_number']?.toString() ?? '',
      customerId: m['customer_id']?.toString() ?? '',
      customerName: m['customer_name']?.toString() ?? '',
      lineItems: const [],
      status: st,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
      // No fallback: a missing due_date means the invoice genuinely has none
      // set, not "30 days from whenever this happened to load".
      dueAt: m['due_date'] == null
          ? null
          : DateTime.tryParse(m['due_date'].toString()),
      subtotal: double.tryParse(m['amount']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(m['tax']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(m['total']?.toString() ?? '0') ?? 0.0,
      notes: m['notes']?.toString(),
    );
  }
}

class InvoiceLineItem {
  final String description;
  final int quantity;
  final double unitPrice;

  InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;
}

// ─── Pre-Alert ───────────────────────────────────────────────────────────────

enum PreAlertStatus { pending, received, processing, ready, completed }

extension PreAlertStatusExt on PreAlertStatus {
  String get label {
    switch (this) {
      case PreAlertStatus.pending:
        return 'Pending';
      case PreAlertStatus.received:
        return 'Received';
      case PreAlertStatus.processing:
        return 'Processing';
      case PreAlertStatus.ready:
        return 'Ready for Pickup';
      case PreAlertStatus.completed:
        return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case PreAlertStatus.pending:
        return const Color(0xFFF59E0B);
      case PreAlertStatus.received:
        return const Color(0xFF0EA5E9);
      case PreAlertStatus.processing:
        return const Color(0xFF8B5CF6);
      case PreAlertStatus.ready:
        return const Color(0xFF10B981);
      case PreAlertStatus.completed:
        return const Color(0xFF6B7280);
    }
  }
}

class PreAlert {
  final String id;
  final String customerId;
  final String customerName;
  final String trackingNumber;
  final String carrier;
  final String description;
  final double weight;
  final double declaredValue;
  final String freightType; // 'air' | 'sea'
  final PreAlertStatus status;
  final DateTime submittedAt;
  final String? invoiceUrl;

  PreAlert({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.trackingNumber,
    required this.carrier,
    required this.description,
    required this.weight,
    required this.declaredValue,
    required this.freightType,
    required this.status,
    required this.submittedAt,
    this.invoiceUrl,
  });

  factory PreAlert.fromMap(Map<String, dynamic> m) {
    PreAlertStatus st = PreAlertStatus.pending;
    switch (m['status']?.toString()) {
      case 'received':
        st = PreAlertStatus.received;
        break;
      case 'processing':
        st = PreAlertStatus.processing;
        break;
      case 'ready':
      case 'ready_for_pickup':
        st = PreAlertStatus.ready;
        break;
      case 'completed':
        st = PreAlertStatus.completed;
        break;
    }
    return PreAlert(
      id: m['id']?.toString() ?? '',
      customerId: m['customer_id']?.toString() ?? '',
      customerName: m['customer_name']?.toString() ?? '',
      trackingNumber: m['tracking_number']?.toString() ?? '',
      carrier: m['carrier']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      weight: double.tryParse(m['weight']?.toString() ?? '0') ?? 0.0,
      declaredValue:
          double.tryParse(m['declared_value']?.toString() ?? '0') ?? 0.0,
      freightType: m['freight_type']?.toString() ?? 'air',
      status: st,
      submittedAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ─── Shipment ────────────────────────────────────────────────────────────────

enum ShipmentType { air, sea }

enum ShipmentStatus { preparing, inTransit, arrived, cleared, closed }

extension ShipmentStatusExt on ShipmentStatus {
  String get label {
    switch (this) {
      case ShipmentStatus.preparing:
        return 'Preparing';
      case ShipmentStatus.inTransit:
        return 'In Transit';
      case ShipmentStatus.arrived:
        return 'Arrived';
      case ShipmentStatus.cleared:
        return 'Customs Cleared';
      case ShipmentStatus.closed:
        return 'Closed';
    }
  }

  Color get color {
    switch (this) {
      case ShipmentStatus.preparing:
        return const Color(0xFFF59E0B);
      case ShipmentStatus.inTransit:
        return const Color(0xFF0EA5E9);
      case ShipmentStatus.arrived:
        return const Color(0xFF8B5CF6);
      case ShipmentStatus.cleared:
        return const Color(0xFF10B981);
      case ShipmentStatus.closed:
        return const Color(0xFF6B7280);
    }
  }
}

class Shipment {
  final String id;
  final String shipmentNumber;
  final ShipmentType type;
  final ShipmentStatus status;
  final String origin;
  final String destination;
  final DateTime departureDate;
  final DateTime? arrivalDate;
  final int packageCount;
  final double totalWeight;
  final String? vesselName;
  final String? flightNumber;
  final String? notes;

  Shipment({
    required this.id,
    required this.shipmentNumber,
    required this.type,
    required this.status,
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.arrivalDate,
    required this.packageCount,
    required this.totalWeight,
    this.vesselName,
    this.flightNumber,
    this.notes,
  });

  factory Shipment.fromMap(Map<String, dynamic> m) {
    ShipmentStatus st = ShipmentStatus.preparing;
    switch (m['status']?.toString()) {
      case 'in_transit':
        st = ShipmentStatus.inTransit;
        break;
      case 'arrived':
        st = ShipmentStatus.arrived;
        break;
      case 'cleared':
        st = ShipmentStatus.cleared;
        break;
      case 'closed':
        st = ShipmentStatus.closed;
        break;
    }
    return Shipment(
      id: m['id']?.toString() ?? '',
      shipmentNumber: m['shipment_number']?.toString() ?? '',
      type: (m['carrier']?.toString() ?? '').toLowerCase().contains('sea')
          ? ShipmentType.sea
          : ShipmentType.air,
      status: st,
      origin: m['origin']?.toString() ?? '',
      destination: m['destination']?.toString() ?? '',
      departureDate:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
      arrivalDate: m['estimated_arrival'] != null
          ? DateTime.tryParse(m['estimated_arrival'].toString())
          : null,
      packageCount: int.tryParse(m['total_packages']?.toString() ?? '0') ?? 0,
      totalWeight: double.tryParse(m['total_weight']?.toString() ?? '0') ?? 0.0,
      vesselName: m['vessel_name']?.toString(),
      flightNumber: m['flight_number']?.toString(),
      notes: m['notes']?.toString(),
    );
  }
}

// ─── Branch ──────────────────────────────────────────────────────────────────

class Branch {
  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final bool isMainBranch;
  final bool isActive;
  final int staffCount;
  final int packagesThisMonth;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.isMainBranch,
    required this.isActive,
    required this.staffCount,
    required this.packagesThisMonth,
  });

  factory Branch.fromMap(Map<String, dynamic> m) => Branch(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    address: m['address']?.toString() ?? '',
    city: m['city']?.toString() ?? '',
    phone: m['phone']?.toString() ?? '',
    email: m['email']?.toString() ?? '',
    isMainBranch: false,
    isActive: m['is_active'] == true,
    staffCount: 0,
    packagesThisMonth: 0,
  );

  Branch copyWith({int? staffCount, int? packagesThisMonth}) => Branch(
    id: id,
    name: name,
    address: address,
    city: city,
    phone: phone,
    email: email,
    isMainBranch: isMainBranch,
    isActive: isActive,
    staffCount: staffCount ?? this.staffCount,
    packagesThisMonth: packagesThisMonth ?? this.packagesThisMonth,
  );
}

// ─── Staff ───────────────────────────────────────────────────────────────────

enum StaffRole { admin, manager, agent, driver }

extension StaffRoleExt on StaffRole {
  String get label {
    switch (this) {
      case StaffRole.admin:
        return 'Admin';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.agent:
        return 'Agent';
      case StaffRole.driver:
        return 'Driver';
    }
  }

  Color get color {
    switch (this) {
      case StaffRole.admin:
        return const Color(0xFF8B5CF6);
      case StaffRole.manager:
        return const Color(0xFF1A56DB);
      case StaffRole.agent:
        return const Color(0xFF0EA5E9);
      case StaffRole.driver:
        return const Color(0xFF10B981);
    }
  }
}

class StaffMember {
  final String id;
  final String name;
  final String email;
  final String phone;
  final StaffRole role;
  final String branchId;
  final String branchName;
  final bool isActive;
  final DateTime joinedAt;
  final DateTime? lastLogin;

  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.branchId,
    required this.branchName,
    required this.isActive,
    required this.joinedAt,
    this.lastLogin,
  });

  factory StaffMember.fromMap(Map<String, dynamic> m) {
    StaffRole role = StaffRole.agent;
    switch (m['role']?.toString()) {
      case 'admin':
        role = StaffRole.admin;
        break;
      case 'manager':
        role = StaffRole.manager;
        break;
      case 'driver':
        role = StaffRole.driver;
        break;
    }
    return StaffMember(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      email: m['email']?.toString() ?? '',
      phone: m['phone']?.toString() ?? '',
      role: role,
      branchId: m['branch_id']?.toString() ?? '',
      branchName: (m['branches'] as Map?)?['name']?.toString() ?? '',
      isActive: m['is_active'] == true,
      joinedAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ─── POS ─────────────────────────────────────────────────────────────────────

class PosItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String unit;
  final bool isActive;

  PosItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    this.isActive = true,
  });
}

class PosTransaction {
  final String id;
  final String receiptNumber;
  final String? customerId;
  final String customerName;
  final List<PosCartItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String paymentMethod;
  final DateTime createdAt;

  PosTransaction({
    required this.id,
    required this.receiptNumber,
    required this.customerName,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    this.customerId,
  });
}

class PosCartItem {
  final PosItem item;
  int quantity;

  PosCartItem({required this.item, this.quantity = 1});

  double get total => item.price * quantity;
}

// ─── Rate Calculator ─────────────────────────────────────────────────────────

class ShippingRate {
  final String zone;
  final double ratePerLb;
  final double ratePerKg;
  final double minimumCharge;
  final String freightType;
  final int transitDays;

  ShippingRate({
    required this.zone,
    required this.ratePerLb,
    required this.ratePerKg,
    required this.minimumCharge,
    required this.freightType,
    required this.transitDays,
  });
}

// ─── Email Campaign ──────────────────────────────────────────────────────────

enum CampaignStatus { draft, scheduled, sent }

class EmailCampaign {
  final String id;
  final String subject;
  final String body;
  final CampaignStatus status;
  final int recipientCount;
  final int? openCount;
  final DateTime createdAt;
  final DateTime? sentAt;

  EmailCampaign({
    required this.id,
    required this.subject,
    required this.body,
    required this.status,
    required this.recipientCount,
    this.openCount,
    required this.createdAt,
    this.sentAt,
  });
}

// ─── Warehouse / Inventory ───────────────────────────────────────────────────

class StorageZone {
  final String id;
  final String name;
  final String branchId;
  final String branchName;
  final int totalSlots;
  final int usedSlots;

  StorageZone({
    required this.id,
    required this.name,
    required this.branchId,
    required this.branchName,
    required this.totalSlots,
    required this.usedSlots,
  });

  int get availableSlots => totalSlots - usedSlots;
  bool get isFull => usedSlots >= totalSlots;
}

class StorageLocation {
  final String id;
  final String zoneId;
  final String zoneName;
  final String shelf;
  final String slot;
  final String branchId;
  final String branchName;

  StorageLocation({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.shelf,
    required this.slot,
    required this.branchId,
    required this.branchName,
  });

  // A StorageLocation reconstructed from a warehouse_entries row (see
  // WarehouseEntry.fromMap) always has an empty slot — its shelf already
  // holds the whole raw "shelf-slot" text stored in that row's single
  // storage_location column. Appending "-$slot" unconditionally would tack
  // on a phantom trailing "-" for every one of those (e.g. "Zone A / 1-1-"
  // instead of "Zone A / 1-1"); only append it when slot actually is a
  // separate, non-empty value, as it is for a real storage_locations row.
  String get displayLabel =>
      slot.isEmpty ? '$zoneName / $shelf' : '$zoneName / $shelf-$slot';
}

enum WarehouseEntryStatus { scannedIn, stored, readyForPickup, pickedUp }

extension WarehouseEntryStatusExt on WarehouseEntryStatus {
  String get label {
    switch (this) {
      case WarehouseEntryStatus.scannedIn:
        return 'Scanned In';
      case WarehouseEntryStatus.stored:
        return 'Stored';
      case WarehouseEntryStatus.readyForPickup:
        return 'Ready for Pickup';
      case WarehouseEntryStatus.pickedUp:
        return 'Picked Up';
    }
  }

  Color get color {
    switch (this) {
      case WarehouseEntryStatus.scannedIn:
        return const Color(0xFF0EA5E9);
      case WarehouseEntryStatus.stored:
        return const Color(0xFF8B5CF6);
      case WarehouseEntryStatus.readyForPickup:
        return const Color(0xFFF59E0B);
      case WarehouseEntryStatus.pickedUp:
        return const Color(0xFF10B981);
    }
  }

  IconData get icon {
    switch (this) {
      case WarehouseEntryStatus.scannedIn:
        return Icons.qr_code_scanner;
      case WarehouseEntryStatus.stored:
        return Icons.warehouse;
      case WarehouseEntryStatus.readyForPickup:
        return Icons.local_shipping_outlined;
      case WarehouseEntryStatus.pickedUp:
        return Icons.check_circle;
    }
  }
}

class WarehouseEntry {
  final String id;
  final String packageId;
  final String trackingNumber;
  final String customerName;
  final String description;
  final double weight;
  final StorageLocation? storageLocation;
  final WarehouseEntryStatus status;
  final DateTime scannedInAt;
  final String scannedInBy;
  final DateTime? pickedUpAt;
  final String? pickedUpBy;
  final String? notes;
  final String? shippingPartnerCode;
  final bool syncedToPartner;
  final double? partnerChargeAmount;
  final String partnerChargeStatus;
  final String? partnerChargeNote;
  final DateTime? partnerChargedAt;
  final DateTime? partnerPaidAt;

  WarehouseEntry({
    required this.id,
    required this.packageId,
    required this.trackingNumber,
    required this.customerName,
    required this.description,
    required this.weight,
    this.storageLocation,
    required this.status,
    required this.scannedInAt,
    required this.scannedInBy,
    this.pickedUpAt,
    this.pickedUpBy,
    this.notes,
    this.shippingPartnerCode,
    this.syncedToPartner = false,
    this.partnerChargeAmount,
    this.partnerChargeStatus = 'unbilled',
    this.partnerChargeNote,
    this.partnerChargedAt,
    this.partnerPaidAt,
  });

  factory WarehouseEntry.fromMap(Map<String, dynamic> m) {
    WarehouseEntryStatus status;
    switch (m['status'] as String? ?? 'scanned_in') {
      case 'stored':
        status = WarehouseEntryStatus.stored;
        break;
      case 'ready_for_pickup':
        status = WarehouseEntryStatus.readyForPickup;
        break;
      case 'picked_up':
        status = WarehouseEntryStatus.pickedUp;
        break;
      default:
        status = WarehouseEntryStatus.scannedIn;
    }
    final zoneName = m['storage_zone'] as String?;
    final locName = m['storage_location'] as String?;
    StorageLocation? loc;
    if (zoneName != null && locName != null) {
      loc = StorageLocation(
        id: '$zoneName-$locName',
        zoneId: zoneName,
        zoneName: zoneName,
        shelf: locName,
        slot: '',
        branchId: '',
        branchName: '',
      );
    }
    return WarehouseEntry(
      id: m['id'] as String? ?? '',
      packageId: m['package_id'] as String? ?? '',
      trackingNumber: m['tracking_number'] as String? ?? '',
      customerName: m['customer_name'] as String? ?? '',
      description: m['description'] as String? ?? '',
      weight: (m['weight'] as num?)?.toDouble() ?? 0.0,
      storageLocation: loc,
      status: status,
      scannedInAt: m['scanned_in_at'] != null
          ? DateTime.parse(m['scanned_in_at'] as String)
          : DateTime.now(),
      scannedInBy: m['scanned_in_by'] as String? ?? '',
      pickedUpAt: m['picked_up_at'] != null
          ? DateTime.parse(m['picked_up_at'] as String)
          : null,
      pickedUpBy: m['picked_up_by'] as String?,
      shippingPartnerCode: m['shipping_partner_code'] as String?,
      syncedToPartner: m['synced_to_partner'] as bool? ?? false,
      partnerChargeAmount: (m['partner_charge_amount'] as num?)?.toDouble(),
      partnerChargeStatus: m['partner_charge_status'] as String? ?? 'unbilled',
      partnerChargeNote: m['partner_charge_note'] as String?,
      partnerChargedAt: m['partner_charged_at'] != null
          ? DateTime.tryParse(m['partner_charged_at'] as String)
          : null,
      partnerPaidAt: m['partner_paid_at'] != null
          ? DateTime.tryParse(m['partner_paid_at'] as String)
          : null,
    );
  }

  WarehouseEntry copyWith({
    StorageLocation? storageLocation,
    WarehouseEntryStatus? status,
    DateTime? pickedUpAt,
    String? pickedUpBy,
    String? notes,
    String? shippingPartnerCode,
    bool? syncedToPartner,
  }) {
    return WarehouseEntry(
      id: id,
      packageId: packageId,
      trackingNumber: trackingNumber,
      customerName: customerName,
      description: description,
      weight: weight,
      storageLocation: storageLocation ?? this.storageLocation,
      status: status ?? this.status,
      scannedInAt: scannedInAt,
      scannedInBy: scannedInBy,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      pickedUpBy: pickedUpBy ?? this.pickedUpBy,
      notes: notes ?? this.notes,
      shippingPartnerCode: shippingPartnerCode ?? this.shippingPartnerCode,
      syncedToPartner: syncedToPartner ?? this.syncedToPartner,
    );
  }
}

// ─── Shipping Partner ────────────────────────────────────────────────────────

class ShippingPartner {
  final String id;
  final String code;
  final String name;
  final String region;
  final String trackingPrefix;
  final String contactEmail;
  final bool isActive;

  ShippingPartner({
    this.id = '',
    required this.code,
    required this.name,
    required this.region,
    required this.trackingPrefix,
    required this.contactEmail,
    this.isActive = true,
  });

  factory ShippingPartner.fromMap(Map<String, dynamic> m) => ShippingPartner(
    id: m['id']?.toString() ?? '',
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    region: m['region'] as String? ?? '',
    trackingPrefix: m['tracking_prefix'] as String? ?? '',
    contactEmail: m['contact_email'] as String? ?? '',
    isActive: m['is_active'] as bool? ?? true,
  );
}
