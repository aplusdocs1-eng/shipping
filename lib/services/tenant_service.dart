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

  String? get partnerId => _partner?['id'] as String?;
  String? get companyName => _partner?['company_name'] as String?;
  String? get trackingPrefix => _partner?['tracking_prefix'] as String?;

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
    if (_host.isEmpty || _adminHosts.contains(_host)) {
      return;
    }
    try {
      final res = await Supabase.instance.client.rpc(
        'get_partner_by_domain',
        params: {'p_domain': _host},
      );
      if (res is List && res.isNotEmpty) {
        _partner = Map<String, dynamic>.from(res.first as Map);
      }
    } catch (_) {
      // If the RPC is unavailable, behave as admin host.
      _partner = null;
    }
  }
}
