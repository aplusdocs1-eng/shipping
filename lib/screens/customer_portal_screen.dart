import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/tenant_service.dart';
import '../theme/app_theme.dart';
import 'landing_screen.dart' show LandingScreen;

/// Customer Portal — mirrors applizonecentralja.com/customer
///
/// Sections: Overview, Shipping Addresses, Pre-Alerts, Refer & Earn,
/// Rate Calculator, Mobile App, Settings.
class CustomerPortalScreen extends StatefulWidget {
  const CustomerPortalScreen({super.key});

  @override
  State<CustomerPortalScreen> createState() => _CustomerPortalScreenState();
}

class _CustomerPortalScreenState extends State<CustomerPortalScreen> {
  final _db = DatabaseService();
  int _current = 0;
  bool _loading = true;
  bool _silentRefresh = false;
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _packages = const [];
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _preAlerts = const [];
  List<Map<String, dynamic>> _paymentSubmissions = const [];
  Map<String, String> _warehouseAddress = DatabaseService.defaultWarehouseAddress;
  String? _loadError;
  RealtimeChannel? _channel;

  static const List<_NavItem> _nav = [
    _NavItem('Overview', Icons.dashboard_outlined, '/customer'),
    _NavItem('Invoices', Icons.receipt_long_outlined, '/customer/invoices'),
    _NavItem(
      'Shipping Addresses',
      Icons.location_on_outlined,
      '/customer/shipping-addresses',
    ),
    _NavItem('Pre-Alerts', Icons.notifications_outlined, '/customer/prealerts'),
    _NavItem('Refer & Earn', Icons.card_giftcard, '/customer/referrals'),
    _NavItem(
      'Rate Calculator',
      Icons.calculate_outlined,
      '/customer/rate-calculator',
    ),
    _NavItem('Mobile App', Icons.phone_iphone, '/customer/mobile-app'),
    _NavItem('Settings', Icons.settings_outlined, '/customer/settings'),
  ];

  @override
  void initState() {
    super.initState();
    _load().then((_) => _subscribe());
    unawaited(_loadWarehouseAddress());
  }

