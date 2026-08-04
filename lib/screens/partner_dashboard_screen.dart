import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Home screen for approved shipping partners — styled to match
/// the Applizone Central JA Backoffice layout.
class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  final _db = DatabaseService();
  Map<String, dynamic>? _account;
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;

  // Real stats loaded from Supabase (partner-scoped where possible).
  _PartnerStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!_db.isAuthenticated) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/partner-login');
        }
        return;
      }
      final account = await _db.getPartnerAccount(_db.currentUser!.id);
      if (!mounted) return;
      if (account == null || account['status'] != 'approved') {
        await _db.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/partner-login');
        }
        return;
      }
      setState(() {
        _account = account;
        _loading = false;
      });
      // Load stats in the background; don't block the UI.
      _loadStats(account);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadStats(Map<String, dynamic> account) async {
    try {
      final prefix = (account['tracking_prefix'] as String?) ?? '';
      final partnerId = account['id']?.toString();
      final results = await Future.wait([
        partnerId != null
            ? _db.getCustomersByPartner(partnerId)
            : _db.getCustomers(),
        if (partnerId != null)
          _db.getPackagesByPartner(partnerId)
        else if (prefix.isNotEmpty)
          _db.getPackagesByPrefix(prefix)
        else
          _db.getPackages(),
        partnerId != null
            ? _db.getInvoicesByPartner(partnerId)
            : _db.getInvoices(),
      ]);
      final customers = results[0];
      final packages = results[1];
      final invoices = results[2];
      if (!mounted) return;
      setState(() {
        _stats = _PartnerStats.from(
          customers: customers,
          packages: packages,
          invoices: invoices,
        );
      });
    } catch (e) {
      // Leave _stats as null — dashboard falls back to dashes.
      // ignore: avoid_print
      print('[PartnerDashboard] stats load failed: $e');
    }
  }

  Future<void> _logout() async {
    await _db.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/partner-login');
  }

  // Sidebar menu grouped like backoffice
  static const List<_NavSection> _sections = [
    _NavSection('Main', [
      _NavItem('Dashboard', Icons.dashboard_outlined),
      _NavItem('Point of Sale', Icons.point_of_sale_outlined),
      _NavItem('Customers', Icons.people_outline),
    ]),
    _NavSection('Management', [
      _NavItem('Packages', Icons.inventory_2_outlined),
      _NavItem('Shipments', Icons.local_shipping_outlined),
      _NavItem('Receivals', Icons.move_to_inbox_outlined),
      _NavItem('Unk Packages', Icons.help_outline),
      _NavItem('Pre-Alerts', Icons.notifications_active_outlined),
    ]),
    _NavSection('Marketing', [
      _NavItem('Broadcast', Icons.campaign_outlined),
      _NavItem('Referrals', Icons.card_giftcard_outlined, badge: 'New'),
      _NavItem('Mobile App', Icons.phone_iphone, badge: 'New'),
    ]),
    _NavSection('Financial', [
      _NavItem('Reports', Icons.bar_chart_outlined),
      _NavItem('Transactions', Icons.receipt_long_outlined),
    ]),
  ];

  static const List<_NavItem> _footerItems = [
    _NavItem('Settings', Icons.settings_outlined),
    _NavItem('Support', Icons.support_agent_outlined),
    _NavItem('Instructions', Icons.menu_book_outlined),
  ];

  // Flattened list mapping index -> title for breadcrumb / content router
  List<_NavItem> get _flat {
    final all = <_NavItem>[];
    for (final s in _sections) {
      all.addAll(s.items);
    }
    all.addAll(_footerItems);
    return all;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partner Portal')),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
        ),
      );
    }
    final a = _account!;
    final current = _flat[_selectedIndex];
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    return Scaffold(
      backgroundColor: _panelBg,
      drawer: isCompact
          ? Drawer(child: _buildSidebar(a, expanded: true, inDrawer: true))
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isCompact)
              _buildSidebar(a, expanded: !_sidebarCollapsed, inDrawer: false),
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(isCompact ? 0 : 0, 8, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    _buildTopBar(current, isCompact),
                    const Divider(height: 1, color: _border),
                    Expanded(child: _buildPageContent(current, a)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sidebar ───────────────────────────────────────────────────────────
  Widget _buildSidebar(
    Map<String, dynamic> account, {
    required bool expanded,
    required bool inDrawer,
  }) {
    final w = expanded ? 248.0 : 72.0;
    return Container(
      width: w,
      padding: const EdgeInsets.all(8),
      color: _panelBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sidebarBrand(account, expanded),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final section in _sections) ...[
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                      child: Text(
                        section.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _muted,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  for (final item in section.items)
                    _sidebarItem(item, expanded, inDrawer),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final item in _footerItems)
            _sidebarItem(item, expanded, inDrawer),
          const SizedBox(height: 8),
          _userPill(account, expanded),
        ],
      ),
    );
  }

  Widget _sidebarBrand(Map<String, dynamic> account, bool expanded) {
    final company = account['company_name']?.toString() ?? 'Partner';
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                company,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sidebarItem(_NavItem item, bool expanded, bool inDrawer) {
    final idx = _flat.indexOf(item);
    final selected = idx == _selectedIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 0),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _selectedIndex = idx);
            if (inDrawer) Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? AppTheme.primary : _muted,
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? _text : _textSoft,
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _userPill(Map<String, dynamic> account, bool expanded) {
    final name = account['contact_name']?.toString() ?? 'Partner';
    final email = account['email']?.toString() ?? '';
    final initials = _initials(name);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _logout,
              tooltip: 'Sign out',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.logout),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  // ─── Top Bar ───────────────────────────────────────────────────────────
  Widget _buildTopBar(_NavItem current, bool isCompact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Toggle Sidebar',
            onPressed: () {
              if (isCompact) {
                Scaffold.of(context).openDrawer();
              } else {
                setState(() => _sidebarCollapsed = !_sidebarCollapsed);
              }
            },
            icon: const Icon(Icons.view_sidebar_outlined, size: 18),
          ),
          const SizedBox(width: 4),
          Text('Dashboard', style: TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 16, color: _muted),
          const SizedBox(width: 6),
          Text(
            current.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
          const Spacer(),
          _topButton(Icons.location_on_outlined, 'kingston'),
          const SizedBox(width: 8),
          _topButton(Icons.bolt_outlined, 'Quick Quote'),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () {},
            icon: const Icon(Icons.dark_mode_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _topButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: _text,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 14, color: _muted),
      label: Text(label),
    );
  }

  // ─── Page Router ───────────────────────────────────────────────────────
  Widget _buildPageContent(_NavItem current, Map<String, dynamic> account) {
    final prefix = (account['tracking_prefix'] as String?) ?? '';
    final partnerId = account['id']?.toString();
    switch (current.label) {
      case 'Dashboard':
        return _DashboardPage(account: account, stats: _stats);
      case 'Point of Sale':
        return const _PointOfSalePage();
      case 'Customers':
        return _CustomersPage(db: _db, prefix: prefix, partnerId: partnerId);
      case 'Packages':
        return _PackagesPage(db: _db, prefix: prefix, partnerId: partnerId);
      case 'Shipments':
        return _ShipmentsPage(db: _db, partnerId: partnerId);
      case 'Receivals':
        return _ReceivalsPage(db: _db, prefix: prefix, partnerId: partnerId);
      case 'Unk Packages':
        return const _UnknownPackagesPage();
      case 'Pre-Alerts':
        return _PreAlertsPage(db: _db, partnerId: partnerId);
      case 'Reports':
        return const _ReportsPage();
      case 'Transactions':
        return _TransactionsPage(db: _db, partnerId: partnerId);
      case 'Settings':
        return _SettingsPage(account: account);
      case 'Broadcast':
        return const _BroadcastPage();
      case 'Referrals':
        return _ReferralsPage(account: account);
      case 'Mobile App':
        return _MobileAppPage(account: account);
      case 'Support':
        return const _SupportPage();
      case 'Instructions':
        return const _InstructionsPage();
      default:
        return _FeaturePage(title: current.label, icon: current.icon);
    }
  }
}

// ─── Constants ───────────────────────────────────────────────────────────
const Color _panelBg = Color(0xFFF5F5F7);
const Color _border = Color(0xFFE5E7EB);
const Color _text = Color(0xFF111827);
const Color _textSoft = Color(0xFF374151);
const Color _muted = Color(0xFF6B7280);

// ─── Nav models ──────────────────────────────────────────────────────────
class _NavSection {
  final String label;
  final List<_NavItem> items;
  const _NavSection(this.label, this.items);
}

class _NavItem {
  final String label;
  final IconData icon;
  final String? badge;
  const _NavItem(this.label, this.icon, {this.badge});
}

