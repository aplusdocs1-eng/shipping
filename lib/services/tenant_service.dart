import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves the current tenant (shipping partner) from the browser hostname.
///
/// Hosting model:
///   - Admin host (e.g. admin.yourdomain.com, or localhost during dev) shows
///     the admin/warehouse login.
///   - Any other hostname is looked up in `partner_accounts.domain`. If a row
///     is found and `status='approved'`, the app is scoped to that partner:
///     /#/partner-login and /#/customer-login both brand & sign in
///     for that partner only.
class TenantService {
  TenantService._();
  static final TenantService instance = TenantService._();
  factory TenantService() => instance;

  /// Hostnames that are always treated as the main admin site.
  /// Add your production admin hostname here.
  static const _adminHosts = <String>{
    'localhost',
    '127.0.0.1',
    'admin.applizonecentral.com',
    'onevillageshipping.com',
    'www.onevillageshipping.com',
    'studio-4294142763-3c3c9.web.app',
    'studio-4294142763-3c3c9.firebaseapp.com',
    'web-six-lyart-elpksgcatu.vercel.app',
    'web-shipping-90d17e8c.vercel.app',
    'web-aplusdocs1-6235-shipping-90d17e8c.vercel.app',
  };

  String _host = '';
  Map<String, dynamic>? _partner;
  bool _initialized = false;

  String get host => _host;
  bool get isInitialized => _initialized;

  /// True when the current host is the admin / main site.
  bool get isAdminHost =>
      _partner == null && (_adminHosts.contains(_host) || _host.isEmpty);

  /// Partner row for the current tenant, or null on the admin host or when
  /// the hostname does not match any approved partner.
  Map<String, dynamic>? get partner => _partner;

  /// One Village's own direct-tenant partner_accounts row — the fallback
  /// tenant for customers who sign up from the main site instead of a
  /// partner's own domain. See migration 20260805010000_direct_tenant.sql.
  static const directPartnerId = '00000000-0000-0000-0000-000000000001';
  static const _directCompanyName = 'One Village Shipping & Freight';
  static const _directTrackingPrefix = 'OVS-';

  String? get partnerId =>
      _partner?['id'] as String? ?? (isAdminHost ? directPartnerId : null);
  String? get companyName =>
      _partner?['company_name'] as String? ??
      (isAdminHost ? _directCompanyName : null);
  String? get trackingPrefix =>
      _partner?['tracking_prefix'] as String? ??
      (isAdminHost ? _directTrackingPrefix : null);

  /// Reads `Uri.base.host` (on web this is `window.location.hostname`) and
  /// queries Supabase for a matching partner. Silently falls back to admin
  /// behaviour if the lookup fails or there is no match.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _host = Uri.base.host.toLowerCase();
    } catch (_) {
      _host = '';
    }
    if (_host.isNotEmpty && !_adminHosts.contains(_host)) {
      try {
        final res = await Supabase.instance.client.rpc(
          'get_partner_by_domain',
          params: {'p_domain': _host},
        );
        if (res is List && res.isNotEmpty) {
          _partner = Map<String, dynamic>.from(res.first as Map);
          return;
        }
      } catch (_) {
        // Fall through to the code-based lookup below.
      }
    }
    // Fallback: a `?partner=CODE` query param scopes the app to a partner
    // on the shared/admin domain — lets a partner share a working
    // customer-facing link immediately, before (or instead of) setting up
    // a custom domain, which needs DNS access they may not have yet.
    final code = Uri.base.queryParameters['partner'];
    if (code == null || code.trim().isEmpty) return;
    try {
      final res = await Supabase.instance.client.rpc(
        'get_partner_by_code',
        params: {'p_code': code.trim()},
      );
      if (res is List && res.isNotEmpty) {
        _partner = Map<String, dynamic>.from(res.first as Map);
      }
    } catch (_) {
      _partner = null;
    }
  }
}
