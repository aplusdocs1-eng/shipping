import 'dart:typed_data';
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

  /// Best-effort suggestion for a new customer's mailbox_number — their
  /// unique forwarding-address ID (see idx_customers_mailbox_number_unique
  /// and getWarehouseAddress). [prefix] is normally the courier's own
  /// tracking_prefix (e.g. "HDS"), so the suggestion reads "HDS-1001" —
  /// falls back to "CUST" when no prefix is known (e.g. the admin-wide
  /// Customers screen, which isn't scoped to one courier).
  ///
  /// This is only ever a *suggestion* shown in an editable field — the
  /// real guarantee against two customers colliding is the database's
  /// unique index, checked at save time via isMailboxNumberConflict.
  Future<String> suggestNextMailboxNumber({String? prefix}) async {
    final p = ((prefix == null || prefix.trim().isEmpty)
            ? 'CUST'
            : prefix.trim())
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    var maxN = 1000;
    try {
      final data = await _db
          .from('customers')
          .select('mailbox_number')
          .ilike('mailbox_number', '$p-%');
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final mb = (row['mailbox_number'] as String?) ?? '';
        final m = RegExp(r'-(\d+)$').firstMatch(mb);
        final n = m == null ? null : int.tryParse(m.group(1)!);
        if (n != null && n > maxN) maxN = n;
      }
    } catch (_) {
      // Fall through with the base maxN — still just a suggestion, and
      // the unique index catches a real collision regardless.
    }
    return '$p-${maxN + 1}';
  }

  /// True when [e] is a save failure specifically because the mailbox
  /// number just submitted is already used by another customer — callers
  /// show "already in use, try another" instead of a raw database error.
  bool isMailboxNumberConflict(Object e) =>
      e is PostgrestException &&
      e.code == '23505' &&
      (e.message.contains('mailbox_number') ||
          (e.details?.toString().contains('mailbox_number') ?? false));

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

  /// The one physical warehouse address every customer's personalized
  /// "Shipping Addresses" page and every courier's dashboard reference —
  /// admin-editable (Settings → Warehouse Address). Lives in its own
  /// singleton table, NOT nested inside company_settings.settings: that
  /// table is admin-only-readable because it also holds integration API
  /// keys, and a customer or courier session needs to read this value.
  /// Same "admin write, authenticated read" RLS shape as scanner_settings
  /// — see 20260813030000_warehouse_settings.sql.
  static const Map<String, String> defaultWarehouseAddress = {
    'line1': '559 NE 42ND ST',
    'city': 'OAKLAND PARK',
    'state': 'Florida',
    'zip': '33334',
    'country': 'United States',
  };

  Future<Map<String, String>> getWarehouseAddress() async {
    try {
      final row = await _db.from('warehouse_settings').select().eq('id', true).single();
      return {
        for (final key in defaultWarehouseAddress.keys)
          key: (row[key] as String?)?.trim().isNotEmpty == true
              ? row[key] as String
              : defaultWarehouseAddress[key]!,
      };
    } catch (_) {
      return defaultWarehouseAddress;
    }
  }

  Future<void> updateWarehouseAddress(Map<String, String> address) async {
    // warehouse_settings.updated_by references admin_users(id), not
    // auth.users(id) — currentUser.id is the latter and would violate the
    // foreign key (same fix as updateScannerSettings).
    final adminId = await _currentAdminId();
    await _db
        .from('warehouse_settings')
        .update({
          'line1': address['line1'],
          'city': address['city'],
          'state': address['state'],
          'zip': address['zip'],
          'country': address['country'],
          'updated_at': DateTime.now().toIso8601String(),
          'updated_by': adminId,
        })
        .eq('id', true);
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

  // ─── Warehouse package scanning (barcode + OCR receiving) ─────────────

  /// Uploads a captured/uploaded label photo to the private package-labels
  /// bucket. Returns the storage path (not a URL — signed URLs expire, so
  /// callers mint a fresh one from this path via
  /// getPackageLabelSignedUrl whenever they actually need to display it).
  Future<String> uploadPackageLabel({
    required String warehouseEntryId,
    required Uint8List bytes,
  }) async {
    final path = '$warehouseEntryId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from('package-labels')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }

  /// Signed URLs are short-lived on purpose — label images contain a
  /// customer's name and address, so nothing about this bucket is public
  /// and nothing here should be linkable/cacheable long-term.
  Future<String> getPackageLabelSignedUrl(String path) async {
    return _db.storage.from('package-labels').createSignedUrl(path, 300);
  }

  /// The authoritative server-side half of a scan: duplicate check,
  /// server-side re-verification of any claimed auto-match, insert, and
  /// audit log — see supabase/functions/process-package-scan. Never
  /// trust a customer assignment that didn't come back through this.
  Future<Map<String, dynamic>> processPackageScan(Map<String, dynamic> payload) async {
    final res = await _db.functions.invoke('process-package-scan', body: payload);
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('process-package-scan returned an unexpected response');
  }

  /// Courier-facing scan OUT: marks a package picked up. Goes through the
  /// scan_out_package SECURITY DEFINER RPC rather than a direct
  /// warehouse_entries update — the RPC resolves the caller's own
  /// tracking_prefix server-side (never trusts a client-supplied partner
  /// id) and only ever touches the pickup fields, matching why
  /// process-package-scan is an Edge Function rather than a raw client
  /// insert. See 20260813010000_courier_scan_out.sql.
  ///
  /// Returns the RPC's JSON result as-is: {ok, error?} or
  /// {ok: true, already_picked_up, entry}. Callers branch on `ok` and
  /// `already_picked_up` rather than a thrown exception, since
  /// "not found" / "already picked up" are expected outcomes of normal
  /// scanning, not failures.
  Future<Map<String, dynamic>> scanOutPackage({
    required String code,
    String? pickedUpBy,
  }) async {
    final data = await _db.rpc(
      'scan_out_package',
      params: {'p_code': code, 'p_picked_up_by': pickedUpBy},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getScannerSettings() async {
    final data = await _db.from('scanner_settings').select().eq('id', true).single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateScannerSettings(Map<String, dynamic> updates) async {
    // scanner_settings.updated_by references admin_users(id), NOT
    // auth.users(id) — currentUser.id is the latter, which is a different
    // value and violates the foreign key. _currentAdminId() resolves the
    // right one (same helper the audit log uses).
    final adminId = await _currentAdminId();
    await _db
        .from('scanner_settings')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
          'updated_by': adminId,
        })
        .eq('id', true);
  }

  /// Unknown Packages queue: received but no confident customer match.
  /// Distinct from the older getUnknownPackagesByPrefix (partner-portal-
  /// scoped, customer_id IS NULL only) — this is the admin-wide queue,
  /// keyed on the richer match_status this feature adds.
  Future<List<Map<String, dynamic>>> getUnknownPackages() async {
    final data = await _db
        .from('warehouse_entries')
        .select()
        .eq('match_status', 'unknown')
        .order('scanned_in_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPackagesNeedingReview() async {
    final data = await _db
        .from('warehouse_entries')
        .select()
        .eq('match_status', 'needs_review')
        .order('scanned_in_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Assigns an Unknown/needs-review package to a customer after a staff
  /// member manually picks one — a routine authenticated admin update
  /// (protected by warehouse_entries' existing "Admins full access" RLS
  /// policy), not a claim that needs the Edge Function's anti-spoofing
  /// re-verification: the staff member is looking at the real label with
  /// their own eyes when they make this call.
  Future<void> assignPackageToCustomer({
    required String warehouseEntryId,
    required String customerId,
    required String customerName,
  }) async {
    final adminId = await _currentAdminId();
    await _db
        .from('warehouse_entries')
        .update({
          'customer_id': customerId,
          'customer_name': customerName,
          'match_status': 'matched',
          'match_score': 100,
          'match_reason': 'Manually matched by warehouse staff',
          'assigned_by': adminId,
          'assigned_at': DateTime.now().toIso8601String(),
        })
        .eq('id', warehouseEntryId);
    await insertPackageScanAuditLog(
      warehouseEntryId: warehouseEntryId,
      action: 'customer_assignment_changed',
      notes: 'Manually matched to $customerName',
    );
  }

  Future<void> rejectPackage({
    required String warehouseEntryId,
    required String reason,
  }) async {
    final adminId = await _currentAdminId();
    await _db
        .from('warehouse_entries')
        .update({
          'match_status': 'rejected',
          'rejected_at': DateTime.now().toIso8601String(),
          'rejected_by': adminId,
          'rejected_reason': reason,
        })
        .eq('id', warehouseEntryId);
    await insertPackageScanAuditLog(
      warehouseEntryId: warehouseEntryId,
      action: 'package_rejected',
      notes: reason,
    );
  }

  Future<void> updateWarehouseEntryFields(
    String warehouseEntryId,
    Map<String, dynamic> updates,
  ) async {
    await _db.from('warehouse_entries').update(updates).eq('id', warehouseEntryId);
    await insertPackageScanAuditLog(
      warehouseEntryId: warehouseEntryId,
      action: 'package_updated',
      notes: 'Fields corrected by staff: ${updates.keys.join(', ')}',
    );
  }

  Future<String?> _currentAdminId() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final row = await getAdminUser(uid);
    return row?['id'] as String?;
  }

  Future<void> insertPackageScanAuditLog({
    String? warehouseEntryId,
    required String action,
    String? notes,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    String performedByName = 'Unknown';
    String? performedById;
    final uid = currentUser?.id;
    if (uid != null) {
      final admin = await getAdminUser(uid);
      performedById = admin?['id'] as String?;
      performedByName = (admin?['full_name'] as String?) ?? currentUser?.email ?? 'Unknown';
    }
    await _db.from('package_scan_audit_log').insert({
      'warehouse_entry_id': warehouseEntryId,
      'action': action,
      'performed_by': performedById,
      'performed_by_name': performedByName,
      'notes': notes,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }

  Future<List<Map<String, dynamic>>> getPackageScanAuditLog(String warehouseEntryId) async {
    final data = await _db
        .from('package_scan_audit_log')
        .select()
        .eq('warehouse_entry_id', warehouseEntryId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Searches every field a warehouse employee might actually have in
  /// hand when looking for a package: tracking number, barcode, recipient
  /// name, postal code, order number, reference number. customer name/ID
  /// search happens client-side against the already-loaded customer list
  /// (see WarehouseScreen), same as the rest of this screen's search.
  Future<List<Map<String, dynamic>>> searchWarehouseEntries(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final data = await _db
        .from('warehouse_entries')
        .select()
        .or(
          'tracking_number.ilike.%$q%,barcode_value.ilike.%$q%,recipient_name.ilike.%$q%,'
          'postal_code.ilike.%$q%,order_number.ilike.%$q%,reference_number.ilike.%$q%',
        )
        .order('scanned_in_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Powers the admin dashboard's "Warehouse Receiving" stat block.
  Future<Map<String, int>> getReceivingStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();

    final results = await Future.wait([
      _db.from('warehouse_entries').select('id').gte('scanned_in_at', todayStart).count(),
      _db.from('warehouse_entries').select('id').gte('scanned_in_at', weekStart).count(),
      _db.from('warehouse_entries').select('id').eq('match_status', 'unknown').count(),
      _db.from('warehouse_entries').select('id').eq('match_status', 'needs_review').count(),
      _db
          .from('package_scan_audit_log')
          .select('id')
          .eq('action', 'duplicate_detected')
          .gte('created_at', todayStart)
          .count(),
    ]);

    return {
      'receivedToday': results[0].count,
      'receivedThisWeek': results[1].count,
      'unmatched': results[2].count,
      'needsReview': results[3].count,
      'duplicatesToday': results[4].count,
    };
  }
}
