import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Service for all Supabase database operations.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  SupabaseClient get _db => SupabaseConfig.client;

  // ─── Warehouse Entries ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWarehouseEntries() async {
    final data = await _db
        .from('warehouse_entries')
        .select()
        .order('scanned_in_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertWarehouseEntry({
    required String trackingNumber,
    required String customerName,
    required String description,
    required double weight,
    String? storageZone,
    String? storageLocation,
    required String status,
    required String scannedInBy,
    String? shippingPartnerCode,
    bool syncedToPartner = false,
  }) async {
    final row = {
      'tracking_number': trackingNumber,
      'customer_name': customerName,
      'description': description,
      'weight': weight,
      'storage_zone': storageZone,
      'storage_location': storageLocation,
      'status': status,
      'scanned_in_by': scannedInBy,
      'scanned_in_at': DateTime.now().toIso8601String(),
      'shipping_partner_code': shippingPartnerCode,
      'synced_to_partner': syncedToPartner,
    };
    final data = await _db
        .from('warehouse_entries')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateWarehouseEntry(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('warehouse_entries').update(updates).eq('id', id);
  }

  Future<void> deleteWarehouseEntry(String id) async {
    await _db.from('warehouse_entries').delete().eq('id', id);
  }

  // ─── Shipping Partners ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getShippingPartners() async {
    final data = await _db
        .from('shipping_partners')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertShippingPartner({
    required String code,
    required String name,
    required String region,
    required String trackingPrefix,
    required String contactEmail,
    bool isActive = true,
  }) async {
    final row = {
      'code': code,
      'name': name,
      'region': region,
      'tracking_prefix': trackingPrefix,
      'contact_email': contactEmail,
      'is_active': isActive,
    };
    final data = await _db
        .from('shipping_partners')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateShippingPartner(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('shipping_partners').update(updates).eq('id', id);
  }

  // ─── Packages ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPackages() async {
    final data = await _db
        .from('packages')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Packages whose tracking number starts with [prefix] (e.g. "DEMO-").
  Future<List<Map<String, dynamic>>> getPackagesByPrefix(String prefix) async {
    final data = await _db
        .from('packages')
        .select()
        .ilike('tracking_number', '$prefix%')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPackagesByPartner(
    String partnerId,
  ) async {
    final data = await _db
        .from('packages')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPackage(Map<String, dynamic> row) async {
    final data = await _db.from('packages').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  // ─── Customers ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final data = await _db
        .from('customers')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getCustomersByPartner(
    String partnerId,
  ) async {
    final data = await _db
        .from('customers')
        .select()
        .eq('partner_id', partnerId)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertCustomer(Map<String, dynamic> row) async {
    final data = await _db.from('customers').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  // ─── Invoices ────────────────────────────────────────────────────────

  /// Admin view: invoices where admin bills a partner account.
  Future<List<Map<String, dynamic>>> getInvoices() async {
    final data = await _db
        .from('invoices')
        .select()
        .eq('invoice_type', 'partner_billing')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// All invoices regardless of type – used for reports/totals.
  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final data = await _db
        .from('invoices')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Admin view: customer-billing invoices (partner→customer), all partners.
  Future<List<Map<String, dynamic>>> getCustomerBillingInvoices() async {
    final data = await _db
        .from('invoices')
        .select()
        .eq('invoice_type', 'customer_billing')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getInvoicesByPartner(
    String partnerId,
  ) async {
    // Partner sees only the customer-billing invoices they created.
    final data = await _db
        .from('invoices')
        .select()
        .eq('partner_id', partnerId)
        .eq('invoice_type', 'customer_billing')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Shipments ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getShipments() async {
    final data = await _db
        .from('shipments')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getShipmentsByPartner(
    String partnerId,
  ) async {
    final data = await _db
        .from('shipments')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Staff ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStaff() async {
    final data = await _db
        .from('staff')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Branches ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBranches() async {
    final data = await _db
        .from('branches')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Pre-Alerts ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPreAlerts() async {
    final data = await _db
        .from('pre_alerts')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPreAlertsByPartner(
    String partnerId,
  ) async {
    final data = await _db
        .from('pre_alerts')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Package / Invoice mutations used by the partner dashboard ─────

  Future<Map<String, dynamic>> updatePackage(
    String packageId,
    Map<String, dynamic> updates,
  ) async {
    final data = await _db
        .from('packages')
        .update(updates)
        .eq('id', packageId)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> createInvoiceForPackage({
    required Map<String, dynamic> pkg,
    required double amount,
    double taxRate = 0,
    String? partnerId,
    String? dueDate,
  }) async {
    final tax = (amount * taxRate).toStringAsFixed(2);
    final total = (amount + amount * taxRate).toStringAsFixed(2);
    final invNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final row = <String, dynamic>{
      'invoice_number': invNumber,
      'customer_id': pkg['customer_id'],
      'customer_name': pkg['customer_name'] ?? '',
      'amount': amount,
      'tax': double.parse(tax),
      'total': double.parse(total),
      'status': 'pending',
      'invoice_type': 'customer_billing',
      if (partnerId != null) 'partner_id': partnerId,
      if (dueDate != null) 'due_date': dueDate,
    };
    final data = await _db.from('invoices').insert(row).select().single();
    // Tag the package with its invoice so the warehouse pickup check can
    // gate on payment.
    try {
      await _db
          .from('packages')
          .update({'invoice_id': data['id'], 'billed_amount': total})
          .eq('id', pkg['id']);
    } catch (_) {
      // Columns may not exist yet; ignore.
    }
    return Map<String, dynamic>.from(data);
  }

  /// Admin bills a partner account (admin→partner invoice).
  Future<Map<String, dynamic>> createPartnerInvoice({
    required String partnerAccountId,
    required String partnerName,
    required double amount,
    double taxRate = 0,
    String? notes,
    String? dueDate,
  }) async {
    final tax = amount * taxRate;
    final total = amount + tax;
    final invNumber =
        'PINV-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final row = <String, dynamic>{
      'invoice_number': invNumber,
      'partner_account_id': partnerAccountId,
      'partner_name': partnerName,
      'customer_name': partnerName, // reuse customer_name for display
      'amount': amount,
      'tax': tax,
      'total': total,
      'status': 'pending',
      'invoice_type': 'partner_billing',
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': dueDate,
    };
    final data = await _db.from('invoices').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> markInvoicePaid(String invoiceId) async {
    final data = await _db
        .from('invoices')
        .update({
          'status': 'paid',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', invoiceId)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getInvoicesForCustomer(
    String customerId,
  ) async {
    final data = await _db
        .from('invoices')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> getCustomerByEmail(
    String email, {
    String? partnerId,
  }) async {
    final lc = email.toLowerCase();
    // Try exact lowercase match first; fall back to ilike for mixed-case stored emails.
    var q = _db.from('customers').select();
    // PostgREST: cast to lowercase to handle mixed-case stored values
    final rows = await q.or('email.eq.$lc,email.ilike.$lc').limit(5);
    if (rows.isEmpty) return null;
    // If partner-scoped, prefer the matching partner row.
    if (partnerId != null) {
      final scoped = rows.firstWhere(
        (r) => r['partner_id']?.toString() == partnerId,
        orElse: () => rows.first,
      );
      return Map<String, dynamic>.from(scoped);
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getPackagesByCustomer(
    String customerId,
  ) async {
    // Join invoices so the customer portal can show invoice number + total + status
    final data = await _db
        .from('packages')
        .select('*, invoices(invoice_number, total, status, due_date)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPreAlertsByCustomer(
    String customerId,
  ) async {
    final data = await _db
        .from('pre_alerts')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Partner Accounts ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPartnerAccounts() async {
    final data = await _db
        .from('partner_accounts')
        .select('id, company_name, contact_name, email')
        .order('company_name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> getPartnerAccount(String authUserId) async {
    final data = await _db
        .from('partner_accounts')
        .select()
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    return data;
  }

  Future<Map<String, dynamic>> insertPartnerAccount({
    required String authUserId,
    required String companyName,
    required String contactName,
    required String email,
    String? phone,
    required String trackingPrefix,
    String? domain,
  }) async {
    final data = await _db.rpc(
      'create_partner_account',
      params: {
        'p_auth_user_id': authUserId,
        'p_company_name': companyName,
        'p_contact_name': contactName,
        'p_email': email,
        'p_phone': phone ?? '',
        'p_tracking_prefix': trackingPrefix,
        'p_domain': domain ?? '',
      },
    );
    final list = List<Map<String, dynamic>>.from(data as List);
    return list.first;
  }

  Future<void> updatePartnerAccount(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('partner_accounts').update(updates).eq('id', id);
  }

  Future<void> setPartnerApiKey(String accountId, String apiKey) async {
    await _db
        .from('partner_accounts')
        .update({'api_key': apiKey})
        .eq('id', accountId);
  }

  Future<void> approvePartnerAccount(String accountId) async {
    await _db
        .from('partner_accounts')
        .update({'status': 'approved'})
        .eq('id', accountId);
  }

  Future<void> rejectPartnerAccount(String accountId) async {
    await _db
        .from('partner_accounts')
        .update({'status': 'rejected'})
        .eq('id', accountId);
  }

  Future<List<Map<String, dynamic>>> getAllPartnerAccounts() async {
    final data = await _db
        .from('partner_accounts')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Admin Users ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAdminUser(String authUserId) async {
    final data = await _db
        .from('admin_users')
        .select()
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    return data;
  }

  Future<void> touchAdminLastLogin(String adminId) async {
    try {
      await _db
          .from('admin_users')
          .update({'last_login_at': DateTime.now().toIso8601String()})
          .eq('id', adminId);
    } catch (_) {}
  }

  // ─── Auth ────────────────────────────────────────────────────────────

  Future<AuthResponse> signUp(String email, String password) async {
    return await _db.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _db.auth.signOut();
  }

  User? get currentUser => _db.auth.currentUser;
  bool get isAuthenticated => _db.auth.currentUser != null;
}
