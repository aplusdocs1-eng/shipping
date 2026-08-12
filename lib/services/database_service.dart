import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Service for all Supabase database operations.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  SupabaseClient get _db => SupabaseConfig.client;

  /// Retries an action that references a just-created auth user by id.
  /// Immediately after `auth.signUp()`, the new row in `auth.users` can
  /// occasionally not yet be visible to a following query on a different
  /// connection (observed as a foreign-key violation on auth_user_id) —
  /// this is a brief replication/visibility race, not a real error, so a
  /// short retry resolves it instead of failing the sign-up outright.
  Future<T> _retryOnAuthRace<T>(Future<T> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await action();
      } on PostgrestException catch (e) {
        final isAuthRace =
            e.code == '23503' &&
            (e.message.contains('auth_user_id') ||
                (e.details?.toString().contains('table "users"') ?? false));
        if (!isAuthRace || attempt >= 3) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }

  // ─── Warehouse Entries ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWarehouseEntries() async {
    final data = await _db
        .from('warehouse_entries')
        .select()
        .order('scanned_in_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Warehouse entries whose tracking number starts with [prefix] (e.g.
  /// "HDS-") — how a partner tenant's own received packages are scoped,
  /// since warehouse_entries has no partner_id column of its own (it only
  /// tracks shipping_partner_code, which identifies the external courier
  /// that delivered a package to our warehouse, not which tenant it
  /// belongs to).
  Future<List<Map<String, dynamic>>> getWarehouseEntriesByPrefix(
    String prefix,
  ) async {
    final data = await _db
        .from('warehouse_entries')
        .select()
        .ilike('tracking_number', '$prefix%')
        .order('scanned_in_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertWarehouseEntry({
    required String trackingNumber,
    required String customerName,
    String? customerId,
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
      'customer_id': customerId,
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

  Future<Map<String, dynamic>> updateCustomer(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _db
        .from('customers')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Self-serve customer sign-up, scoped to the partner whose domain the
  /// customer registered on. Goes through a SECURITY DEFINER RPC because
  /// a brand-new customer has no row yet to satisfy the RLS insert check.
  Future<Map<String, dynamic>> insertCustomerAccount({
    required String authUserId,
    required String partnerId,
    required String name,
    required String email,
    String? phone,
  }) async {
    final data = await _retryOnAuthRace(
      () => _db.rpc(
        'create_customer_account',
        params: {
          'p_auth_user_id': authUserId,
          'p_partner_id': partnerId,
          'p_name': name,
          'p_email': email,
          'p_phone': phone,
        },
      ),
    );
    final list = List<Map<String, dynamic>>.from(data as List);
    return list.first;
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

  Future<Map<String, dynamic>> insertShipment(
    Map<String, dynamic> row,
  ) async {
    final data = await _db.from('shipments').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateShipment(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _db
        .from('shipments')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  // ─── Staff ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStaff() async {
    final data = await _db
        .from('staff')
        .select('*, branches(name)')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertStaff(Map<String, dynamic> row) async {
    final data = await _db.from('staff').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateStaff(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _db
        .from('staff')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  // ─── Branches ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBranches() async {
    final data = await _db
        .from('branches')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertBranch(Map<String, dynamic> row) async {
    final data = await _db.from('branches').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateBranch(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _db
        .from('branches')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  // ─── Storage Zones & Locations ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStorageZones() async {
    final data = await _db
        .from('storage_zones')
        .select()
        .order('code', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getStorageLocations() async {
    final data = await _db
        .from('storage_locations')
        .select('*, storage_zones(code, name)')
        .order('label', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> setStorageLocationOccupied(String id, bool occupied) async {
    await _db
        .from('storage_locations')
        .update({'is_occupied': occupied})
        .eq('id', id);
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

  Future<Map<String, dynamic>> insertPreAlert(
    Map<String, dynamic> row,
  ) async {
    final data = await _db.from('pre_alerts').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updatePreAlert(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _db
        .from('pre_alerts')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
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

  /// A POS "quick sale" not tied to any existing package — e.g. a walk-in
  /// charge for packing materials, a same-day local delivery, etc.
  Future<Map<String, dynamic>> insertQuickSaleInvoice({
    required String customerId,
    required String customerName,
    required String description,
    required double amount,
    double taxRate = 0,
    String? partnerId,
  }) async {
    final tax = amount * taxRate;
    final total = amount + tax;
    final invNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final row = <String, dynamic>{
      'invoice_number': invNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'amount': amount,
      'tax': tax,
      'total': total,
      'status': 'pending',
      'invoice_type': 'customer_billing',
      'notes': description,
      if (partnerId != null) 'partner_id': partnerId,
    };
    final data = await _db.from('invoices').insert(row).select().single();
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

  // ─── Payment Submissions ─────────────────────────────────────────────
  // Customers can't mark their own invoice paid — they submit a payment
  // method + reference for staff to confirm, which then calls
  // markInvoicePaid.

  Future<Map<String, dynamic>> submitPaymentReference({
    required String invoiceId,
    required String customerId,
    String? partnerId,
    required String method,
    String? reference,
    String? notes,
    double? amount,
  }) async {
    final row = <String, dynamic>{
      'invoice_id': invoiceId,
      'customer_id': customerId,
      'partner_id': partnerId,
      'method': method,
      'reference': reference,
      'notes': notes,
      'amount': amount,
      'status': 'pending_review',
    };
    final data = await _db
        .from('payment_submissions')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPaymentSubmissionsByCustomer(
    String customerId,
  ) async {
    final data = await _db
        .from('payment_submissions')
        .select()
        .eq('customer_id', customerId)
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPaymentSubmissionsForInvoice(
    String invoiceId,
  ) async {
    final data = await _db
        .from('payment_submissions')
        .select()
        .eq('invoice_id', invoiceId)
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Every payment submission platform-wide — the admin Accounting
  /// screen's review queue and transaction ledger, not scoped to one
  /// customer/invoice/partner the way the other getters here are.
  Future<List<Map<String, dynamic>>> getAllPaymentSubmissions() async {
    final data = await _db
        .from('payment_submissions')
        .select()
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPendingPaymentSubmissionsByPartner(
    String partnerId,
  ) async {
    final data = await _db
        .from('payment_submissions')
        .select()
        .eq('partner_id', partnerId)
        .eq('status', 'pending_review')
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Confirms a customer's payment submission and marks the linked
  /// invoice paid.
  Future<void> confirmPaymentSubmission(
    String submissionId,
    String invoiceId,
  ) async {
    await _db
        .from('payment_submissions')
        .update({
          'status': 'confirmed',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', submissionId);
    await markInvoicePaid(invoiceId);
  }

  Future<void> rejectPaymentSubmission(String submissionId) async {
    await _db
        .from('payment_submissions')
        .update({
          'status': 'rejected',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', submissionId);
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
    String? plan,
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
        'p_plan': plan,
      },
    );
    final list = List<Map<String, dynamic>>.from(data as List);
    return list.first;
  }

  /// Registers the partner's domain with Vercel via the
  /// provision-partner-domain Edge Function. Returns the DNS
  /// instructions to show the partner.
  Future<Map<String, dynamic>> provisionPartnerDomain({
    required String domain,
    required String partnerAccountId,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'provision-partner-domain',
        body: {'domain': domain, 'partnerAccountId': partnerAccountId},
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map ? details['error']?.toString() : null;
      throw msg ?? 'Domain provisioning failed (${e.status}).';
    }
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

  // ─── Partner Settings (Settings screen) ───────────────────────────────
  // Simple scalar preferences (Storage Fee, Terms, Currency, Rate
  // Calculator, Branding, Api/Webhooks tabs) live in one JSONB bag on the
  // account row; list-shaped sections get their own small tables below.

  /// Merges [patch] into the account's existing settings JSONB (a plain
  /// `.update()` would overwrite the whole column, wiping unrelated keys
  /// set by other tabs) and returns the updated account row.
  Future<Map<String, dynamic>> updatePartnerSettings(
    String accountId,
    Map<String, dynamic> patch,
  ) async {
    final current = await _db
        .from('partner_accounts')
        .select('settings')
        .eq('id', accountId)
        .single();
    final merged = <String, dynamic>{
      ...Map<String, dynamic>.from(current['settings'] as Map? ?? {}),
      ...patch,
    };
    final data = await _db
        .from('partner_accounts')
        .update({'settings': merged})
        .eq('id', accountId)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPartnerLocations(
    String partnerId,
  ) async {
    final data = await _db
        .from('partner_locations')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerLocation(
    Map<String, dynamic> row,
  ) async {
    final data = await _db
        .from('partner_locations')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> deletePartnerLocation(String id) async {
    await _db.from('partner_locations').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getPartnerCharges(
    String partnerId,
  ) async {
    final data = await _db
        .from('partner_charges')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerCharge(
    Map<String, dynamic> row,
  ) async {
    final data = await _db
        .from('partner_charges')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePartnerCharge(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('partner_charges').update(updates).eq('id', id);
  }

  Future<void> deletePartnerCharge(String id) async {
    await _db.from('partner_charges').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getPartnerDiscounts(
    String partnerId,
  ) async {
    final data = await _db
        .from('partner_discounts')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerDiscount(
    Map<String, dynamic> row,
  ) async {
    final data = await _db
        .from('partner_discounts')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePartnerDiscount(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('partner_discounts').update(updates).eq('id', id);
  }

  Future<void> deletePartnerDiscount(String id) async {
    await _db.from('partner_discounts').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getPartnerRoles(String partnerId) async {
    final data = await _db
        .from('partner_roles')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerRole(
    Map<String, dynamic> row,
  ) async {
    final data = await _db.from('partner_roles').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePartnerRole(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('partner_roles').update(updates).eq('id', id);
  }

  Future<void> deletePartnerRole(String id) async {
    await _db.from('partner_roles').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getPartnerStaff(String partnerId) async {
    final data = await _db
        .from('partner_staff')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerStaff(
    Map<String, dynamic> row,
  ) async {
    final data = await _db.from('partner_staff').insert(row).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> deletePartnerStaff(String id) async {
    await _db.from('partner_staff').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getPartnerShippingAddresses(
    String partnerId,
  ) async {
    final data = await _db
        .from('partner_shipping_addresses')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerShippingAddress(
    Map<String, dynamic> row,
  ) async {
    final data = await _db
        .from('partner_shipping_addresses')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePartnerShippingAddress(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('partner_shipping_addresses').update(updates).eq('id', id);
  }

  Future<void> deletePartnerShippingAddress(String id) async {
    await _db.from('partner_shipping_addresses').delete().eq('id', id);
  }

  // ─── Broadcasts / Referrals / Support Tickets ─────────────────────────

  Future<List<Map<String, dynamic>>> getPartnerBroadcasts(
    String partnerId,
  ) async {
    final data = await _db
        .from('partner_broadcasts')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerBroadcast(
    Map<String, dynamic> row,
  ) async {
    final data = await _db
        .from('partner_broadcasts')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPartnerReferrals(
    String partnerId,
  ) async {
    final data = await _db
        .from('partner_referrals')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerReferral(
    Map<String, dynamic> row,
  ) async {
    final data = await _db
        .from('partner_referrals')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPartnerSupportTickets(
    String partnerId,
  ) async {
    final data = await _db
        .from('partner_support_tickets')
        .select()
        .eq('partner_id', partnerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPartnerSupportTicket(
    Map<String, dynamic> row,
  ) async {
    final data = await _db
        .from('partner_support_tickets')
        .insert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Warehouse entries matching this partner's tracking prefix that never
  /// got matched to one of their customers — i.e. genuinely unidentified
  /// packages, not a hardcoded "all clear" claim.
  Future<List<Map<String, dynamic>>> getUnknownPackagesByPrefix(
    String prefix,
  ) async {
    final data = await _db
        .from('warehouse_entries')
        .select()
        .ilike('tracking_number', '$prefix%')
        .isFilter('customer_id', null)
        .order('scanned_in_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─── Vendor API (admin Settings "API for 3rd Party Vendors") ─────────
  // Backs the real vendor-api Edge Function — see supabase/functions/vendor-api.

  Future<Map<String, dynamic>?> getVendorApiKey() async {
    final data = await _db
        .from('vendor_api_keys')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  /// Creates the key if [existingId] is null, otherwise rotates the
  /// existing row's key in place (old value stops working immediately).
  Future<Map<String, dynamic>> regenerateVendorApiKey({
    String? existingId,
    required String newKey,
  }) async {
    if (existingId != null) {
      final data = await _db
          .from('vendor_api_keys')
          .update({'key': newKey})
          .eq('id', existingId)
          .select()
          .single();
      return Map<String, dynamic>.from(data);
    }
    final data = await _db
        .from('vendor_api_keys')
        .insert({'key': newKey})
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> setVendorApiKeySandbox(String id, bool sandbox) async {
    await _db.from('vendor_api_keys').update({'sandbox': sandbox}).eq('id', id);
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

  // ─── Site Content (public landing page editor) ──────────────────────

  /// Raw admin-saved overrides for the landing page, or null if nothing
  /// has ever been saved (or the row/table isn't reachable) — callers
  /// merge this over `LandingContent.defaults` so the page always renders
  /// something correct even with no overrides at all.
  Future<Map<String, dynamic>?> getSiteContent(String pageId) async {
    try {
      final data = await _db
          .from('site_content')
          .select('content')
          .eq('id', pageId)
          .maybeSingle();
      final content = data?['content'];
      return content is Map<String, dynamic> ? content : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateSiteContent(String pageId, Map<String, dynamic> content) async {
    await _db.from('site_content').upsert({
      'id': pageId,
      'content': content,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': currentUser?.id,
    });
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

  /// The full admin roster — name, email, role, last login. Used by the
  /// Settings screen's Security section in place of a fictional "audit
  /// log" (this app doesn't track per-action history; this is the real
  /// data that does exist).
  Future<List<Map<String, dynamic>>> getAllAdminUsers() async {
    final data = await _db
        .from('admin_users')
        .select()
        .order('last_login_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Changes the password of the *currently signed-in* user — Supabase
  /// Auth only supports updating your own credentials this way (there is
  /// no "change someone else's password" client call, by design).
  Future<void> updateOwnPassword(String newPassword) async {
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ─── Company Settings (admin Settings screen) ───────────────────────

  Future<Map<String, dynamic>?> getCompanySettings() async {
    try {
      final data = await _db
          .from('company_settings')
          .select('settings')
          .eq('id', 'default')
          .maybeSingle();
      final settings = data?['settings'];
      return settings is Map<String, dynamic> ? settings : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateCompanySettings(Map<String, dynamic> settings) async {
    await _db.from('company_settings').upsert({
      'id': 'default',
      'settings': settings,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': currentUser?.id,
    });
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

  // ─── Point of Sale ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPosItems() async {
    final data = await _db
        .from('pos_items')
        .select()
        .order('category', ascending: true)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> insertPosItem(
    Map<String, dynamic> item,
  ) async {
    final data = await _db.from('pos_items').insert(item).select().single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePosItem(String id, Map<String, dynamic> updates) async {
    await _db.from('pos_items').update(updates).eq('id', id);
  }

  Future<void> deletePosItem(String id) async {
    await _db.from('pos_items').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getPosTransactions() async {
    final data = await _db
        .from('pos_transactions')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Inserts the transaction row, then its line items (linked by the new
  /// transaction's id). The line items keep their own copy of name/price
  /// at time of sale — a historical receipt shouldn't change retroactively
  /// just because a catalog item's price was edited later.
  Future<Map<String, dynamic>> insertPosTransaction({
    required String receiptNumber,
    String? customerId,
    required String customerName,
    required double subtotal,
    required double tax,
    required double total,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) async {
    final txn = await _db
        .from('pos_transactions')
        .insert({
          'receipt_number': receiptNumber,
          'customer_id': customerId,
          'customer_name': customerName,
          'subtotal': subtotal,
          'tax': tax,
          'total': total,
          'payment_method': paymentMethod,
        })
        .select()
        .single();
    final txnId = txn['id'] as String;
    if (items.isNotEmpty) {
      await _db.from('pos_transaction_items').insert([
        for (final i in items) {...i, 'transaction_id': txnId},
      ]);
    }
    return Map<String, dynamic>.from(txn);
  }

  // ─── Payroll ─────────────────────────────────────────────────────────
  // Record-keeping only — there's no payment integration behind this
  // (see the migration's own comment). "Mark Paid" records that a
  // transfer happened; it doesn't send one.

  Future<List<Map<String, dynamic>>> getPayrollRuns() async {
    final data = await _db
        .from('payroll_runs')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPayrollEntries(String runId) async {
    final data = await _db
        .from('payroll_entries')
        .select()
        .eq('payroll_run_id', runId)
        .order('staff_name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> createPayrollRun({
    required String periodLabel,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<Map<String, dynamic>> entries,
  }) async {
    double total = 0;
    for (final e in entries) {
      total += (e['amount'] as num?)?.toDouble() ?? 0.0;
    }
    final run = await _db
        .from('payroll_runs')
        .insert({
          'period_label': periodLabel,
          'period_start': periodStart.toIso8601String().split('T').first,
          'period_end': periodEnd.toIso8601String().split('T').first,
          'total_amount': total,
        })
        .select()
        .single();
    final runId = run['id'] as String;
    if (entries.isNotEmpty) {
      await _db.from('payroll_entries').insert([
        for (final e in entries) {...e, 'payroll_run_id': runId},
      ]);
    }
    return Map<String, dynamic>.from(run);
  }

  Future<void> markPayrollEntryPaid(
    String entryId, {
    required String paymentMethod,
    String? reference,
  }) async {
    await _db
        .from('payroll_entries')
        .update({
          'status': 'paid',
          'payment_method': paymentMethod,
          'reference': reference,
          'paid_at': DateTime.now().toIso8601String(),
        })
        .eq('id', entryId);
  }

  Future<void> markPayrollRunPaid(String runId) async {
    await _db
        .from('payroll_runs')
        .update({'status': 'paid', 'paid_at': DateTime.now().toIso8601String()})
        .eq('id', runId);
  }

  Future<void> deletePayrollRun(String runId) async {
    // payroll_entries cascades via ON DELETE CASCADE.
    await _db.from('payroll_runs').delete().eq('id', runId);
  }
}