// ─── Dashboard Page ──────────────────────────────────────────────────────
class _DashboardPage extends StatelessWidget {
  final Map<String, dynamic> account;
  final _PartnerStats? stats;
  const _DashboardPage({required this.account, required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MobileAppBanner(),
          const SizedBox(height: 16),
          _StatRow(stats: stats),
          const SizedBox(height: 16),
          _GrowthChartCard(stats: stats),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _CustomersByLocationCard(stats: stats)),
              const SizedBox(width: 16),
              Expanded(child: _RevenueTrendsCard(stats: stats)),
            ],
          ),
          const SizedBox(height: 16),
          _FeaturesIncludedCard(),
        ],
      ),
    );
  }
}

class _MobileAppBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, size: 16, color: Color(0xFF6366F1)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Partner Portal is now on Android! Available on Google Play & App Store.',
              style: TextStyle(fontSize: 12, color: _text),
            ),
          ),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 14),
            label: const Text(
              'Get the app',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final _PartnerStats? stats;
  const _StatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = stats;
        final cards = [
          _StatCard(
            icon: Icons.people_outline,
            tileColor: const Color(0xFFDBEAFE),
            iconColor: const Color(0xFF2563EB),
            value: s == null ? '—' : '${s.totalCustomers}',
            label: 'Total Customers',
            sub: 'ALL TIME',
          ),
          _StatCard(
            icon: Icons.badge_outlined,
            tileColor: const Color(0xFFEDE9FE),
            iconColor: const Color(0xFF7C3AED),
            value: s == null ? '—' : '${s.newCustomers7d}',
            label: 'New Customers',
            sub: 'LAST 7 DAYS',
          ),
          _StatCard(
            icon: Icons.inventory_2_outlined,
            tileColor: const Color(0xFFD1FAE5),
            iconColor: const Color(0xFF059669),
            value: s == null ? '—' : '${s.totalPackages}',
            label: 'Packages Processed',
            sub: 'ALL TIME',
          ),
          _StatCard(
            icon: Icons.bar_chart,
            tileColor: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            value: s == null ? '—' : s.customersPerDay.toStringAsFixed(1),
            label: 'Customers / Day',
            sub: 'DAILY AVG (7d)',
          ),
          _StatCard(
            icon: Icons.bolt,
            tileColor: const Color(0xFFFEE2E2),
            iconColor: const Color(0xFFDC2626),
            value: s == null ? '—' : s.packagesPerDay.toStringAsFixed(1),
            label: 'Packages / Day',
            sub: 'DAILY AVG (7d)',
          ),
        ];
        final cols = constraints.maxWidth > 1200
            ? 5
            : constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in cards) SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color tileColor;
  final Color iconColor;
  final String value;
  final String label;
  final String sub;
  final String? trend;
  final bool trendUp;

  const _StatCard({
    required this.icon,
    required this.tileColor,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.sub,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (trendUp ? AppTheme.success : AppTheme.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: trendUp ? AppTheme.success : AppTheme.danger,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: trendUp ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

class _GrowthChartCard extends StatelessWidget {
  final _PartnerStats? stats;
  const _GrowthChartCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Package & Customer Growth',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Total for the last 7 days',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
              const Spacer(),
              _RangePill(label: 'Last 3 months'),
              const SizedBox(width: 4),
              _RangePill(label: 'Last 30 days'),
              const SizedBox(width: 4),
              _RangePill(label: 'Last 7 days', selected: true),
              const SizedBox(width: 4),
              _RangePill(label: 'Custom'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _AreaChartPainter(
                packages7d: stats?.packages7d,
                customers7d: stats?.customers7d,
                labels: stats?.labels7d,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool selected;
  const _RangePill({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.white : _panelBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? _text : _muted,
        ),
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<int>? packages7d;
  final List<int>? customers7d;
  final List<String>? labels;
  _AreaChartPainter({this.packages7d, this.customers7d, this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pkg = packages7d ?? List<int>.filled(7, 0);
    final cust = customers7d ?? List<int>.filled(7, 0);
    final maxVal = [
      ...pkg,
      ...cust,
      1,
    ].reduce((a, b) => a > b ? a : b).toDouble();
    final greenData = pkg.map((v) => v / maxVal).toList();
    final indigoData = cust.map((v) => v / maxVal).toList();
    _drawSeries(canvas, size, greenData, const Color(0xFF10B981));
    _drawSeries(canvas, size, indigoData, const Color(0xFF6366F1));
    final lbls = labels ?? const ['', '', '', '', '', '', ''];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < lbls.length; i++) {
      tp.text = TextSpan(
        text: lbls[i],
        style: const TextStyle(fontSize: 10, color: _muted),
      );
      tp.layout();
      final x = w * i / (lbls.length - 1) - tp.width / 2;
      tp.paint(canvas, Offset(x, h - 14));
    }
  }

  void _drawSeries(Canvas canvas, Size size, List<double> data, Color color) {
    if (data.isEmpty) return;
    final h = size.height - 20;
    final w = size.width;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = w * i / (data.length - 1);
      final y = h * (1 - data[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = w * (i - 1) / (data.length - 1);
        final prevY = h * (1 - data[i - 1]);
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
      }
    }
    // Fill
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);
    // Line
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) =>
      oldDelegate.packages7d != packages7d ||
      oldDelegate.customers7d != customers7d;
}

class _CustomersByLocationCard extends StatelessWidget {
  final _PartnerStats? stats;
  const _CustomersByLocationCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customers by Location',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Distribution across major cities',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(
                painter: _DonutPainter(percent: 1.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stats == null ? '—' : '${stats!.totalCustomers}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      const Text(
                        'Customers',
                        style: TextStyle(fontSize: 10, color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 14, color: AppTheme.success),
              const SizedBox(width: 6),
              const Text(
                'Growing customer base across regions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Showing customer distribution by location',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;
  _DonutPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    final ringPaint = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(center, radius, ringPaint);
    final arcPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * percent,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RevenueTrendsCard extends StatelessWidget {
  final _PartnerStats? stats;
  const _RevenueTrendsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.attach_money, size: 16, color: _muted),
              SizedBox(width: 6),
              Text(
                'Revenue Trends',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Monthly revenue performance',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _RevenueChartPainter(monthly: stats?.revenueByMonth),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                stats == null
                    ? 'Revenue — no data yet'
                    : 'Total revenue: \$${stats!.totalRevenue.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.trending_up, size: 14, color: AppTheme.success),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            stats == null
                ? 'Monthly revenue will appear here once invoices are created.'
                : 'Average monthly revenue: \$${stats!.avgMonthlyRevenue.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  final List<double>? monthly;
  _RevenueChartPainter({this.monthly});

  @override
  void paint(Canvas canvas, Size size) {
    final raw = monthly ?? List<double>.filled(12, 0);
    final maxVal = raw.fold<double>(0, (a, b) => b > a ? b : a);
    final data = maxVal > 0
        ? raw.map((v) => v / maxVal).toList()
        : List<double>.filled(12, 0);
    final w = size.width;
    final h = size.height - 20;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = w * i / (data.length - 1);
      final y = h * (1 - data[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = w * (i - 1) / (data.length - 1);
        final prevY = h * (1 - data[i - 1]);
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.25),
          const Color(0xFF6366F1).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);
    final stroke = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, stroke);
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
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < months.length; i++) {
      tp.text = TextSpan(
        text: months[i],
        style: const TextStyle(fontSize: 9, color: _muted),
      );
      tp.layout();
      final x = w * i / (months.length - 1) - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) =>
      oldDelegate.monthly != monthly;
}

class _FeaturesIncludedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      'Customer Portal',
      'iOS & Android Apps',
      'Advanced Package Tracking',
      'Backoffice Portal',
      'Pre-Alert System',
      'Invoice Management',
      'Unlimited Users',
      'Multiple Branch Locations',
      'Point of Sale',
      'Email Marketing',
      'Label Generation',
      'Advanced Reporting',
      'No Setup Fee',
      'White Label',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Everything included in your plan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 12,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        f,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Feature placeholder page (used for every non-Dashboard nav item) ────
class _FeaturePage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _FeaturePage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Included',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _descriptionFor(title),
              style: const TextStyle(
                fontSize: 13,
                color: _textSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panelBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Full $title functionality is being rolled out to your portal. '
                      'Contact support to enable early access.',
                      style: const TextStyle(fontSize: 12, color: _textSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _descriptionFor(String title) {
    switch (title) {
      case 'Point of Sale':
        return 'Built-in POS for in-store package pickups, payments, and walk-in sales. Accept cash, card, and mobile wallets with receipt printing.';
      case 'Customers':
        return 'Manage your customer database — registrations, addresses, contact preferences, and lifetime stats.';
      case 'Packages':
        return 'End-to-end package management with scan history, location updates, and automated customer notifications.';
      case 'Shipments':
        return 'Outbound & inbound shipment management — track consolidations, manifests, and delivery status.';
      case 'Receivals':
        return 'Warehouse intake: scan incoming packages, match to pre-alerts, and assign storage zones.';
      case 'Unk Packages':
        return 'Unknown / unidentified packages — attach tracking info and match them to customers.';
      case 'Pre-Alerts':
        return 'Customers can pre-register inbound packages with supplier tracking numbers and invoices before they arrive.';
      case 'Broadcast':
        return 'Send targeted email campaigns to your customers — promotions, statements, and newsletters.';
      case 'Referrals':
        return 'Reward customers for bringing new users to your service.';
      case 'Mobile App':
        return 'Native iOS & Android apps for your customers, published under your brand.';
      case 'Reports':
        return 'Revenue, volume, customer cohort, and operational KPIs — exportable to CSV / Excel.';
      case 'Transactions':
        return 'Full transaction ledger — payments, refunds, adjustments, and fees across all branches.';
      case 'Settings':
        return 'Configure your company profile, branch locations, tax rates, rate cards, and branding.';
      case 'Support':
        return 'Get help from the Applizone Central JA support team 24/7.';
      case 'Instructions':
        return 'Onboarding guides, API docs, and best practices for getting the most out of your portal.';
      default:
        return 'Manage $title directly from your partner portal.';
    }
  }
}

// ─── Real stats model (loaded from Supabase) ─────────────────────────────
class _PartnerStats {
  final int totalCustomers;
  final int newCustomers7d;
  final int totalPackages;
  final int packages7dTotal;
  final List<int> packages7d; // 7 daily buckets, oldest → newest
  final List<int> customers7d;
  final List<String> labels7d;
  final double customersPerDay;
  final double packagesPerDay;
  final double totalRevenue;
  final double avgMonthlyRevenue;
  final List<double> revenueByMonth; // 12 entries, Jan..Dec of current year

  _PartnerStats({
    required this.totalCustomers,
    required this.newCustomers7d,
    required this.totalPackages,
    required this.packages7dTotal,
    required this.packages7d,
    required this.customers7d,
    required this.labels7d,
    required this.customersPerDay,
    required this.packagesPerDay,
    required this.totalRevenue,
    required this.avgMonthlyRevenue,
    required this.revenueByMonth,
  });

  factory _PartnerStats.from({
    required List<Map<String, dynamic>> customers,
    required List<Map<String, dynamic>> packages,
    required List<Map<String, dynamic>> invoices,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Build 7 day buckets: index 0 = 6 days ago, index 6 = today
    final days = List<DateTime>.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );
    final labels = days
        .map(
          (d) => '${_monthAbbr(d.month)} ${d.day.toString().padLeft(2, '0')}',
        )
        .toList();
    final pkg7 = List<int>.filled(7, 0);
    final cust7 = List<int>.filled(7, 0);

    DateTime? parse(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    for (final p in packages) {
      final t = parse(p['created_at']);
      if (t == null) continue;
      for (var i = 0; i < 7; i++) {
        if (_sameDay(t, days[i])) {
          pkg7[i]++;
          break;
        }
      }
    }
    var newCust7Total = 0;
    for (final c in customers) {
      final t = parse(c['created_at']);
      if (t == null) continue;
      for (var i = 0; i < 7; i++) {
        if (_sameDay(t, days[i])) {
          cust7[i]++;
          newCust7Total++;
          break;
        }
      }
    }

    // Revenue by month of current year
    final revByMonth = List<double>.filled(12, 0);
    var totalRev = 0.0;
    for (final inv in invoices) {
      final paid = (inv['status']?.toString() ?? '').toLowerCase() == 'paid';
      if (!paid) continue;
      final t = parse(inv['paid_at']) ?? parse(inv['created_at']);
      if (t == null) continue;
      final amt =
          double.tryParse(inv['total']?.toString() ?? '') ??
          double.tryParse(inv['amount']?.toString() ?? '') ??
          0;
      totalRev += amt;
      if (t.year == now.year) {
        revByMonth[t.month - 1] += amt;
      }
    }
    final monthsSoFar = now.month;
    final avgMonth = monthsSoFar == 0 ? 0.0 : totalRev / monthsSoFar;

    final pkg7Total = pkg7.fold<int>(0, (a, b) => a + b);
    return _PartnerStats(
      totalCustomers: customers.length,
      newCustomers7d: newCust7Total,
      totalPackages: packages.length,
      packages7dTotal: pkg7Total,
      packages7d: pkg7,
      customers7d: cust7,
      labels7d: labels,
      customersPerDay: newCust7Total / 7.0,
      packagesPerDay: pkg7Total / 7.0,
      totalRevenue: totalRev,
      avgMonthlyRevenue: avgMonth,
      revenueByMonth: revByMonth,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _monthAbbr(int m) {
    const names = [
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
    return names[(m - 1).clamp(0, 11)];
  }
}

// ─── Shared page scaffold ────────────────────────────────────────────────
class _PagePanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;
  const _PagePanel({
    required this.title,
    this.subtitle,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null) ...[const SizedBox(width: 12), ...actions!],
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}

class _DataTableCard extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final String emptyMessage;
  const _DataTableCard({
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No records found.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textSoft,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 13, color: _text),
                  columns: [
                    for (final c in columns) DataColumn(label: Text(c)),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow(
                        cells: [for (final cell in r) DataCell(Text(cell))],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

Widget _futureList<T>({
  required Future<List<T>> future,
  required Widget Function(List<T>) builder,
}) {
  return FutureBuilder<List<T>>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return Center(
          child: Text(
            'Error loading data: ${snap.error}',
            style: const TextStyle(color: AppTheme.danger),
          ),
        );
      }
      return builder(snap.data ?? const []);
    },
  );
}

String _s(dynamic v) => v == null ? '—' : v.toString();
String _money(dynamic v) {
  final d = double.tryParse(v?.toString() ?? '');
  return d == null ? '—' : '\$${d.toStringAsFixed(2)}';
}

String _date(dynamic v) {
  if (v == null) return '—';
  final t = DateTime.tryParse(v.toString())?.toLocal();
  if (t == null) return v.toString();
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

// ─── Customers Page ──────────────────────────────────────────────────────
class _CustomersPage extends StatefulWidget {
  final DatabaseService db;
  final String prefix;
  final String? partnerId;
  const _CustomersPage({
    required this.db,
    required this.prefix,
    required this.partnerId,
  });

  @override
  State<_CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<_CustomersPage> {
  late Future<List<Map<String, dynamic>>> _future;

  Future<List<Map<String, dynamic>>> _fetch() => widget.partnerId != null
      ? widget.db.getCustomersByPartner(widget.partnerId!)
      : widget.db.getCustomers();

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  void _refresh() {
    setState(() => _future = _fetch());
  }

  Future<void> _openAddDialog() async {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final addressCtl = TextEditingController();
    final prefix = widget.prefix.isEmpty ? 'CUST' : widget.prefix;
    final nextBox =
        '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final mailboxCtl = TextEditingController(text: nextBox);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Customer'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mailboxCtl,
                  decoration: const InputDecoration(
                    labelText: 'Mailbox Number',
                    prefixIcon: Icon(Icons.markunread_mailbox),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              try {
                await widget.db.insertCustomer({
                  'name': name,
                  if (emailCtl.text.trim().isNotEmpty)
                    'email': emailCtl.text.trim(),
                  if (phoneCtl.text.trim().isNotEmpty)
                    'phone': phoneCtl.text.trim(),
                  if (addressCtl.text.trim().isNotEmpty)
                    'address': addressCtl.text.trim(),
                  'mailbox_number': mailboxCtl.text.trim(),
                  'status': 'active',
                  if (widget.partnerId != null) 'partner_id': widget.partnerId,
                });
                if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(
                    dialogCtx,
                  ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                }
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer added')));
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Customers',
      subtitle: 'Manage your customer accounts and contact details.',
      actions: [
        ElevatedButton.icon(
          onPressed: _openAddDialog,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Customer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
      child: _futureList<Map<String, dynamic>>(
        future: _future,
        builder: (data) => _DataTableCard(
          columns: const [
            'Name',
            'Email',
            'Phone',
            'Mailbox',
            'Status',
            'Created',
          ],
          rows: [
            for (final c in data)
              [
                _s(c['name'] ?? c['full_name']),
                _s(c['email']),
                _s(c['phone']),
                _s(c['mailbox_number'] ?? c['account_number']),
                _s(c['status']),
                _date(c['created_at']),
              ],
          ],
          emptyMessage: 'No customers yet. Add one to get started.',
        ),
      ),
    );
  }
}

// ─── Packages Page ───────────────────────────────────────────────────────
class _PackagesPage extends StatefulWidget {
  final DatabaseService db;
  final String prefix;
  final String? partnerId;
  const _PackagesPage({
    required this.db,
    required this.prefix,
    required this.partnerId,
  });

  @override
  State<_PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<_PackagesPage> {
  late Future<List<Map<String, dynamic>>> _future;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribe() {
    final client = Supabase.instance.client;
    final ch = client.channel('partner-packages-${widget.partnerId ?? 'all'}');
    for (final table in ['packages', 'invoices']) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          if (mounted) _refresh();
        },
      );
    }
    ch.subscribe();
    _channel = ch;
  }

  Future<List<Map<String, dynamic>>> _load() {
    if (widget.partnerId != null) {
      return widget.db.getPackagesByPartner(widget.partnerId!);
    }
    return widget.prefix.isEmpty
        ? widget.db.getPackages()
        : widget.db.getPackagesByPrefix(widget.prefix);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Packages',
      subtitle: widget.prefix.isEmpty
          ? 'All packages in the warehouse system.'
          : 'Packages assigned to tracking prefix "${widget.prefix}".',
      actions: [
        _PrimaryAction(label: 'Refresh', icon: Icons.refresh, onTap: _refresh),
      ],
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: AppTheme.danger),
              ),
            );
          }
          final data = snap.data ?? const [];
          if (data.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No packages found for this account.'),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < data.length; i++)
                    _PackageRow(
                      pkg: data[i],
                      partnerId: widget.partnerId,
                      db: widget.db,
                      isFirst: i == 0,
                      isLast: i == data.length - 1,
                      onChanged: _refresh,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final String? partnerId;
  final DatabaseService db;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onChanged;

  const _PackageRow({
    required this.pkg,
    required this.partnerId,
    required this.db,
    required this.isFirst,
    required this.isLast,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final status = (pkg['status'] ?? '').toString();
    final billed = pkg['billed_amount'];
    final invoiceId = pkg['invoice_id']?.toString();
    final pickedUp = pkg['picked_up_at'] != null;
    final statusColor = switch (status) {
      'received' => AppTheme.success,
      'in_transit' => AppTheme.primary,
      'ready_for_pickup' => const Color(0xFF10B981),
      'picked_up' => _muted,
      _ => _muted,
    };
    return InkWell(
      onTap: () => _openEditor(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: isFirst ? BorderSide.none : const BorderSide(color: _border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg['tracking_number']?.toString() ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pkg['customer_name'] ?? '—'} · ${pkg['description'] ?? '—'}',
                    style: const TextStyle(fontSize: 12, color: _muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: Text(
                pkg['weight'] == null ? '—' : '${pkg['weight']} lb',
                style: const TextStyle(fontSize: 12, color: _textSoft),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: Text(
                billed == null ? 'Not billed' : '\$$billed',
                style: TextStyle(
                  fontSize: 12,
                  color: billed == null ? _muted : _text,
                  fontWeight: billed == null
                      ? FontWeight.w400
                      : FontWeight.w700,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    _openEditor(context);
                    break;
                  case 'bill':
                    await _openBillDialog(context);
                    break;
                  case 'paid':
                    if (invoiceId != null) {
                      await db.markInvoicePaid(invoiceId);
                      await db.updatePackage(pkg['id'] as String, {
                        'status': 'ready_for_pickup',
                      });
                      onChanged();
                    }
                    break;
                  case 'pickup':
                    await db.updatePackage(pkg['id'] as String, {
                      'status': 'picked_up',
                      'picked_up_at': DateTime.now().toUtc().toIso8601String(),
                    });
                    onChanged();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit package')),
                PopupMenuItem(
                  value: 'bill',
                  enabled: invoiceId == null,
                  child: Text(
                    invoiceId == null ? 'Bill customer' : 'Already billed',
                  ),
                ),
                PopupMenuItem(
                  value: 'paid',
                  enabled:
                      invoiceId != null &&
                      status != 'picked_up' &&
                      status != 'ready_for_pickup',
                  child: const Text('Mark invoice paid'),
                ),
                PopupMenuItem(
                  value: 'pickup',
                  enabled: !pickedUp && status == 'ready_for_pickup',
                  child: const Text('Mark picked up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PackageEditorDialog(pkg: pkg, db: db),
    );
    if (changed == true) onChanged();
  }

  Future<void> _openBillDialog(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _BillCustomerDialog(pkg: pkg, db: db, partnerId: partnerId),
    );
    if (changed == true) onChanged();
  }
}

class _PackageEditorDialog extends StatefulWidget {
  final Map<String, dynamic> pkg;
  final DatabaseService db;
  const _PackageEditorDialog({required this.pkg, required this.db});

  @override
  State<_PackageEditorDialog> createState() => _PackageEditorDialogState();
}

class _PackageEditorDialogState extends State<_PackageEditorDialog> {
  late final TextEditingController _desc;
  late final TextEditingController _weight;
  late String _status;
  bool _saving = false;
  String? _error;

  static const _statuses = [
    'received',
    'in_transit',
    'ready_for_pickup',
    'picked_up',
    'returned',
  ];

  @override
  void initState() {
    super.initState();
    _desc = TextEditingController(
      text: widget.pkg['description']?.toString() ?? '',
    );
    _weight = TextEditingController(
      text: widget.pkg['weight']?.toString() ?? '',
    );
    _status = (widget.pkg['status']?.toString().isNotEmpty ?? false)
        ? widget.pkg['status'].toString()
        : 'received';
    if (!_statuses.contains(_status)) _statuses.add(_status);
  }

  @override
  void dispose() {
    _desc.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updates = <String, dynamic>{
        'description': _desc.text.trim(),
        'status': _status,
      };
      final w = double.tryParse(_weight.text.trim());
      if (w != null) updates['weight'] = w;
      await widget.db.updatePackage(widget.pkg['id'] as String, updates);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.pkg['tracking_number']?.toString() ?? 'Edit package'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.pkg['customer_name']?.toString() ?? '',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight (lb)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in _statuses)
                  DropdownMenuItem(
                    value: s,
                    child: Text(s.replaceAll('_', ' ')),
                  ),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _BillCustomerDialog extends StatefulWidget {
  final Map<String, dynamic> pkg;
  final DatabaseService db;
  final String? partnerId;
  const _BillCustomerDialog({
    required this.pkg,
    required this.db,
    required this.partnerId,
  });

  @override
  State<_BillCustomerDialog> createState() => _BillCustomerDialogState();
}

class _BillCustomerDialogState extends State<_BillCustomerDialog> {
  late final TextEditingController _amountCtl;
  late final TextEditingController _taxCtl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final w = double.tryParse(widget.pkg['weight']?.toString() ?? '') ?? 0;
    final value =
        double.tryParse(widget.pkg['declared_value']?.toString() ?? '') ?? 0;
    // Default: $4.50/lb (air) + 0.5% of declared value — partner can edit.
    final suggested = (w * 4.50 + value * 0.005).toStringAsFixed(2);
    _amountCtl = TextEditingController(text: suggested);
    _taxCtl = TextEditingController(text: '15'); // GCT 15%
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _taxCtl.dispose();
    super.dispose();
  }

  Future<void> _charge() async {
    final amount = double.tryParse(_amountCtl.text.trim());
    final taxPct = double.tryParse(_taxCtl.text.trim()) ?? 0;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.db.createInvoiceForPackage(
        pkg: widget.pkg,
        amount: amount,
        taxRate: taxPct / 100,
        partnerId: widget.partnerId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountCtl.text) ?? 0;
    final taxPct = double.tryParse(_taxCtl.text) ?? 0;
    final total = amount + amount * (taxPct / 100);
    return AlertDialog(
      title: const Text('Bill customer'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.pkg['tracking_number']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              widget.pkg['customer_name']?.toString() ?? '',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (USD)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _taxCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tax %',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _panelBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _charge,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create invoice'),
        ),
      ],
    );
  }
}

// ─── Shipments Page ──────────────────────────────────────────────────────
class _ShipmentsPage extends StatelessWidget {
  final DatabaseService db;
  final String? partnerId;
  const _ShipmentsPage({required this.db, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Shipments',
      subtitle: 'Outgoing and incoming shipment manifests.',
      actions: const [_PrimaryAction(label: 'New Shipment', icon: Icons.add)],
      child: _futureList<Map<String, dynamic>>(
        future: partnerId != null
            ? db.getShipmentsByPartner(partnerId!)
            : db.getShipments(),
        builder: (data) => _DataTableCard(
          columns: const [
            'Shipment #',
            'Carrier',
            'Origin',
            'Destination',
            'Status',
            'Date',
          ],
          rows: [
            for (final s in data)
              [
                _s(s['shipment_number'] ?? s['reference']),
                _s(s['carrier']),
                _s(s['origin']),
                _s(s['destination']),
                _s(s['status']),
                _date(s['created_at'] ?? s['shipped_at']),
              ],
          ],
        ),
      ),
    );
  }
}

// ─── Receivals Page ──────────────────────────────────────────────────────
class _ReceivalsPage extends StatelessWidget {
  final DatabaseService db;
  final String prefix;
  final String? partnerId;
  const _ReceivalsPage({
    required this.db,
    required this.prefix,
    required this.partnerId,
  });

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Receivals',
      subtitle: 'Packages received into the warehouse.',
      child: _futureList<Map<String, dynamic>>(
        future: partnerId != null
            ? db.getPackagesByPartner(partnerId!)
            : (prefix.isEmpty
                  ? db.getPackages()
                  : db.getPackagesByPrefix(prefix)),
        builder: (data) {
          final received = data
              .where(
                (p) =>
                    (p['status']?.toString().toLowerCase() ?? '') == 'received',
              )
              .toList();
          return _DataTableCard(
            columns: const [
              'Tracking #',
              'Customer',
              'Description',
              'Weight',
              'Received',
            ],
            rows: [
              for (final p in received)
                [
                  _s(p['tracking_number']),
                  _s(p['customer_name']),
                  _s(p['description']),
                  p['weight'] == null ? '—' : '${p['weight']} lb',
                  _date(p['created_at']),
                ],
            ],
            emptyMessage: 'No received packages yet.',
          );
        },
      ),
    );
  }
}

// ─── Pre-Alerts Page ─────────────────────────────────────────────────────
class _PreAlertsPage extends StatelessWidget {
  final DatabaseService db;
  final String? partnerId;
  const _PreAlertsPage({required this.db, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Pre-Alerts',
      subtitle: 'Customer pre-alert submissions awaiting receival.',
      child: _futureList<Map<String, dynamic>>(
        future: partnerId != null
            ? db.getPreAlertsByPartner(partnerId!)
            : db.getPreAlerts(),
        builder: (data) => _DataTableCard(
          columns: const [
            'Tracking #',
            'Customer',
            'Merchant',
            'Description',
            'Value',
            'Submitted',
          ],
          rows: [
            for (final a in data)
              [
                _s(a['tracking_number']),
                _s(a['customer_name'] ?? a['customer']),
                _s(a['merchant']),
                _s(a['description']),
                _money(a['value'] ?? a['declared_value']),
                _date(a['created_at']),
              ],
          ],
          emptyMessage: 'No pre-alerts submitted yet.',
        ),
      ),
    );
  }
}

// ─── Transactions Page ───────────────────────────────────────────────────
class _TransactionsPage extends StatelessWidget {
  final DatabaseService db;
  final String? partnerId;
  const _TransactionsPage({required this.db, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Transactions',
      subtitle: 'Invoices, payments, and account activity.',
      child: _futureList<Map<String, dynamic>>(
        future: partnerId != null
            ? db.getInvoicesByPartner(partnerId!)
            : db.getInvoices(),
        builder: (data) => _DataTableCard(
          columns: const [
            'Invoice #',
            'Customer',
            'Amount',
            'Status',
            'Created',
            'Paid',
          ],
          rows: [
            for (final i in data)
              [
                _s(i['invoice_number'] ?? i['id']),
                _s(i['customer_name'] ?? i['customer']),
                _money(i['total'] ?? i['amount']),
                _s(i['status']),
                _date(i['created_at']),
                _date(i['paid_at']),
              ],
          ],
          emptyMessage: 'No transactions recorded yet.',
        ),
      ),
    );
  }
}

// ─── Static placeholder pages ────────────────────────────────────────────
class _PointOfSalePage extends StatelessWidget {
  const _PointOfSalePage();
  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Point of Sale',
      subtitle:
          'Process customer payments, package pickups, and walk-in sales.',
      actions: const [_PrimaryAction(label: 'New Sale', icon: Icons.add)],
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.point_of_sale, size: 48, color: _muted),
              const SizedBox(height: 12),
              const Text(
                'POS Terminal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect your card reader and select a customer to begin a sale.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownPackagesPage extends StatelessWidget {
  const _UnknownPackagesPage();
  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Unknown Packages',
      subtitle: 'Packages received without a matching customer account.',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No unknown packages awaiting assignment.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _ReportsPage extends StatelessWidget {
  const _ReportsPage();
  @override
  Widget build(BuildContext context) {
    final reports = [
      ('Daily Sales', Icons.today, 'Today\'s revenue and package count'),
      ('Customer Activity', Icons.people, 'Top customers by volume'),
      ('Outstanding Invoices', Icons.receipt_long, 'Unpaid balances'),
      ('Package Aging', Icons.inventory_2, 'Time in warehouse'),
      ('Manifest Summary', Icons.local_shipping, 'Shipments by carrier'),
      ('Tax Report', Icons.account_balance, 'GCT and duty totals'),
    ];
    return _PagePanel(
      title: 'Reports',
      subtitle: 'Generate operational and financial reports.',
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: [
          for (final r in reports)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(r.$2, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.$1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.$3,
                          style: TextStyle(fontSize: 11, color: _muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  final Map<String, dynamic> account;
  const _SettingsPage({required this.account});
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  String? _openCard;

  static const _cards = <_SettingsCard>[
    _SettingsCard(
      'Company',
      Icons.business,
      'Update your company settings. This information will be displayed publicly so be careful what you share.',
    ),
    _SettingsCard(
      'Customization',
      Icons.palette,
      'Customize look and feel of your platform',
    ),
    _SettingsCard(
      'Subscription',
      Icons.workspace_premium,
      'Manage your subscription plan and billing information',
    ),
    _SettingsCard(
      'Online Payment Gateway',
      Icons.credit_card,
      'Process payments online',
    ),
    _SettingsCard(
      'User Management',
      Icons.group,
      'People who work in the company',
    ),
    _SettingsCard(
      'Roles and Permissions',
      Icons.shield,
      'Limit access to parts of software',
    ),
    _SettingsCard(
      'Locations',
      Icons.location_on,
      'Locations that consist of stores and warehouses',
    ),
    _SettingsCard(
      'Charges',
      Icons.receipt_long,
      'Charges that can be added during invoicing. Custom line items',
    ),
    _SettingsCard(
      'Discounts',
      Icons.local_offer,
      'Manage discount codes and promotional offers',
    ),
    _SettingsCard(
      'Storage Fee',
      Icons.warehouse,
      'Automatically add storage fees to invoices.',
    ),
    _SettingsCard(
      'Terms and Conditions',
      Icons.description,
      'This will be shown to the user when they sign up for an account. They have to accept it before proceeding.',
    ),
    _SettingsCard(
      'Api Sync',
      Icons.sync,
      'Sync with external warehouse dashboard',
    ),
    _SettingsCard(
      'Shipping Addresses',
      Icons.local_shipping,
      'Address that will be used by customers',
    ),
    _SettingsCard(
      'Currency',
      Icons.attach_money,
      'Manage conversion rates of charges',
    ),
    _SettingsCard(
      'Rate Calculator',
      Icons.calculate,
      'Manage rate calculation configurations and rules',
    ),
    _SettingsCard(
      'Api Sync Legacy',
      Icons.sync_problem,
      'Sync with external warehouse dashboard (Legacy)',
    ),
    _SettingsCard(
      'Webhooks',
      Icons.webhook,
      'Listen to realtime events from warehouses',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_openCard != null) {
      return _SettingsDetailPage(
        title: _openCard!,
        account: widget.account,
        onBack: () => setState(() => _openCard = null),
      );
    }
    return _PagePanel(
      title: 'Settings',
      subtitle: 'Manage your platform configuration and preferences',
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 1100
              ? 3
              : c.maxWidth >= 760
              ? 2
              : 1;
          return GridView.count(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: [
              for (final c in _cards)
                _SettingsCardTile(
                  card: c,
                  onTap: () => setState(() => _openCard = c.title),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsCard {
  final String title;
  final IconData icon;
  final String description;
  const _SettingsCard(this.title, this.icon, this.description);
}

class _SettingsCardTile extends StatelessWidget {
  final _SettingsCard card;
  final VoidCallback onTap;
  const _SettingsCardTile({required this.card, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(card.icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: _muted,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDetailPage extends StatelessWidget {
  final String title;
  final Map<String, dynamic> account;
  final VoidCallback onBack;
  const _SettingsDetailPage({
    required this.title,
    required this.account,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('All Settings'),
              style: TextButton.styleFrom(foregroundColor: _textSoft),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitleFor(title),
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: _body(context),
          ),
        ),
      ],
    );
  }

  String _subtitleFor(String t) {
    switch (t) {
      case 'Company':
        return 'Update your company settings.';
      case 'Customization':
        return 'Customize look and feel of your platform.';
      case 'Subscription':
        return 'Manage your subscription plan and billing information.';
      case 'Online Payment Gateway':
        return 'Process payments online.';
      case 'User Management':
        return 'People who work in the company.';
      case 'Roles and Permissions':
        return 'Limit access to parts of software.';
      case 'Locations':
        return 'Locations that consist of stores and warehouses.';
      case 'Charges':
        return 'Custom line items for invoicing.';
      case 'Discounts':
        return 'Manage discount codes and promotional offers.';
      case 'Storage Fee':
        return 'Automatically add storage fees to invoices.';
      case 'Terms and Conditions':
        return 'Shown to customers on sign up.';
      case 'Api Sync':
        return 'Sync with external warehouse dashboard.';
      case 'Shipping Addresses':
        return 'Addresses used by customers for pre-alerts.';
      case 'Currency':
        return 'Manage conversion rates.';
      case 'Rate Calculator':
        return 'Manage rate calculation rules.';
      case 'Api Sync Legacy':
        return 'Legacy sync with external warehouse dashboard.';
      case 'Webhooks':
        return 'Listen to realtime events from warehouses.';
    }
    return '';
  }

  Widget _body(BuildContext context) {
    switch (title) {
      case 'Company':
        return _CompanyProfileTab(account: account);
      case 'Customization':
        return const _BrandingTab();
      case 'User Management':
        return const _UserManagementTab();
      case 'Currency':
        return const _TaxCurrencyTab();
      case 'Online Payment Gateway':
        return const _IntegrationsTab();
      case 'Api Sync':
      case 'Api Sync Legacy':
      case 'Webhooks':
        return _ApiKeysTab(account: account);
      case 'Subscription':
        return const _SubscriptionBody();
      case 'Roles and Permissions':
        return const _RolesBody();
      case 'Locations':
        return const _LocationsBody();
      case 'Charges':
        return const _ChargesBody();
      case 'Discounts':
        return const _DiscountsBody();
      case 'Storage Fee':
        return const _StorageFeeBody();
      case 'Terms and Conditions':
        return const _TermsBody();
      case 'Shipping Addresses':
        return const _ShippingAddressesBody();
      case 'Rate Calculator':
        return const _RateCalcBody();
    }
    return Center(
      child: Text('$title coming soon', style: TextStyle(color: _muted)),
    );
  }
}

class _SubscriptionBody extends StatelessWidget {
  const _SubscriptionBody();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, const Color(0xFF8B0000)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Professional Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Unlimited users · Multi-branch · Full feature set',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '\$299',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'per month',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Next billing',
                  value: 'May 01, 2026',
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Payment method',
                  value: 'Visa •••• 4242',
                  icon: Icons.credit_card,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Status',
                  value: 'Active',
                  icon: Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Change Plan'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: _text,
                  side: const BorderSide(color: _border),
                ),
                child: const Text('Download Invoices'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RolesBody extends StatelessWidget {
  const _RolesBody();
  @override
  Widget build(BuildContext context) {
    final roles = [
      ('Owner', 'Full access to all features', true),
      ('Admin', 'Manage operations and staff', true),
      ('Manager', 'View reports and manage customers', true),
      ('Cashier', 'Process sales and receivals only', true),
      ('Read-only', 'View-only access to dashboard', true),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Roles',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Role'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = roles[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: _muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          Text(
                            r.$2,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Edit Permissions'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LocationsBody extends StatelessWidget {
  const _LocationsBody();
  @override
  Widget build(BuildContext context) {
    final locs = [
      ('Kingston HQ', '10 Knutsford Blvd, Kingston', 'Warehouse'),
      ('Montego Bay', 'Sam Sharpe Square, Montego Bay', 'Store'),
      ('Ocho Rios', 'Main Street, Ocho Rios', 'Pickup'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Locations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_location, size: 16),
                label: const Text('Add Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: locs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final l = locs[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          Text(
                            l.$2,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.$3,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ChargesBody extends StatelessWidget {
  const _ChargesBody();
  @override
  Widget build(BuildContext context) {
    final charges = [
      ('Customs Handling', '\$5.00 USD', 'Per package'),
      ('Fuel Surcharge', '\$2.50 USD', 'Per shipment'),
      ('Insurance', '2% of value', 'Per package'),
      ('After-Hours Pickup', '\$15.00 USD', 'Per request'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Custom Line Items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Charge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: charges.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = charges[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        c.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        c.$2,
                        style: const TextStyle(fontSize: 13, color: _text),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        c.$3,
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 16, color: _muted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _DiscountsBody extends StatelessWidget {
  const _DiscountsBody();
  @override
  Widget build(BuildContext context) {
    final codes = [
      ('SPRING20', '20% off', 'Active', 'Expires May 31'),
      ('NEWCUSTOMER', '10% off first order', 'Active', 'No expiry'),
      ('VIP50', '\$50 off', 'Paused', 'Expires Dec 31'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Promo Codes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: codes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = codes[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _panelBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        d.$1,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d.$2,
                        style: const TextStyle(fontSize: 13, color: _text),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (d.$3 == 'Active'
                                    ? AppTheme.success
                                    : AppTheme.warning)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        d.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: d.$3 == 'Active'
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(d.$4, style: TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StorageFeeBody extends StatelessWidget {
  const _StorageFeeBody();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _ToggleRow(title: 'Enable automatic storage fees', value: true),
                SizedBox(height: 12),
                _SettingsField(
                  label: 'Grace Period (days)',
                  initial: '7',
                  icon: Icons.hourglass_top,
                ),
                SizedBox(height: 12),
                _SettingsField(
                  label: 'Daily Storage Rate (USD)',
                  initial: '1.00',
                  icon: Icons.attach_money,
                ),
                SizedBox(height: 12),
                _SettingsField(
                  label: 'Maximum Storage Fee (USD)',
                  initial: '50.00',
                  icon: Icons.money_off,
                ),
                SizedBox(height: 12),
                _ToggleRow(
                  title: 'Notify customer when fees begin accruing',
                  value: true,
                ),
              ],
            ),
          ),
        ),
        const _SettingsSaveBar(),
      ],
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SettingsField(
                  label: 'Terms & Conditions',
                  initial:
                      '1. Acceptance of Terms\n\nBy registering for an account, you agree to be bound by these terms.\n\n2. Services\n\nWe provide courier and warehousing services subject to availability.\n\n3. Liability\n\nOur liability is limited to the declared value of the package.\n\n4. Privacy\n\nYour personal information is handled per our privacy policy.',
                  maxLines: 14,
                ),
                SizedBox(height: 12),
                _ToggleRow(
                  title: 'Require customer to accept on sign up',
                  value: true,
                ),
                SizedBox(height: 4),
                _ToggleRow(
                  title: 'Require re-acceptance when terms change',
                  value: true,
                ),
              ],
            ),
          ),
        ),
        const _SettingsSaveBar(),
      ],
    );
  }
}

class _ShippingAddressesBody extends StatelessWidget {
  const _ShippingAddressesBody();
  @override
  Widget build(BuildContext context) {
    final addresses = [
      ('Miami Hub — US', '8200 NW 27th St, Miami, FL 33122, USA'),
      ('Buffalo Hub — US', '1200 Niagara St, Buffalo, NY 14213, USA'),
      ('London Hub — UK', '45 Wembley Park Dr, London HA9 8HA, UK'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Addresses shown to customers',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final a = addresses[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          Text(
                            a.$2,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 16, color: _muted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RateCalcBody extends StatelessWidget {
  const _RateCalcBody();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Weight-based Rate Table',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                SizedBox(height: 8),
                _RateRow(range: '0 – 1 lb', rate: '\$8.00'),
                _RateRow(range: '1 – 5 lb', rate: '\$3.50 / lb'),
                _RateRow(range: '5 – 20 lb', rate: '\$3.00 / lb'),
                _RateRow(range: '20 – 50 lb', rate: '\$2.50 / lb'),
                _RateRow(range: '50 lb +', rate: '\$2.00 / lb'),
                SizedBox(height: 16),
                _ToggleRow(
                  title: 'Use volumetric weight when higher',
                  value: true,
                ),
                _ToggleRow(title: 'Round up to nearest 0.5 lb', value: true),
                _ToggleRow(
                  title: 'Apply fuel surcharge automatically',
                  value: false,
                ),
              ],
            ),
          ),
        ),
        const _SettingsSaveBar(),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  final String range;
  final String rate;
  const _RateRow({required this.range, required this.rate});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(child: Text(range, style: const TextStyle(fontSize: 13))),
          Text(
            rate,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? initial;
  final TextEditingController? controller;
  final IconData? icon;
  final bool obscure;
  final int maxLines;
  const _SettingsField({
    required this.label,
    this.hint,
    this.initial,
    this.controller,
    this.icon,
    this.obscure = false,
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
            color: _textSoft,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initial : null,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _muted, fontSize: 13),
            prefixIcon: icon == null ? null : Icon(icon, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSaveBar extends StatelessWidget {
  final VoidCallback? onSave;
  final bool saving;
  const _SettingsSaveBar({this.onSave, this.saving = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(foregroundColor: _muted),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: saving
                ? null
                : (onSave ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings saved')),
                        );
                      }),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _CompanyProfileTab extends StatefulWidget {
  final Map<String, dynamic> account;
  const _CompanyProfileTab({required this.account});
  @override
  State<_CompanyProfileTab> createState() => _CompanyProfileTabState();
}

class _CompanyProfileTabState extends State<_CompanyProfileTab> {
  final _db = DatabaseService();
  late final _companyNameCtl = TextEditingController(
    text: (widget.account['company_name'] as String?) ?? '',
  );
  late final _emailCtl = TextEditingController(
    text: (widget.account['email'] as String?) ?? '',
  );
  late final _phoneCtl = TextEditingController(
    text: (widget.account['phone'] as String?) ?? '',
  );
  late final _addressCtl = TextEditingController(
    text: (widget.account['address'] as String?) ?? '',
  );
  late final _prefixCtl = TextEditingController(
    text: (widget.account['tracking_prefix'] as String?) ?? '',
  );
  late final _domainCtl = TextEditingController(
    text: (widget.account['domain'] as String?) ?? '',
  );
  late String _domainStatus =
      (widget.account['domain_status'] as String?) ?? 'unset';
  bool _saving = false;
  bool _provisioning = false;
  String? _error;

  @override
  void dispose() {
    _companyNameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _prefixCtl.dispose();
    _domainCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _db.updatePartnerAccount(widget.account['id'] as String, {
        'company_name': _companyNameCtl.text.trim(),
        'email': _emailCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
        'address': _addressCtl.text.trim(),
        'tracking_prefix': _prefixCtl.text.trim(),
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save changes: $e';
      });
    }
  }

  Future<void> _provisionDomain() async {
    final domain = _domainCtl.text.trim();
    if (domain.isEmpty) {
      setState(() => _error = 'Enter a domain first.');
      return;
    }
    setState(() {
      _provisioning = true;
      _error = null;
    });
    try {
      final result = await _db.provisionPartnerDomain(
        domain: domain,
        partnerAccountId: widget.account['id'] as String,
      );
      if (!mounted) return;
      setState(() {
        _provisioning = false;
        _domainStatus = (result['status'] as String?) ?? 'pending_dns';
      });
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add this DNS record'),
          content: Text(
            (result['instructions'] as String?) ??
                'Point $domain to us via CNAME to finish setup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _provisioning = false;
        _error = 'Domain provisioning failed: $e';
      });
    }
  }

  Widget _domainStatusBadge() {
    final (label, color) = switch (_domainStatus) {
      'verified' => ('Verified', AppTheme.success),
      'pending_dns' => ('Waiting on DNS', AppTheme.warning),
      _ => ('Not connected', _muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        _companyNameCtl.text.isNotEmpty
                            ? _companyNameCtl.text.substring(0, 1).toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Business Logo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recommended: 256×256 PNG, transparent background',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.upload, size: 14),
                          label: const Text('Upload'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _text,
                            side: const BorderSide(color: _border),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _SettingsField(
                  label: 'Business Name',
                  controller: _companyNameCtl,
                  icon: Icons.business,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsField(
                        label: 'Contact Email',
                        controller: _emailCtl,
                        icon: Icons.email,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Contact Phone',
                        controller: _phoneCtl,
                        icon: Icons.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Business Address',
                  controller: _addressCtl,
                  icon: Icons.location_on,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Tracking Prefix',
                  controller: _prefixCtl,
                  icon: Icons.qr_code,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Custom Domain',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textSoft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _domainStatusBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _domainCtl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'track.yourcompany.com',
                          hintStyle: TextStyle(color: _muted, fontSize: 13),
                          prefixIcon: const Icon(Icons.language, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _provisioning ? null : _provisionDomain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      child: _provisioning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Connect'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a CNAME record for this domain pointing to '
                  'cname.vercel-dns.com at your DNS provider.',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
        ),
        _SettingsSaveBar(onSave: _save, saving: _saving),
      ],
    );
  }
}

class _BrandingTab extends StatelessWidget {
  const _BrandingTab();
  @override
  Widget build(BuildContext context) {
    final swatches = [
      const Color(0xFFCC0000),
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF0EA5E9),
      const Color(0xFF111827),
    ];
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Primary Brand Color',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final c in swatches)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsField(
                  label: 'Customer Portal Title',
                  initial: 'Welcome to your courier portal',
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Email Sender Name',
                  initial: 'Applizone Central JA',
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Email Footer',
                  initial: 'Thank you for choosing us.',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _ToggleRow(
                  title: 'Show partner branding in customer emails',
                  value: true,
                ),
                _ToggleRow(
                  title: 'Allow customers to download invoice PDFs',
                  value: true,
                ),
                _ToggleRow(
                  title: 'Use dark mode in customer portal',
                  value: false,
                ),
              ],
            ),
          ),
        ),
        const _SettingsSaveBar(),
      ],
    );
  }
}

class _TaxCurrencyTab extends StatelessWidget {
  const _TaxCurrencyTab();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: _SettingsField(
                        label: 'Default Currency',
                        initial: 'JMD — Jamaican Dollar',
                        icon: Icons.attach_money,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Secondary Currency',
                        initial: 'USD — US Dollar',
                        icon: Icons.attach_money,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(
                      child: _SettingsField(
                        label: 'GCT Rate (%)',
                        initial: '15.0',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Customs Duty Rate (%)',
                        initial: '20.0',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Environmental Levy (%)',
                        initial: '0.5',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Default Shipping Rate (per lb)',
                  initial: '\$3.50 USD',
                ),
                const SizedBox(height: 16),
                _ToggleRow(title: 'Apply GCT to shipping fees', value: true),
                _ToggleRow(title: 'Show prices inclusive of tax', value: false),
              ],
            ),
          ),
        ),
        const _SettingsSaveBar(),
      ],
    );
  }
}

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab();
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Stripe', 'Payment processing', Icons.credit_card, true),
      ('PayPal', 'Alternate payments', Icons.account_balance_wallet, false),
      ('DHL', 'Shipping carrier', Icons.local_shipping, true),
      ('FedEx', 'Shipping carrier', Icons.local_shipping, false),
      ('Twilio', 'SMS notifications', Icons.sms, true),
      ('SendGrid', 'Transactional email', Icons.mail, true),
      ('QuickBooks', 'Accounting sync', Icons.account_balance, false),
      ('Zapier', 'Workflow automations', Icons.bolt, false),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(i.$3, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.$1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        Text(
                          i.$2,
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  if (i.$4)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Connected',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _text,
                        side: const BorderSide(color: _border),
                      ),
                      child: const Text('Connect'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UserManagementTab extends StatelessWidget {
  const _UserManagementTab();
  @override
  Widget build(BuildContext context) {
    final users = [
      ('Owner Account', 'owner@example.com', 'Owner', AppTheme.primary),
      ('Operations Manager', 'ops@example.com', 'Admin', AppTheme.success),
      ('Front Desk', 'desk@example.com', 'Cashier', _muted),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Team members',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Invite User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final u = users[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: u.$4.withValues(alpha: 0.15),
                      child: Text(
                        u.$1.substring(0, 1),
                        style: TextStyle(
                          color: u.$4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          Text(
                            u.$2,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: u.$4.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        u.$3,
                        style: TextStyle(
                          color: u.$4,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ApiKeysTab extends StatelessWidget {
  final Map<String, dynamic> account;
  const _ApiKeysTab({required this.account});
  @override
  Widget build(BuildContext context) {
    final apiKey =
        (account['api_key'] as String?) ??
        'sk_live_${(account['id']?.toString() ?? 'XXXXXXXX').substring(0, 8)}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Treat your API keys like passwords. Never commit them to source control.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live API Key',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _panelBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          apiKey,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: _text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _text,
                        side: const BorderSide(color: _border),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Regenerate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: BorderSide(
                          color: AppTheme.danger.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SettingsField(
            label: 'Webhook Endpoint URL',
            hint: 'https://yourdomain.com/webhooks/applizone',
            icon: Icons.webhook,
          ),
          const SizedBox(height: 12),
          const _SettingsField(
            label: 'Rate Limit (requests / minute)',
            initial: '120',
            icon: Icons.speed,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatefulWidget {
  final String title;
  final bool value;
  const _ToggleRow({required this.title, required this.value});
  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool _val = widget.value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 13, color: _textSoft),
            ),
          ),
          Switch(
            value: _val,
            onChanged: (v) => setState(() => _val = v),
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

// ─── Broadcast / Referrals / Mobile App / Support / Instructions ─────────
class _BroadcastPage extends StatefulWidget {
  const _BroadcastPage();
  @override
  State<_BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<_BroadcastPage> {
  String _channel = 'Email';
  String _audience = 'All Customers';

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Broadcast',
      subtitle: 'Send announcements and promotions to your customers.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DropdownField(
                            label: 'Channel',
                            value: _channel,
                            options: const ['Email', 'SMS', 'Push', 'In-App'],
                            onChanged: (v) => setState(() => _channel = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DropdownField(
                            label: 'Audience',
                            value: _audience,
                            options: const [
                              'All Customers',
                              'Active (last 30d)',
                              'New This Month',
                              'High-Value (>\$500)',
                            ],
                            onChanged: (v) => setState(() => _audience = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _SettingsField(
                      label: 'Subject',
                      hint: 'A short, attention-grabbing headline',
                    ),
                    const SizedBox(height: 16),
                    const _SettingsField(
                      label: 'Message',
                      hint: 'Write your announcement here…',
                      maxLines: 8,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.attach_file, size: 14),
                          label: const Text('Attach Image'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _text,
                            side: const BorderSide(color: _border),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Save Draft'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Broadcast queued via $_channel to $_audience',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.send, size: 14),
                          label: const Text('Send Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Broadcasts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final r in const [
                    ('Spring Sale 20% Off', 'Email · 1,204 sent', '3d ago'),
                    ('Holiday Hours Update', 'SMS · 980 sent', '1w ago'),
                    ('New Mobile App Launch', 'Push · 624 sent', '2w ago'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign, size: 18, color: _muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.$1,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                                Text(
                                  r.$2,
                                  style: TextStyle(fontSize: 11, color: _muted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            r.$3,
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
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
            color: _textSoft,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: _text),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferralsPage extends StatelessWidget {
  final Map<String, dynamic> account;
  const _ReferralsPage({required this.account});
  @override
  Widget build(BuildContext context) {
    final code = ((account['tracking_prefix'] as String?) ?? 'PARTNER')
        .toUpperCase();
    return _PagePanel(
      title: 'Referrals',
      subtitle: 'Earn rewards by referring other couriers to Applizone.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, const Color(0xFF8B0000)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refer a partner, earn \$250 credit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'When they sign up and complete their first month, you both get rewarded.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOUR CODE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Referrals Sent',
                    value: '12',
                    icon: Icons.send,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Signed Up',
                    value: '4',
                    icon: Icons.person_add,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Credits Earned',
                    value: '\$1,000',
                    icon: Icons.savings,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Referrals',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final r in const [
                    ('Quick Ship Ltd', 'quick@example.com', 'Active'),
                    ('Island Express', 'island@example.com', 'Active'),
                    ('Coast Couriers', 'coast@example.com', 'Pending'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.$1,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r.$2,
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (r.$3 == 'Active'
                                          ? AppTheme.success
                                          : AppTheme.warning)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              r.$3,
                              style: TextStyle(
                                color: r.$3 == 'Active'
                                    ? AppTheme.success
                                    : AppTheme.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: _muted)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileAppPage extends StatelessWidget {
  final Map<String, dynamic> account;
  const _MobileAppPage({required this.account});
  @override
  Widget build(BuildContext context) {
    final brand = (account['business_name'] as String?) ?? 'Your Brand';
    return _PagePanel(
      title: 'Mobile App',
      subtitle: 'Your white-label customer app for iOS and Android.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 120,
                    height: 200,
                    decoration: BoxDecoration(
                      color: _panelBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border, width: 4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          brand,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$brand — Customer App',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pre-alerts, package tracking, payments, and notifications — all in your customers\' pocket.',
                          style: TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.apple, size: 16),
                              label: const Text('App Store'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.android, size: 16),
                              label: const Text('Google Play'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'App Features',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                for (final f in const [
                  ('Real-time Tracking', Icons.location_on),
                  ('Pre-Alerts', Icons.notifications_active),
                  ('In-App Payments', Icons.credit_card),
                  ('Push Notifications', Icons.send),
                  ('Photo Receipts', Icons.photo_camera),
                  ('Live Chat', Icons.chat_bubble),
                ])
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Icon(f.$2, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

class _SupportPage extends StatelessWidget {
  const _SupportPage();
  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Support',
      subtitle: 'We\'re here 24/7 — pick the channel that works for you.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Expanded(
                  child: _SupportTile(
                    title: 'Live Chat',
                    subtitle: 'Average reply: 2 min',
                    icon: Icons.chat,
                    cta: 'Start Chat',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SupportTile(
                    title: 'Email',
                    subtitle: 'support@applizonecentralja.com',
                    icon: Icons.mail,
                    cta: 'Send Email',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SupportTile(
                    title: 'Phone',
                    subtitle: '+1 (876) 555-0100',
                    icon: Icons.call,
                    cta: 'Call Now',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submit a Support Ticket',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SettingsField(
                    label: 'Subject',
                    hint: 'Briefly describe the issue',
                  ),
                  const SizedBox(height: 12),
                  const _SettingsField(
                    label: 'Description',
                    hint: 'Steps to reproduce, screenshots, error messages…',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ticket submitted')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit Ticket'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Frequently Asked',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: 8),
                  _FaqRow(
                    q: 'How do I add a new customer?',
                    a: 'Open the Customers tab and click "Add Customer" in the top-right.',
                  ),
                  _FaqRow(
                    q: 'How do I generate shipping labels?',
                    a: 'Open a package and click "Print Label" in the actions menu.',
                  ),
                  _FaqRow(
                    q: 'How do I configure my tracking prefix?',
                    a: 'Go to Settings → Company Profile → Tracking Prefix.',
                  ),
                  _FaqRow(
                    q: 'How do I get paid?',
                    a: 'Connect Stripe in Settings → Integrations. Payouts are daily.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String cta;
  const _SupportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cta,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Text(cta),
          ),
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  final String q;
  final String a;
  const _FaqRow({required this.q, required this.a});
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8, left: 4),
      title: Text(
        q,
        style: const TextStyle(
          fontSize: 13,
          color: _text,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(a, style: TextStyle(fontSize: 12, color: _muted)),
        ),
      ],
    );
  }
}

class _InstructionsPage extends StatelessWidget {
  const _InstructionsPage();
  @override
  Widget build(BuildContext context) {
    final guides = const [
      (
        'Getting Started',
        Icons.rocket_launch,
        '5 min read',
        'Set up your portal, brand it, and add your first customer.',
      ),
      (
        'Receiving Packages',
        Icons.inbox,
        '4 min read',
        'Workflow for receiving, weighing, and labeling incoming packages.',
      ),
      (
        'Pre-Alerts',
        Icons.notifications_active,
        '3 min read',
        'How customers submit pre-alerts and how to match them to packages.',
      ),
      (
        'Creating Shipments',
        Icons.local_shipping,
        '6 min read',
        'Build manifests, print labels, and hand off to carriers.',
      ),
      (
        'Invoicing & Payments',
        Icons.receipt_long,
        '5 min read',
        'Generate invoices, accept card payments, and track AR.',
      ),
      (
        'API & Webhooks',
        Icons.code,
        '8 min read',
        'Integrate Applizone with your own systems via REST + webhooks.',
      ),
    ];
    return _PagePanel(
      title: 'Instructions',
      subtitle: 'Step-by-step guides and best practices.',
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3,
        children: [
          for (final g in guides)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(g.$2, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                g.$1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _text,
                                ),
                              ),
                            ),
                            Text(
                              g.$3,
                              style: TextStyle(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          g.$4,
                          style: TextStyle(fontSize: 12, color: _muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Read guide',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              size: 12,
                              color: AppTheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _PrimaryAction({required this.label, required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed:
          onTap ??
          () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$label coming soon')));
          },
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