  /// Not customer-specific, so it's loaded independently of _load() —
  /// a failure here shouldn't block the rest of the portal, and it
  /// doesn't need to block on knowing who the customer is first.
  Future<void> _loadWarehouseAddress() async {
    try {
      final address = await _db.getWarehouseAddress();
      if (mounted) setState(() => _warehouseAddress = address);
    } catch (_) {
      // Leave the built-in default in place.
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribe() {
    final custId = _customer?['id']?.toString();
    if (custId == null) return;
    final client = Supabase.instance.client;
    _channel = client
        .channel('customer-portal-$custId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'packages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: custId,
          ),
          callback: (_) {
            if (mounted) _silentLoad();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invoices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: custId,
          ),
          callback: (_) {
            if (mounted) _silentLoad();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pre_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: custId,
          ),
          callback: (_) {
            if (mounted) _silentLoad();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payment_submissions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: custId,
          ),
          callback: (_) {
            if (mounted) _silentLoad();
          },
        )
        .subscribe();
  }

  /// Refresh data without showing full-screen spinner.
  Future<void> _silentLoad() async {
    if (_customer == null) return;
    setState(() => _silentRefresh = true);
    final custId = _customer!['id'].toString();
    try {
      final results = await Future.wait([
        _db.getPackagesByCustomer(custId),
        _db.getInvoicesForCustomer(custId),
        _db.getPreAlertsByCustomer(custId),
        _db.getPaymentSubmissionsByCustomer(custId),
      ]);
      if (mounted) {
        setState(() {
          _packages = results[0];
          _invoices = results[1];
          _preAlerts = results[2];
          _paymentSubmissions = results[3];
          _silentRefresh = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _silentRefresh = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final email = _db.currentUser?.email;
      debugPrint(
        '[CustomerPortal] _load: email=$email partnerId=${TenantService().partnerId}',
      );
      if (email == null) {
        throw 'Not signed in.';
      }
      final partnerId = TenantService().partnerId;
      final cust = await _db.getCustomerByEmail(email, partnerId: partnerId);
      debugPrint('[CustomerPortal] cust=${cust?['id']} / ${cust?['name']}');
      if (cust == null) {
        // This auth session has no matching customers row — it isn't a
        // customer account at all (an admin or courier's own session in
        // the same browser, still valid from another tab; a stray
        // account; anything). This route is reachable directly by URL
        // regardless of how sign-in happened, so this check — not just
        // the one in customer_login_screen.dart — is the real boundary.
        // Previously this fabricated a synthetic customer instead of
        // rejecting, with mailbox_number hardcoded to the same "—"
        // placeholder the original broken-address bug (874c30c) was
        // named for — so any non-customer account landing here saw
        // that exact "—_AIR" address again. Never paper over it: sign
        // out and send them back to a real customer login.
        await _db.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/customer-login');
        }
        // Deliberately leave _loading as-is rather than flipping it off:
        // this widget is being replaced, and a late setState here (a
        // finally block previously did this unconditionally) would
        // rebuild _buildBody() with _customer still null and crash on
        // its `_customer!` — caught live via the null-check exception
        // this produced before switching to explicit per-branch
        // setState calls instead of a blanket finally.
        return;
      } else if ((cust['status']?.toString() ?? 'active') == 'inactive') {
        // A row existing only proves this really is a customer — not
        // that staff haven't since deactivated them (see
        // approveCustomerDeletion in database_service.dart). Same
        // "anything but literally 'inactive' counts as active" rule
        // Customer.isActive uses, and the same reject-don't-render
        // shape as the cust == null branch above, for the same reason:
        // this is the boundary that's actually reachable, regardless
        // of whether customer_login_screen.dart's own check ran first.
        await _db.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/customer-login');
        }
        return;
      } else {
        _customer = cust;
        final custId = cust['id'].toString();
        final results = await Future.wait([
          _db.getPackagesByCustomer(custId),
          _db.getInvoicesForCustomer(custId),
          _db.getPreAlertsByCustomer(custId),
          _db.getPaymentSubmissionsByCustomer(custId),
        ]);
        _packages = results[0];
        _invoices = results[1];
        _preAlerts = results[2];
        _paymentSubmissions = results[3];
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _db.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/customer-login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandingScreen.iceGray,
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              current: _current,
              nav: _nav,
              customer: _customer,
              onSelect: (i) => setState(() => _current = i),
              onLogout: _logout,
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(label: _nav[_current].label),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _loadError != null
                        ? _ErrorView(error: _loadError!, onRetry: _load)
                        : _buildBody(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_nav[_current].label) {
      case 'Overview':
        return _OverviewPage(
          customer: _customer!,
          packages: _packages,
          invoices: _invoices,
          onNavigate: (label) {
            final i = _nav.indexWhere((n) => n.label == label);
            if (i >= 0) setState(() => _current = i);
          },
        );
      case 'Invoices':
        return _InvoicesPage(
          customer: _customer!,
          invoices: _invoices,
          paymentSubmissions: _paymentSubmissions,
          onSubmitted: _silentLoad,
        );
      case 'Shipping Addresses':
        return _ShippingAddressesPage(
          customer: _customer!,
          warehouseAddress: _warehouseAddress,
        );
      case 'Pre-Alerts':
        return _PreAlertsPage(
          preAlerts: _preAlerts,
          customer: _customer!,
          onCreated: _silentLoad,
        );
      case 'Refer & Earn':
        return _ReferEarnPage(customer: _customer!);
      case 'Rate Calculator':
        return const _RateCalculatorPage();
      case 'Mobile App':
        return const _MobileAppPage();
      case 'Settings':
        return _SettingsPage(
          customer: _customer!,
          onLogout: _logout,
          onProfileUpdated: (updated) => setState(() => _customer = updated),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═════ Sidebar ══════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: AppTheme.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String path;
  const _NavItem(this.label, this.icon, this.path);
}

class _Sidebar extends StatelessWidget {
  final int current;
  final List<_NavItem> nav;
  final Map<String, dynamic>? customer;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.current,
    required this.nav,
    required this.customer,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: LandingScreen.navy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/one_village_logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_shipping_outlined,
                      color: LandingScreen.navy,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TenantService().companyName ?? 'One Village Shipping & Freight',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Text(
              'CUSTOMER PORTAL',
              style: TextStyle(
                fontSize: 10,
                color: LandingScreen.gold,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: nav.length,
              itemBuilder: (_, i) {
                final item = nav[i];
                final selected = i == current;
                return InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? const Border(left: BorderSide(color: LandingScreen.yellow, width: 3))
                          : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: selected
                              ? LandingScreen.yellow
                              : const Color(0xFFA9B8CC),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFC7D2E0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          InkWell(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Support'),
                content: const Text(
                  'Need help with a shipment or your account?\n\n'
                  'Phone: 267-844-5155\n'
                  'Email: shipping@onevillageshipping.com',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.help_outline, size: 18, color: Color(0xFFA9B8CC)),
                  SizedBox(width: 10),
                  Text(
                    'Support',
                    style: TextStyle(fontSize: 13, color: Color(0xFFC7D2E0), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onLogout,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LandingScreen.secondaryNavy.withValues(alpha: 0.4),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: LandingScreen.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initials(customer?['name'] as String? ?? '—'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: LandingScreen.navy,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (customer?['name'] as String?) ?? 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          (customer?['email'] as String?) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFA9B8CC),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.logout,
                    size: 16,
                    color: Color(0xFFA9B8CC),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _TopBar extends StatelessWidget {
  final String label;
  const _TopBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: LandingScreen.borderGray)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 12),
          const Text(
            'Customer Portal',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Text('  /  ', style: TextStyle(color: Color(0xFFD1D5DB))),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: LandingScreen.navy,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════ Overview ═════════════════════════════════════════════════════════

class _OverviewPage extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> packages;
  final List<Map<String, dynamic>> invoices;
  final ValueChanged<String> onNavigate;

  const _OverviewPage({
    required this.customer,
    required this.packages,
    required this.invoices,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = ((customer['name'] as String?) ?? 'Customer')
        .split(' ')
        .first;
    final balanceDue = invoices
        .where((i) => (i['status']?.toString() ?? '') != 'paid')
        .fold<num>(0, (s, i) => s + ((i['total'] as num?) ?? 0));
    final readyForPickup = packages
        .where((p) => (p['status']?.toString() ?? '') == 'ready_for_pickup')
        .length;
    final mailbox = (customer['mailbox_number'] as String?) ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [LandingScreen.navy, LandingScreen.secondaryNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back, $firstName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Here's what's happening with your packages today.",
                      style: TextStyle(color: Color(0xFFC7D2E0)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onNavigate('Pre-Alerts'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.notifications_outlined, size: 16),
                      label: const Text('Pre-Alerts'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => onNavigate('Shipping Addresses'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LandingScreen.yellow,
                        foregroundColor: LandingScreen.navy,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.location_on_outlined, size: 16),
                      label: const Text('Address'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _StatGrid(
            tiles: [
              _StatTileData(
                title: 'Balance Due',
                value: '\$${balanceDue.toStringAsFixed(2)}',
                sub: 'JMD · All open invoices',
                icon: Icons.receipt_long_outlined,
                tint: const Color(0xFFB83A3A).withValues(alpha: 0.10),
                iconColor: const Color(0xFFB83A3A),
              ),
              _StatTileData(
                title: 'Credit Balance',
                value: '\$0.00',
                sub: 'Available for future payments',
                icon: Icons.account_balance_wallet_outlined,
                tint: const Color(0xFF16845B).withValues(alpha: 0.10),
                iconColor: const Color(0xFF16845B),
              ),
              _StatTileData(
                title: 'Account Number',
                value: mailbox,
                sub: 'Your unique identifier',
                icon: Icons.badge_outlined,
                tint: LandingScreen.secondaryNavy.withValues(alpha: 0.10),
                iconColor: LandingScreen.secondaryNavy,
              ),
              _StatTileData(
                title: 'Ready for Pickup',
                value: '$readyForPickup',
                sub: 'Packages available',
                icon: Icons.inventory_2_outlined,
                tint: LandingScreen.gold.withValues(alpha: 0.14),
                iconColor: const Color(0xFFB8860B),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Packages',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: LandingScreen.navy,
            ),
          ),
          const SizedBox(height: 12),
          _PackagesTable(packages: packages),
        ],
      ),
    );
  }
}

class _StatTileData {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  _StatTileData({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });
}

class _StatGrid extends StatelessWidget {
  final List<_StatTileData> tiles;
  const _StatGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        int cols = 4;
        if (w < 1100) cols = 2;
        if (w < 600) cols = 1;
        final tileW = (w - (cols - 1) * 16) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final t in tiles)
              SizedBox(
                width: tileW,
                child: _StatTile(data: t),
              ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LandingScreen.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: data.tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, size: 18, color: data.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.sub,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _PackagesTable extends StatelessWidget {
  final List<Map<String, dynamic>> packages;
  const _PackagesTable({required this.packages});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LandingScreen.borderGray),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(LandingScreen.iceGray),
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: LandingScreen.navy,
          ),
          columns: const [
            DataColumn(label: Text('Tracking')),
            DataColumn(label: Text('Courier')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Weight')),
            DataColumn(label: Text('Value')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Invoice')),
            DataColumn(label: Text('Inv #')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Created')),
          ],
          rows: packages.isEmpty
              ? [
                  const DataRow(
                    cells: [
                      DataCell(Text('—')),
                      DataCell(Text('No packages yet')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                    ],
                  ),
                ]
              : [for (final p in packages) _buildRow(p)],
        ),
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> p) {
    final inv = p['invoices'] as Map<String, dynamic>?;
    final invStatus = inv?['status']?.toString() ?? '';
    final invTotal = (inv?['total'] as num?)?.toStringAsFixed(2) ?? '—';
    final invNumber = inv?['invoice_number']?.toString() ?? '—';
    return DataRow(
      cells: [
        DataCell(
          Text(
            p['tracking_number']?.toString() ?? '—',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(p['service_type']?.toString() ?? '—')),
        DataCell(Text(p['description']?.toString() ?? '')),
        DataCell(Text(p['weight'] == null ? '—' : '${p['weight']} lb')),
        DataCell(
          Text(
            '\$${(p['declared_value'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
        ),
        DataCell(_StatusPill(p['status']?.toString() ?? '')),
        DataCell(
          invStatus.isEmpty ? const Text('—') : _InvStatusBadge(invStatus),
        ),
        DataCell(Text(invNumber, style: const TextStyle(fontSize: 11))),
        DataCell(Text(invTotal.isNotEmpty ? '\$$invTotal' : '—')),
        DataCell(Text(_fmtDate(p['created_at']))),
      ],
    );
  }
}

class _InvStatusBadge extends StatelessWidget {
  final String status;
  const _InvStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final isPaid = status.toLowerCase() == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isPaid ? 'PAID' : 'PENDING',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB45309),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'delivered' ||
      'Delivered' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      'received' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'ready_for_pickup' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF374151)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _fmtDate(dynamic v) {
  if (v == null) return '—';
  try {
    final d = DateTime.parse(v.toString()).toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return v.toString();
  }
}

// ═════ Invoices ═════════════════════════════════════════════════════════

class _InvoicesPage extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> paymentSubmissions;
  final VoidCallback onSubmitted;

  const _InvoicesPage({
    required this.customer,
    required this.invoices,
    required this.paymentSubmissions,
    required this.onSubmitted,
  });

  Map<String, dynamic>? _pendingSubmissionFor(String invoiceId) {
    for (final s in paymentSubmissions) {
      if (s['invoice_id']?.toString() == invoiceId &&
          s['status'] == 'pending_review') {
        return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...invoices]..sort((a, b) {
      final aPaid = (a['status']?.toString() ?? '') == 'paid';
      final bPaid = (b['status']?.toString() ?? '') == 'paid';
      if (aPaid != bPaid) return aPaid ? 1 : -1;
      final aDate = a['created_at']?.toString() ?? '';
      final bDate = b['created_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoices',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'View and pay your invoices',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (sorted.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No invoices yet.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...sorted.map(
              (inv) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InvoiceCard(
                  invoice: inv,
                  pendingSubmission: _pendingSubmissionFor(
                    inv['id'].toString(),
                  ),
                  customer: customer,
                  onSubmitted: onSubmitted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final Map<String, dynamic>? pendingSubmission;
  final Map<String, dynamic> customer;
  final VoidCallback onSubmitted;

  const _InvoiceCard({
    required this.invoice,
    required this.pendingSubmission,
    required this.customer,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final status = invoice['status']?.toString() ?? 'pending';
    final isPaid = status == 'paid';
    final total = (invoice['total'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final invNumber = invoice['invoice_number']?.toString() ?? '—';
    final dueDate = invoice['due_date'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      invNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isPaid)
                      const _Badge(
                        'PAID',
                        Color(0xFFDCFCE7),
                        Color(0xFF15803D),
                      )
                    else if (pendingSubmission != null)
                      const _Badge(
                        'PENDING REVIEW',
                        Color(0xFFFEF3C7),
                        Color(0xFFB45309),
                      )
                    else
                      const _Badge(
                        'UNPAID',
                        Color(0xFFFEE2E2),
                        Color(0xFFDC2626),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dueDate == null ? 'No due date' : 'Due ${_fmtDate(dueDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$$total',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 16),
          if (!isPaid)
            ElevatedButton(
              onPressed: pendingSubmission != null
                  ? null
                  : () => _showPayDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                pendingSubmission != null ? 'Submitted' : 'Pay Invoice',
              ),
            ),
        ],
      ),
    );
  }

  void _showPayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PayInvoiceDialog(
        invoice: invoice,
        customer: customer,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _PayInvoiceDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final Map<String, dynamic> customer;
  final VoidCallback onSubmitted;
  const _PayInvoiceDialog({
    required this.invoice,
    required this.customer,
    required this.onSubmitted,
  });

  @override
  State<_PayInvoiceDialog> createState() => _PayInvoiceDialogState();
}

class _PayInvoiceDialogState extends State<_PayInvoiceDialog> {
  final _db = DatabaseService();
  String _method = 'Bank Transfer';
  final _referenceCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _referenceCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _db.submitPaymentReference(
        invoiceId: widget.invoice['id'].toString(),
        customerId: widget.customer['id'].toString(),
        partnerId: widget.customer['partner_id']?.toString(),
        method: _method,
        reference: _referenceCtl.text.trim().isEmpty
            ? null
            : _referenceCtl.text.trim(),
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        amount: (widget.invoice['total'] as num?)?.toDouble(),
      );
      widget.onSubmitted();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment reference submitted. We will confirm it shortly.',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total =
        (widget.invoice['total'] as num?)?.toStringAsFixed(2) ?? '0.00';
    return AlertDialog(
      title: Text('Pay Invoice ${widget.invoice['invoice_number'] ?? ''}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Amount due: \$$total',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to pay',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pay by bank transfer, cash, or POS at any branch, then '
                      'submit the reference below so we can confirm it. '
                      'Contact us if you need our banking details.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Bank Transfer',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem(
                    value: 'Cash at Branch',
                    child: Text('Cash at Branch'),
                  ),
                  DropdownMenuItem(
                    value: 'POS at Branch',
                    child: Text('POS at Branch'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setState(() => _method = v ?? 'Bank Transfer'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Reference / Confirmation Number',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _referenceCtl,
                decoration: InputDecoration(
                  hintText: 'e.g. transfer confirmation #',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Notes (optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtl,
                maxLines: 2,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit Payment Reference'),
        ),
      ],
    );
  }
}

// ═════ Shipping Addresses ════════════════════════════════════════════════

class _ShippingAddressesPage extends StatelessWidget {
  final Map<String, dynamic> customer;
  final Map<String, String> warehouseAddress;
  const _ShippingAddressesPage({
    required this.customer,
    required this.warehouseAddress,
  });

  @override
  Widget build(BuildContext context) {
    final rawMailbox = (customer['mailbox_number'] as String?)?.trim();
    final hasMailbox = rawMailbox != null && rawMailbox.isNotEmpty;
    final mailbox = hasMailbox ? rawMailbox : '';
    final name = (customer['name'] as String?) ?? 'Customer';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shipping Addresses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Use these addresses when shopping online',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(
                  Icons.warning_amber_outlined,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Copy each line exactly as shown. Incorrect addresses may cause delays or lost packages.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!hasMailbox)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFD97706)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mailbox number not yet assigned',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your account doesn\'t have a unique mailbox number '
                          'yet, so a shipping address can\'t be shown safely — '
                          'without it, packages can\'t be matched to you at the '
                          'warehouse. Contact support and we\'ll get one '
                          'assigned.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
              final wide = c.maxWidth > 800;
              final air = _WarehouseAddressCard(
                title: 'AIR Warehouse',
                tint: const Color(0xFF10B981),
                name: name,
                addressLine1: warehouseAddress['line1']!,
                addressLine2: '${mailbox}_AIR',
                city: warehouseAddress['city']!,
                state: warehouseAddress['state']!,
                zip: warehouseAddress['zip']!,
                country: warehouseAddress['country']!,
              );
              final sea = _WarehouseAddressCard(
                title: 'SEA Warehouse',
                tint: const Color(0xFF3B82F6),
                name: name,
                addressLine1: warehouseAddress['line1']!,
                addressLine2: '$mailbox SEA',
                city: warehouseAddress['city']!,
                state: warehouseAddress['state']!,
                zip: warehouseAddress['zip']!,
                country: warehouseAddress['country']!,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: air),
                    const SizedBox(width: 16),
                    Expanded(child: sea),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [air, const SizedBox(height: 16), sea],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WarehouseAddressCard extends StatelessWidget {
  final String title;
  final Color tint;
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String zip;
  final String country;

  const _WarehouseAddressCard({
    required this.title,
    required this.tint,
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AddressField(label: 'Name', value: name),
          const SizedBox(height: 10),
          _AddressField(label: 'Address Line 1', value: addressLine1),
          const SizedBox(height: 10),
          _AddressField(label: 'Address Line 2', value: addressLine2),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AddressField(label: 'City', value: city),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AddressField(label: 'State', value: state),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AddressField(label: 'ZIP Code', value: zip),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AddressField(label: 'Country', value: country),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  final String label;
  final String value;
  const _AddressField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 14),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied: $value'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════ Pre-Alerts ═══════════════════════════════════════════════════════

class _PreAlertsPage extends StatelessWidget {
  final List<Map<String, dynamic>> preAlerts;
  final Map<String, dynamic> customer;
  final Future<void> Function() onCreated;
  const _PreAlertsPage({
    required this.preAlerts,
    required this.customer,
    required this.onCreated,
  });

  Future<void> _showCreateDialog(BuildContext context) async {
    final db = DatabaseService();
    final tracking = TextEditingController();
    final carrier = TextEditingController();
    final description = TextEditingController();
    final declaredValue = TextEditingController();
    bool saving = false;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Pre-Alert'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tracking,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Tracking Number *',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: carrier,
                    decoration: const InputDecoration(
                      labelText: 'Carrier',
                      hintText: 'UPS, FedEx, USPS...',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'What is in the package?',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: declaredValue,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Item Value (\$)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (tracking.text.trim().isEmpty ||
                          description.text.trim().isEmpty) {
                        setDialogState(
                          () => error = 'Tracking number and description are required.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await db.insertPreAlert({
                          'tracking_number': tracking.text.trim(),
                          'customer_id': customer['id'],
                          'customer_name': customer['name'],
                          'carrier': carrier.text.trim(),
                          'description': description.text.trim(),
                          'declared_value': double.tryParse(declaredValue.text.trim()) ?? 0,
                          'status': 'pending',
                          if (customer['partner_id'] != null)
                            'partner_id': customer['partner_id'],
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = 'Failed to submit: $e';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (created == true) await onCreated();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pre-Alerts',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pre-Alerts help us accurately identify your packages, ensuring faster and smoother customs clearance.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Pre-Alert'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                  columns: const [
                    DataColumn(label: Text('Tracking')),
                    DataColumn(label: Text('Courier')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Item Value')),
                    DataColumn(label: Text('Linked')),
                    DataColumn(label: Text('Created at')),
                  ],
                  rows: preAlerts.isEmpty
                      ? [
                          const DataRow(
                            cells: [
                              DataCell(Text('—')),
                              DataCell(Text('')),
                              DataCell(Text('No pre-alerts yet')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                            ],
                          ),
                        ]
                      : [
                          for (final a in preAlerts)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(a['tracking_number']?.toString() ?? '—'),
                                ),
                                DataCell(Text(a['carrier']?.toString() ?? '—')),
                                DataCell(
                                  Text(a['description']?.toString() ?? '—'),
                                ),
                                DataCell(
                                  Text(
                                    '\$${(a['declared_value'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  ),
                                ),
                                DataCell(
                                  Text(a['package_id'] == null ? 'No' : 'Yes'),
                                ),
                                DataCell(Text(_fmtDate(a['created_at']))),
                              ],
                            ),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════ Refer & Earn ══════════════════════════════════════════════════════

class _ReferEarnPage extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _ReferEarnPage({required this.customer});

  @override
  Widget build(BuildContext context) {
    // Was hardcoded to https://applizonecentralja.com/... — a real,
    // different, unrelated site (the one this whole portal's UI was
    // originally modeled on, per this file's own top-of-file comment —
    // apparently copied along with the design). Anyone who actually
    // used "their" referral link was sending friends to someone else's
    // website, not this one. Uri.base.origin is whatever domain the
    // customer is actually on right now — this app's own shared host,
    // or their specific courier's custom domain.
    final link = '${Uri.base.origin}/#/customer-login?ref=${customer['id'] ?? 'CUSTOMER'}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Color(0xFFE11D48),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refer & Earn',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Share your link and earn rewards when friends sign up',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your link below is real and works — but points, '
                    'conversions, and rewards aren\'t tracked automatically '
                    'yet, so the numbers on this page won\'t move even after '
                    'a friend signs up. Contact support if someone used your '
                    'link.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE4E6), Color(0xFFFFF1F2)],
              ),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFE11D48)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Points Balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '0',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      'Worth approximately',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    Text(
                      '\$0.00',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Text(
                      'Your Referral Link',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Share this QR code or link with friends to earn rewards',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Direct Link',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy Link'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatTile(
                  data: _StatTileData(
                    title: 'Friends Referred',
                    value: '0',
                    sub: '',
                    icon: Icons.group_outlined,
                    tint: const Color(0xFFDBEAFE),
                    iconColor: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatTile(
                  data: _StatTileData(
                    title: 'Conversions',
                    value: '0',
                    sub: '',
                    icon: Icons.check_circle_outline,
                    tint: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════ Rate Calculator ═══════════════════════════════════════════════════

class _RateCalculatorPage extends StatefulWidget {
  const _RateCalculatorPage();

  @override
  State<_RateCalculatorPage> createState() => _RateCalculatorPageState();
}

class _RateCalculatorPageState extends State<_RateCalculatorPage> {
  final _weightCtl = TextEditingController();
  final _valueCtl = TextEditingController();
  String _mode = 'Sea Freight';
  String? _estimate;

  void _calculate() {
    final w = double.tryParse(_weightCtl.text) ?? 0;
    final v = double.tryParse(_valueCtl.text) ?? 0;
    if (w <= 0 || v <= 0) {
      setState(() => _estimate = 'Enter valid weight and value to calculate.');
      return;
    }
    // Prefer the current courier's own configured rates (set in their
    // dashboard's Rate Calculator/Api Sync settings tabs) over the
    // generic fallback — every customer used to get the same demo
    // numbers ($4.50/lb air, $2.25/lb sea, 20% duty) no matter which
    // courier's portal they were actually on.
    final rates = TenantService().rates;
    final usingRealRates =
        rates != null &&
        (_mode == 'Air Freight' ? rates['airPerLb'] : rates['seaPerLb']) !=
            null;
    final perLb =
        (rates?[_mode == 'Air Freight' ? 'airPerLb' : 'seaPerLb'] as num?)
            ?.toDouble() ??
        (_mode == 'Air Freight' ? 4.5 : 2.25);
    final dutyPercent =
        (rates?['dutyPercent'] as num?)?.toDouble() ?? 20.0;
    final shipping = w * perLb;
    final duty = v * (dutyPercent / 100);
    final total = shipping + duty;
    setState(
      () => _estimate =
          'Estimated ${_mode.toLowerCase()} cost: \$${total.toStringAsFixed(2)} '
          '(\$${shipping.toStringAsFixed(2)} shipping + \$${duty.toStringAsFixed(2)} duty)'
          '${usingRealRates ? '' : '\n\nThis is a general estimate — your courier '
                'hasn\'t set custom rates yet.'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Calculator',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Get instant shipping cost estimates',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instant Shipping Estimates',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      Text(
                        'Enter your package details below to get an accurate cost estimate. This is for reference only - final charges may vary.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Package Details',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Package Weight (lbs) *',
                        child: TextField(
                          controller: _weightCtl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDec('Enter weight'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Package Value (\$) *',
                        child: TextField(
                          controller: _valueCtl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDec('Enter value'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Rate Calculator *',
                  child: DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: _inputDec('Select mode'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Sea Freight',
                        child: Text('Sea Freight'),
                      ),
                      DropdownMenuItem(
                        value: 'Air Freight',
                        child: Text('Air Freight'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _mode = v ?? 'Sea Freight'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _calculate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.calculate, size: 18),
                    label: const Text('Calculate Estimate'),
                  ),
                ),
                if (_estimate != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _estimate!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ═════ Mobile App ════════════════════════════════════════════════════════

class _MobileAppPage extends StatelessWidget {
  const _MobileAppPage();

  void _notBuiltYet(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Not available yet'),
      content: const Text(
        'There\'s no mobile app to download yet — this page is a preview '
        'of what\'s coming. Everything here already works in your '
        'browser, including on your phone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Was hardcoded to a brand name ("Wanhub") that has nothing to do
    // with this app or any courier using it — leftover from whatever
    // template this page's design was copied from. companyName already
    // resolves to the current courier's real name (or this platform's
    // own, on the direct/admin host).
    final brand = TenantService().companyName ?? 'our';
    return Center(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.phone_iphone,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Get the $brand Mobile App',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track packages, pay invoices, and create pre-alerts from your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Coming soon — everything here already works great in your '
              'phone\'s browser in the meantime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _notBuiltYet(context),
                  icon: const Icon(Icons.apple),
                  label: const Text('App Store'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _notBuiltYet(context),
                  icon: const Icon(Icons.shop),
                  label: const Text('Google Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════ Settings ══════════════════════════════════════════════════════════

class _SettingsPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onProfileUpdated;
  const _SettingsPage({
    required this.customer,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _db = DatabaseService();
  late final _nameCtl = TextEditingController(
    text: (widget.customer['name'] as String?) ?? '',
  );
  late final _phoneCtl = TextEditingController(
    text: (widget.customer['phone'] as String?) ?? '',
  );
  late final _addressCtl = TextEditingController(
    text: (widget.customer['address'] as String?) ?? '',
  );
  bool _saving = false;
  String? _saveError;
  bool _requestingDeletion = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameCtl.text.trim().isEmpty) {
      setState(() => _saveError = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final updated = await _db.updateOwnCustomerProfile(
        name: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
        address: _addressCtl.text.trim(),
      );
      widget.onProfileUpdated(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Failed to save: $e';
      });
    }
  }

  Future<void> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'This submits a real request to One Village staff to delete your '
          'account. Nothing is deleted immediately — your request will be '
          'reviewed and processed according to policy. You\'ll be signed '
          'out now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Request Deletion'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _requestingDeletion = true);
    try {
      await _db.requestOwnAccountDeletion();
      widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestingDeletion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = (widget.customer['email'] as String?) ?? '';
    final deletionRequestedAt = widget.customer['deletion_requested_at'] as String?;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage your account profile and delivery address',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 520,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Profile',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your name, phone, and delivery address.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 14),
                _SettingsField(label: 'Full Name', controller: _nameCtl),
                const SizedBox(height: 12),
                _SettingsField(label: 'Phone', controller: _phoneCtl),
                const SizedBox(height: 12),
                _SettingsField(
                  label: 'Delivery Address',
                  controller: _addressCtl,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        email.isEmpty ? 'No email on file' : email,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Contact support to change the email you sign in with.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 520,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Request account deletion',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  deletionRequestedAt != null
                      ? 'Your deletion request was submitted and is awaiting review by staff.'
                      : 'Permanently request deletion of your account. Once submitted you will be signed out and your request will be processed according to our policy.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                ),
                const SizedBox(height: 12),
                if (deletionRequestedAt == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _requestingDeletion ? null : _confirmDeletion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                      ),
                      child: _requestingDeletion
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Request account deletion'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _SettingsField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
