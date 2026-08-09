import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
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
  List<Map<String, dynamic>> _branches = [];

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
      // Load stats and branch list in the background; don't block the UI.
      _loadStats(account);
      unawaited(_loadBranches());
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

  Future<void> _loadBranches() async {
    try {
      final branches = await _db.getBranches();
      if (!mounted) return;
      setState(() => _branches = branches);
    } catch (e) {
      // Leave _branches empty — location button falls back to "Set Location".
      // ignore: avoid_print
      print('[PartnerDashboard] branches load failed: $e');
    }
  }

  Map<String, dynamic>? get _preferredBranch {
    final id = _account?['preferred_branch_id']?.toString();
    if (id == null) return null;
    for (final b in _branches) {
      if (b['id']?.toString() == id) return b;
    }
    return null;
  }

  Future<void> _showLocationDialog() async {
    final accountId = _account?['id']?.toString();
    if (accountId == null) return;
    String? selectedId = _account?['preferred_branch_id']?.toString();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Receiving Location'),
              content: SizedBox(
                width: 420,
                child: _branches.isEmpty
                    ? const Text(
                        'No branch locations have been added yet. Ask your '
                        'OneVillage account admin to add one from the '
                        'Branches screen — it will appear here once added.',
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select the branch your shipments primarily '
                            'route through.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  for (final b in _branches)
                                    RadioListTile<String>(
                                      value: b['id'].toString(),
                                      groupValue: selectedId,
                                      onChanged: (v) =>
                                          setDialogState(() => selectedId = v),
                                      dense: true,
                                      title: Text(
                                        b['name']?.toString() ?? 'Branch',
                                      ),
                                      subtitle: Text(
                                        [
                                          b['city'],
                                          b['address'],
                                        ].where((s) => (s?.toString().isNotEmpty ?? false)).join(' · '),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                if (_branches.isNotEmpty)
                  FilledButton(
                    onPressed: saving || selectedId == null
                        ? null
                        : () async {
                            setDialogState(() => saving = true);
                            try {
                              await _db.updatePartnerAccount(accountId, {
                                'preferred_branch_id': selectedId,
                              });
                              if (!mounted) return;
                              setState(() {
                                _account = {
                                  ..._account!,
                                  'preferred_branch_id': selectedId,
                                };
                              });
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            } catch (e) {
                              setDialogState(() => saving = false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save: $e')),
                              );
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
                        : const Text('Save'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showQuickQuoteDialog() async {
    final weightCtl = TextEditingController();
    final valueCtl = TextEditingController();
    String mode = 'Sea Freight';
    String? estimate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void calculate() {
              final w = double.tryParse(weightCtl.text) ?? 0;
              final v = double.tryParse(valueCtl.text) ?? 0;
              if (w <= 0 || v <= 0) {
                setDialogState(
                  () => estimate = 'Enter a valid weight and value.',
                );
                return;
              }
              final settings = Map<String, dynamic>.from(
                _account?['settings'] as Map? ?? {},
              );
              final airRate =
                  (settings['rate_air_per_lb'] as num?)?.toDouble() ?? 4.5;
              final seaRate =
                  (settings['rate_sea_per_lb'] as num?)?.toDouble() ?? 2.25;
              final dutyPercent =
                  (settings['rate_duty_percent'] as num?)?.toDouble() ?? 20.0;
              final perLb = mode == 'Air Freight' ? airRate : seaRate;
              final shipping = w * perLb;
              final duty = v * (dutyPercent / 100);
              final total = shipping + duty;
              setDialogState(
                () => estimate =
                    'Estimated ${mode.toLowerCase()} cost: '
                    '\$${total.toStringAsFixed(2)} '
                    '(\$${shipping.toStringAsFixed(2)} shipping + '
                    '\$${duty.toStringAsFixed(2)} duty)',
              );
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.bolt_outlined, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Quick Quote'),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instant shipping estimate — for reference only, '
                      'final charges may vary.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightCtl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Weight (lbs)',
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: valueCtl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Declared Value (\$)',
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: InputDecoration(
                        labelText: 'Shipping Mode',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
                          setDialogState(() => mode = v ?? 'Sea Freight'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: calculate,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                        ),
                        icon: const Icon(Icons.calculate_outlined, size: 18),
                        label: const Text('Calculate'),
                      ),
                    ),
                    if (estimate != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          estimate!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
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
          _topButton(
            Icons.location_on_outlined,
            _preferredBranch?['city']?.toString().isNotEmpty == true
                ? _preferredBranch!['city'].toString()
                : (_preferredBranch?['name']?.toString() ?? 'Set Location'),
            onPressed: _showLocationDialog,
          ),
          const SizedBox(width: 8),
          _topButton(
            Icons.bolt_outlined,
            'Quick Quote',
            onPressed: _showQuickQuoteDialog,
          ),
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

  Widget _topButton(
    IconData icon,
    String label, {
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
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
        return _ReportsPage(db: _db, partnerId: partnerId);
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
        return 'Get help from the One Village support team 24/7.';
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

// ─── Shared Settings Form Dialog ─────────────────────────────────────────
// Used by every list-based Settings section (Locations, Charges,
// Discounts, Roles, Staff, Shipping Addresses) to add/edit a record
// without each section hand-rolling its own dialog.

class _FormField {
  final String key;
  final String label;
  final String? hint;
  final List<String>? options;
  final int maxLines;
  const _FormField(
    this.key,
    this.label, {
    this.hint,
    this.options,
    this.maxLines = 1,
  });
}

Future<Map<String, String>?> _showFormDialog(
  BuildContext context, {
  required String title,
  required List<_FormField> fields,
  Map<String, String>? initialValues,
  String confirmLabel = 'Save',
}) {
  final controllers = <String, TextEditingController>{};
  final dropdowns = <String, String>{};
  for (final f in fields) {
    if (f.options != null) {
      final iv = initialValues?[f.key];
      dropdowns[f.key] = (iv != null && f.options!.contains(iv))
          ? iv
          : f.options!.first;
    } else {
      controllers[f.key] = TextEditingController(
        text: initialValues?[f.key] ?? '',
      );
    }
  }
  return showDialog<Map<String, String>>(
    context: context,
    builder: (dctx) {
      return StatefulBuilder(
        builder: (dctx, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final f in fields) ...[
                      if (f.options != null) ...[
                        Text(
                          f.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: dropdowns[f.key],
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _border),
                            ),
                          ),
                          items: [
                            for (final o in f.options!)
                              DropdownMenuItem(value: o, child: Text(o)),
                          ],
                          onChanged: (v) => setDialogState(
                            () => dropdowns[f.key] = v ?? dropdowns[f.key]!,
                          ),
                        ),
                      ] else
                        _SettingsField(
                          label: f.label,
                          hint: f.hint,
                          controller: controllers[f.key],
                          maxLines: f.maxLines,
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                onPressed: () {
                  final result = <String, String>{};
                  for (final f in fields) {
                    result[f.key] = f.options != null
                        ? dropdowns[f.key]!
                        : controllers[f.key]!.text.trim();
                  }
                  Navigator.of(dctx).pop(result);
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> _confirmDelete(BuildContext context, String what) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: () => Navigator.of(dctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result == true;
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
                      final submissions = await db
                          .getPaymentSubmissionsForInvoice(invoiceId);
                      final pending = submissions
                          .where((s) => s['status'] == 'pending_review')
                          .toList();
                      if (pending.isNotEmpty) {
                        await db.confirmPaymentSubmission(
                          pending.first['id'] as String,
                          invoiceId,
                        );
                      } else {
                        await db.markInvoicePaid(invoiceId);
                      }
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
class _ShipmentsPage extends StatefulWidget {
  final DatabaseService db;
  final String? partnerId;
  const _ShipmentsPage({required this.db, required this.partnerId});

  @override
  State<_ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends State<_ShipmentsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  Future<List<Map<String, dynamic>>> _fetch() => widget.partnerId != null
      ? widget.db.getShipmentsByPartner(widget.partnerId!)
      : widget.db.getShipments();

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  void _refresh() => setState(() => _future = _fetch());

  Future<void> _openNewShipmentDialog() async {
    final shipmentNumber = TextEditingController();
    final origin = TextEditingController();
    final destination = TextEditingController();
    String type = 'Air';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('New Shipment'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: shipmentNumber,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Shipment # *',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'Air', child: Text('Air')),
                      DropdownMenuItem(value: 'Sea', child: Text('Sea')),
                    ],
                    onChanged: (v) => setDialogState(() => type = v ?? 'Air'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: origin,
                    decoration: const InputDecoration(
                      labelText: 'Origin *',
                      prefixIcon: Icon(Icons.flight_takeoff),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: destination,
                    decoration: const InputDecoration(
                      labelText: 'Destination *',
                      prefixIcon: Icon(Icons.flight_land),
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
                if (shipmentNumber.text.trim().isEmpty ||
                    origin.text.trim().isEmpty ||
                    destination.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('Shipment #, origin, and destination are required')),
                  );
                  return;
                }
                try {
                  await widget.db.insertShipment({
                    'shipment_number': shipmentNumber.text.trim(),
                    'origin': origin.text.trim(),
                    'destination': destination.text.trim(),
                    'carrier': type,
                    'status': 'preparing',
                    if (widget.partnerId != null) 'partner_id': widget.partnerId,
                  });
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(content: Text('Failed to save: $e')),
                    );
                  }
                }
              },
              child: const Text('Create Shipment'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipment created')),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: 'Shipments',
      subtitle: 'Outgoing and incoming shipment manifests.',
      actions: [
        _PrimaryAction(
          label: 'New Shipment',
          icon: Icons.add,
          onTap: _openNewShipmentDialog,
        ),
      ],
      child: _futureList<Map<String, dynamic>>(
        future: _future,
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

  static String _statusLabel(dynamic status) {
    switch (status?.toString()) {
      case 'stored':
        return 'Stored';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'picked_up':
        return 'Picked Up';
      case 'scanned_in':
        return 'Scanned In';
      default:
        return _s(status);
    }
  }

  static String _location(Map<String, dynamic> e) {
    final zone = e['storage_zone']?.toString();
    final loc = e['storage_location']?.toString();
    if (zone == null || zone.isEmpty) return 'Not assigned';
    return loc == null || loc.isEmpty ? zone : '$zone / $loc';
  }

  @override
  Widget build(BuildContext context) {
    if (prefix.isEmpty) {
      return _PagePanel(
        title: 'Receivals',
        subtitle: 'Packages received into the warehouse for your account.',
        child: _DataTableCard(
          columns: const [
            'Tracking #',
            'Customer',
            'Description',
            'Weight',
            'Location',
            'Status',
            'Received',
          ],
          rows: const [],
          emptyMessage:
              'No tracking prefix is configured for this account yet — '
              'contact support to have one assigned before packages can be '
              'matched to you.',
        ),
      );
    }
    return _PagePanel(
      title: 'Receivals',
      subtitle: 'Packages received into the warehouse for your account.',
      child: _futureList<Map<String, dynamic>>(
        future: db.getWarehouseEntriesByPrefix(prefix),
        builder: (data) {
          return _DataTableCard(
            columns: const [
              'Tracking #',
              'Customer',
              'Description',
              'Weight',
              'Location',
              'Status',
              'Received',
            ],
            rows: [
              for (final e in data)
                [
                  _s(e['tracking_number']),
                  _s(e['customer_name']),
                  _s(e['description']),
                  e['weight'] == null ? '—' : '${e['weight']} lb',
                  _location(e),
                  _statusLabel(e['status']),
                  _date(e['scanned_in_at']),
                ],
            ],
            emptyMessage: 'No packages received into the warehouse yet.',
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

class _ReportsPage extends StatefulWidget {
  final DatabaseService db;
  final String? partnerId;
  const _ReportsPage({required this.db, required this.partnerId});

  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<_ReportsPage> {
  static const _reports = [
    ('daily_sales', 'Daily Sales', Icons.today, 'Today\'s revenue and package count'),
    ('customer_activity', 'Customer Activity', Icons.people, 'Top customers by volume'),
    ('outstanding_invoices', 'Outstanding Invoices', Icons.receipt_long, 'Unpaid balances'),
    ('package_aging', 'Package Aging', Icons.inventory_2, 'Time in warehouse'),
    ('manifest_summary', 'Manifest Summary', Icons.local_shipping, 'Shipments by carrier'),
    ('tax_report', 'Tax Report', Icons.account_balance, 'GCT and duty totals'),
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      final meta = _reports.firstWhere((r) => r.$1 == _selected);
      return _ReportDetailPage(
        db: widget.db,
        partnerId: widget.partnerId,
        reportKey: _selected!,
        title: meta.$2,
        onBack: () => setState(() => _selected = null),
      );
    }
    return _PagePanel(
      title: 'Reports',
      subtitle: 'Generate operational and financial reports.',
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: [
          for (final r in _reports)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selected = r.$1),
              child: Container(
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
                      child: Icon(r.$3, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.$2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.$4,
                            style: TextStyle(fontSize: 11, color: _muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: _muted, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Loads packages/customers/invoices/shipments for the partner once, then
/// renders whichever report was tapped from that shared dataset.
class _ReportDetailPage extends StatefulWidget {
  final DatabaseService db;
  final String? partnerId;
  final String reportKey;
  final String title;
  final VoidCallback onBack;
  const _ReportDetailPage({
    required this.db,
    required this.partnerId,
    required this.reportKey,
    required this.title,
    required this.onBack,
  });

  @override
  State<_ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<_ReportDetailPage> {
  late final Future<List<List<Map<String, dynamic>>>> _future;

  @override
  void initState() {
    super.initState();
    final pid = widget.partnerId;
    _future = Future.wait([
      pid != null ? widget.db.getPackagesByPartner(pid) : widget.db.getPackages(),
      pid != null ? widget.db.getCustomersByPartner(pid) : widget.db.getCustomers(),
      pid != null ? widget.db.getInvoicesByPartner(pid) : widget.db.getAllInvoices(),
      pid != null ? widget.db.getShipmentsByPartner(pid) : widget.db.getShipments(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return _PagePanel(
      title: widget.title,
      subtitle: 'Generate operational and financial reports.',
      actions: [
        OutlinedButton.icon(
          onPressed: widget.onBack,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _border),
            foregroundColor: _text,
          ),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('All Reports'),
        ),
      ],
      child: FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error loading report: ${snap.error}',
                style: const TextStyle(color: AppTheme.danger),
              ),
            );
          }
          final data = snap.data!;
          final packages = data[0];
          final customers = data[1];
          final invoices = data[2];
          final shipments = data[3];
          switch (widget.reportKey) {
            case 'daily_sales':
              return _DailySalesReport(packages: packages, invoices: invoices);
            case 'customer_activity':
              return _CustomerActivityReport(packages: packages, customers: customers);
            case 'outstanding_invoices':
              return _OutstandingInvoicesReport(invoices: invoices);
            case 'package_aging':
              return _PackageAgingReport(packages: packages);
            case 'manifest_summary':
              return _ManifestSummaryReport(shipments: shipments);
            case 'tax_report':
              return _TaxReport(packages: packages, invoices: invoices);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

bool _isToday(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '');
  if (d == null) return false;
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

class _ReportStatRow extends StatelessWidget {
  final List<Widget> cards;
  const _ReportStatRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _DailySalesReport extends StatelessWidget {
  final List<Map<String, dynamic>> packages;
  final List<Map<String, dynamic>> invoices;
  const _DailySalesReport({required this.packages, required this.invoices});

  @override
  Widget build(BuildContext context) {
    final todayInvoices = invoices.where((i) => _isToday(i['created_at'])).toList();
    final invoicedToday = todayInvoices.fold(0.0, (s, i) => s + _num(i['total']));
    final collectedToday = todayInvoices
        .where((i) => i['status']?.toString() == 'paid')
        .fold(0.0, (s, i) => s + _num(i['total']));
    final packagesToday = packages.where((p) => _isToday(p['created_at'])).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReportStatRow(
            cards: [
              _StatCard(
                icon: Icons.receipt_long,
                tileColor: AppTheme.accent.withValues(alpha: 0.12),
                iconColor: AppTheme.accent,
                value: _money(invoicedToday),
                label: 'Invoiced Today',
                sub: '${todayInvoices.length} invoice(s)',
              ),
              _StatCard(
                icon: Icons.check_circle_outline,
                tileColor: AppTheme.success.withValues(alpha: 0.12),
                iconColor: AppTheme.success,
                value: _money(collectedToday),
                label: 'Collected Today',
                sub: 'Paid invoices only',
              ),
              _StatCard(
                icon: Icons.inventory_2_outlined,
                tileColor: AppTheme.primary.withValues(alpha: 0.08),
                iconColor: AppTheme.primary,
                value: '$packagesToday',
                label: 'Packages Today',
                sub: 'Received today',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DataTableCard(
            columns: const ['Invoice #', 'Customer', 'Amount', 'Status'],
            rows: [
              for (final i in todayInvoices)
                [
                  _s(i['invoice_number']),
                  _s(i['customer_name']),
                  _money(i['total']),
                  _s(i['status']),
                ],
            ],
            emptyMessage: 'No invoices created today.',
          ),
        ],
      ),
    );
  }
}

class _CustomerActivityReport extends StatelessWidget {
  final List<Map<String, dynamic>> packages;
  final List<Map<String, dynamic>> customers;
  const _CustomerActivityReport({required this.packages, required this.customers});

  @override
  Widget build(BuildContext context) {
    final pkgCount = <String, int>{};
    final pkgValue = <String, double>{};
    for (final p in packages) {
      final cid = p['customer_id']?.toString();
      if (cid == null) continue;
      pkgCount[cid] = (pkgCount[cid] ?? 0) + 1;
      pkgValue[cid] = (pkgValue[cid] ?? 0) + _num(p['declared_value']);
    }
    final ranked = [...customers]..sort(
      (a, b) => (pkgCount[b['id']?.toString()] ?? 0).compareTo(
        pkgCount[a['id']?.toString()] ?? 0,
      ),
    );
    return _DataTableCard(
      columns: const ['Customer', 'Email', 'Packages', 'Total Value'],
      rows: [
        for (final c in ranked)
          [
            _s(c['name']),
            _s(c['email']),
            '${pkgCount[c['id']?.toString()] ?? 0}',
            _money(pkgValue[c['id']?.toString()] ?? 0),
          ],
      ],
      emptyMessage: 'No customers yet.',
    );
  }
}

class _OutstandingInvoicesReport extends StatelessWidget {
  final List<Map<String, dynamic>> invoices;
  const _OutstandingInvoicesReport({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final outstanding = invoices.where((i) => i['status']?.toString() != 'paid').toList();
    final total = outstanding.fold(0.0, (s, i) => s + _num(i['total']));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReportStatRow(
            cards: [
              _StatCard(
                icon: Icons.hourglass_bottom,
                tileColor: AppTheme.warning.withValues(alpha: 0.12),
                iconColor: AppTheme.warning,
                value: _money(total),
                label: 'Total Outstanding',
                sub: '${outstanding.length} unpaid invoice(s)',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DataTableCard(
            columns: const ['Invoice #', 'Customer', 'Amount', 'Status', 'Due Date'],
            rows: [
              for (final i in outstanding)
                [
                  _s(i['invoice_number']),
                  _s(i['customer_name']),
                  _money(i['total']),
                  _s(i['status']),
                  i['due_date'] == null ? 'No due date' : _date(i['due_date']),
                ],
            ],
            emptyMessage: 'No outstanding invoices — everything is paid up.',
          ),
        ],
      ),
    );
  }
}

class _PackageAgingReport extends StatelessWidget {
  final List<Map<String, dynamic>> packages;
  const _PackageAgingReport({required this.packages});

  // 'picked_up' is the value actually used in this database for a
  // collected package; 'delivered'/'exception'/'returned' are also handled
  // in case future data uses those instead.
  static const _terminalStatuses = {
    'delivered',
    'exception',
    'returned',
    'picked_up',
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final aging = packages
        .where((p) => !_terminalStatuses.contains(p['status']?.toString()))
        .map((p) {
          final created = DateTime.tryParse(p['created_at']?.toString() ?? '');
          final days = created == null ? 0 : now.difference(created).inDays;
          return (p, days);
        })
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    return _DataTableCard(
      columns: const ['Tracking #', 'Customer', 'Status', 'Days in Warehouse'],
      rows: [
        for (final (p, days) in aging)
          [_s(p['tracking_number']), _s(p['customer_name']), _s(p['status']), '$days'],
      ],
      emptyMessage: 'No packages currently in the warehouse.',
    );
  }
}

class _ManifestSummaryReport extends StatelessWidget {
  final List<Map<String, dynamic>> shipments;
  const _ManifestSummaryReport({required this.shipments});

  @override
  Widget build(BuildContext context) {
    final byCarrier = <String, List<Map<String, dynamic>>>{};
    for (final s in shipments) {
      final carrier = (s['carrier']?.toString().trim().isNotEmpty ?? false)
          ? s['carrier'].toString()
          : (s['vessel_name']?.toString() ??
                s['flight_number']?.toString() ??
                'Unspecified');
      byCarrier.putIfAbsent(carrier, () => []).add(s);
    }
    return _DataTableCard(
      columns: const ['Carrier', 'Shipments', 'Total Packages', 'Total Weight'],
      rows: [
        for (final entry in byCarrier.entries)
          [
            entry.key,
            '${entry.value.length}',
            '${entry.value.fold(0, (s, x) => s + (int.tryParse(x['total_packages']?.toString() ?? '0') ?? 0))}',
            '${entry.value.fold(0.0, (s, x) => s + _num(x['total_weight'])).toStringAsFixed(1)} lb',
          ],
      ],
      emptyMessage: 'No shipments recorded yet.',
    );
  }
}

class _TaxReport extends StatelessWidget {
  final List<Map<String, dynamic>> packages;
  final List<Map<String, dynamic>> invoices;
  const _TaxReport({required this.packages, required this.invoices});

  @override
  Widget build(BuildContext context) {
    final totalGct = invoices.fold(0.0, (s, i) => s + _num(i['tax']));
    final totalDeclaredValue = packages.fold(0.0, (s, p) => s + _num(p['declared_value']));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReportStatRow(
            cards: [
              _StatCard(
                icon: Icons.account_balance_outlined,
                tileColor: AppTheme.primary.withValues(alpha: 0.08),
                iconColor: AppTheme.primary,
                value: _money(totalGct),
                label: 'GCT Collected',
                sub: 'Sum of tax across all invoices',
              ),
              _StatCard(
                icon: Icons.inventory_2_outlined,
                tileColor: AppTheme.accent.withValues(alpha: 0.12),
                iconColor: AppTheme.accent,
                value: _money(totalDeclaredValue),
                label: 'Total Declared Value',
                sub: 'Across all packages',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Customs duty isn\'t tracked as its own figure yet, so it isn\'t '
                    'included above. GCT is the real total collected via invoice tax; '
                    'declared value is shown as the reference figure duty would be '
                    'calculated from.',
                    style: TextStyle(fontSize: 12, color: _textSoft),
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
    final partnerId = account['id']?.toString();
    switch (title) {
      case 'Company':
        return _CompanyProfileTab(account: account);
      case 'Customization':
        return _BrandingTab(account: account);
      case 'User Management':
        return _UserManagementTab(account: account);
      case 'Currency':
        return _TaxCurrencyTab(account: account);
      case 'Online Payment Gateway':
        return const _IntegrationsTab();
      case 'Api Sync':
      case 'Api Sync Legacy':
      case 'Webhooks':
        return _ApiKeysTab(account: account);
      case 'Subscription':
        return _SubscriptionBody(account: account);
      case 'Roles and Permissions':
        return _RolesBody(partnerId: partnerId);
      case 'Locations':
        return _LocationsBody(partnerId: partnerId);
      case 'Charges':
        return _ChargesBody(partnerId: partnerId);
      case 'Discounts':
        return _DiscountsBody(partnerId: partnerId);
      case 'Storage Fee':
        return _StorageFeeBody(account: account);
      case 'Terms and Conditions':
        return _TermsBody(account: account);
      case 'Shipping Addresses':
        return _ShippingAddressesBody(partnerId: partnerId);
      case 'Rate Calculator':
        return _RateCalcBody(account: account);
    }
    return Center(
      child: Text('$title coming soon', style: TextStyle(color: _muted)),
    );
  }
}

class _SubscriptionBody extends StatefulWidget {
  final Map<String, dynamic> account;
  const _SubscriptionBody({required this.account});
  @override
  State<_SubscriptionBody> createState() => _SubscriptionBodyState();
}

class _SubscriptionBodyState extends State<_SubscriptionBody> {
  final _db = DatabaseService();
  bool _busy = false;

  String get _planLabel {
    switch (widget.account['plan'] as String?) {
      case 'courier':
        return 'Courier Platform';
      case 'warehouse':
        return 'Warehouse Platform';
      case 'direct':
        return 'Direct Account';
      default:
        return 'No plan set';
    }
  }

  void _showPlanInfo() {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Your Plan'),
        content: const Text(
          'Every partner account includes the full platform — customer '
          'portal, apps, tracking, invoicing, POS, and more. There are no '
          'other tiers to switch between today. No billing is set up on '
          'this account, so nothing here is being charged.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoices() async {
    final partnerId = widget.account['id']?.toString();
    if (partnerId == null) return;
    setState(() => _busy = true);
    try {
      final invoices = await _db.getInvoicesByPartner(partnerId);
      if (!mounted) return;
      ExportService.downloadCsv(
        filename: 'invoices.csv',
        headers: const [
          'Invoice #',
          'Customer',
          'Amount',
          'Status',
          'Created',
          'Paid',
        ],
        rows: [
          for (final i in invoices)
            [
              _s(i['invoice_number'] ?? i['id']),
              _s(i['customer_name'] ?? i['customer']),
              _money(i['total'] ?? i['amount']),
              _s(i['status']),
              _date(i['created_at']),
              _date(i['paid_at']),
            ],
        ],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Downloaded ${invoices.length} invoice${invoices.length == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                colors: [AppTheme.primary, AppTheme.secondaryNavy],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _planLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Full feature set included — no tiers to upgrade '
                        'between.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
                  label: 'Billing',
                  value: 'Not set up',
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Payment method',
                  value: 'None on file',
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
                onPressed: _showPlanInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Plan Details'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _downloadInvoices,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _text,
                  side: const BorderSide(color: _border),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Download Invoices'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RolesBody extends StatefulWidget {
  final String? partnerId;
  const _RolesBody({required this.partnerId});
  @override
  State<_RolesBody> createState() => _RolesBodyState();
}

class _RolesBodyState extends State<_RolesBody> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;

  static const _permissionOptions = [
    'Manage operations',
    'Manage staff',
    'View reports',
    'Manage customers',
    'Process sales',
    'Process receivals',
    'View-only dashboard access',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.partnerId == null) {
      setState(() => _loading = false);
      return;
    }
    final roles = await _db.getPartnerRoles(widget.partnerId!);
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _loading = false;
    });
  }

  Future<void> _addRole() async {
    final result = await _showFormDialog(
      context,
      title: 'New Role',
      fields: const [
        _FormField('name', 'Role Name', hint: 'e.g. Supervisor'),
        _FormField(
          'description',
          'Description',
          hint: 'What this role can do',
          maxLines: 2,
        ),
      ],
      confirmLabel: 'Add',
    );
    if (result == null || result['name']!.isEmpty || widget.partnerId == null) {
      return;
    }
    await _db.insertPartnerRole({
      'partner_id': widget.partnerId,
      'name': result['name'],
      'description': result['description'],
    });
    _load();
  }

  Future<void> _editPermissions(Map<String, dynamic> role) async {
    final current =
        (role['permissions'] as List?)?.cast<String>().toSet() ?? <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setDialogState) {
            return AlertDialog(
              title: Text('Permissions — ${role['name']}'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in _permissionOptions)
                      CheckboxListTile(
                        dense: true,
                        value: current.contains(p),
                        title: Text(p, style: const TextStyle(fontSize: 13)),
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            current.add(p);
                          } else {
                            current.remove(p);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  onPressed: () => Navigator.of(dctx).pop(current),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    await _db.updatePartnerRole(role['id'] as String, {
      'permissions': result.toList(),
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                onPressed: _addRole,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Permissions are saved for reference. Your team logs in with '
            'one shared account today, so these aren\'t enforced per-login '
            'yet.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _roles.isEmpty
              ? Center(
                  child: Text(
                    'No custom roles yet.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _roles[i];
                    final perms =
                        (r['permissions'] as List?)?.cast<String>() ??
                        const [];
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
                                  _s(r['name']),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                                Text(
                                  perms.isEmpty
                                      ? _s(r['description'])
                                      : '${_s(r['description'])} · ${perms.length} permission${perms.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _editPermissions(r),
                            child: const Text('Edit Permissions'),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: _muted,
                            ),
                            onPressed: () async {
                              if (!await _confirmDelete(
                                context,
                                'role "${r['name']}"',
                              )) {
                                return;
                              }
                              await _db.deletePartnerRole(r['id'] as String);
                              _load();
                            },
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

class _LocationsBody extends StatefulWidget {
  final String? partnerId;
  const _LocationsBody({required this.partnerId});
  @override
  State<_LocationsBody> createState() => _LocationsBodyState();
}

class _LocationsBodyState extends State<_LocationsBody> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _locs = [];
  bool _loading = true;
  static const _types = ['Warehouse', 'Store', 'Pickup'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.partnerId == null) {
      setState(() => _loading = false);
      return;
    }
    final locs = await _db.getPartnerLocations(widget.partnerId!);
    if (!mounted) return;
    setState(() {
      _locs = locs;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final result = await _showFormDialog(
      context,
      title: 'Add Location',
      fields: const [
        _FormField('name', 'Name', hint: 'e.g. Kingston HQ'),
        _FormField('address', 'Address', hint: 'Street, city'),
        _FormField('type', 'Type', options: _types),
      ],
      confirmLabel: 'Add',
    );
    if (result == null || result['name']!.isEmpty || widget.partnerId == null) {
      return;
    }
    await _db.insertPartnerLocation({
      'partner_id': widget.partnerId,
      'name': result['name'],
      'address': result['address'],
      'type': result['type'],
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                onPressed: _add,
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
          child: _locs.isEmpty
              ? Center(
                  child: Text(
                    'No locations added yet.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _locs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final l = _locs[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _s(l['name']),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                                Text(
                                  _s(l['address']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
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
                              _s(l['type']),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: _muted,
                            ),
                            onPressed: () async {
                              if (!await _confirmDelete(
                                context,
                                'location "${l['name']}"',
                              )) {
                                return;
                              }
                              await _db.deletePartnerLocation(l['id'] as String);
                              _load();
                            },
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

class _ChargesBody extends StatefulWidget {
  final String? partnerId;
  const _ChargesBody({required this.partnerId});
  @override
  State<_ChargesBody> createState() => _ChargesBodyState();
}

class _ChargesBodyState extends State<_ChargesBody> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _charges = [];
  bool _loading = true;
  static const _amountTypes = ['fixed', 'percent'];
  static const _units = ['Per package', 'Per shipment', 'Per request'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.partnerId == null) {
      setState(() => _loading = false);
      return;
    }
    final charges = await _db.getPartnerCharges(widget.partnerId!);
    if (!mounted) return;
    setState(() {
      _charges = charges;
      _loading = false;
    });
  }

  String _label(Map<String, dynamic> c) {
    final amount = double.tryParse(c['amount']?.toString() ?? '') ?? 0;
    return c['amount_type'] == 'percent'
        ? '${amount.toStringAsFixed(1)}% of value'
        : '\$${amount.toStringAsFixed(2)} USD';
  }

  Future<void> _addOrEdit({Map<String, dynamic>? existing}) async {
    final result = await _showFormDialog(
      context,
      title: existing == null ? 'Add Charge' : 'Edit Charge',
      fields: const [
        _FormField('name', 'Name', hint: 'e.g. Customs Handling'),
        _FormField('amount', 'Amount', hint: 'e.g. 5.00'),
        _FormField('amount_type', 'Type', options: _amountTypes),
        _FormField('unit', 'Applies', options: _units),
      ],
      initialValues: existing == null
          ? null
          : {
              'name': _s(existing['name']),
              'amount': existing['amount']?.toString() ?? '0',
              'amount_type': _s(existing['amount_type']),
              'unit': _s(existing['unit']),
            },
      confirmLabel: existing == null ? 'Add' : 'Save',
    );
    if (result == null || result['name']!.isEmpty) return;
    final row = {
      'name': result['name'],
      'amount': double.tryParse(result['amount'] ?? '') ?? 0,
      'amount_type': result['amount_type'],
      'unit': result['unit'],
    };
    if (existing == null) {
      if (widget.partnerId == null) return;
      await _db.insertPartnerCharge({
        ...row,
        'partner_id': widget.partnerId,
      });
    } else {
      await _db.updatePartnerCharge(existing['id'] as String, row);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                onPressed: () => _addOrEdit(),
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
          child: _charges.isEmpty
              ? Center(
                  child: Text(
                    'No custom charges yet.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _charges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = _charges[i];
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
                              _s(c['name']),
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
                              _label(c),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _s(c['unit']),
                              style: TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _addOrEdit(existing: c),
                            icon: const Icon(
                              Icons.edit,
                              size: 16,
                              color: _muted,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (!await _confirmDelete(
                                context,
                                'charge "${c['name']}"',
                              )) {
                                return;
                              }
                              await _db.deletePartnerCharge(c['id'] as String);
                              _load();
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
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

class _DiscountsBody extends StatefulWidget {
  final String? partnerId;
  const _DiscountsBody({required this.partnerId});
  @override
  State<_DiscountsBody> createState() => _DiscountsBodyState();
}

class _DiscountsBodyState extends State<_DiscountsBody> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _codes = [];
  bool _loading = true;
  static const _statuses = ['active', 'paused'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.partnerId == null) {
      setState(() => _loading = false);
      return;
    }
    final codes = await _db.getPartnerDiscounts(widget.partnerId!);
    if (!mounted) return;
    setState(() {
      _codes = codes;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final result = await _showFormDialog(
      context,
      title: 'New Promo Code',
      fields: const [
        _FormField('code', 'Code', hint: 'e.g. SPRING20'),
        _FormField('description', 'Description', hint: 'e.g. 20% off'),
        _FormField('status', 'Status', options: _statuses),
        _FormField(
          'expires_at',
          'Expires (YYYY-MM-DD)',
          hint: 'Leave blank for no expiry',
        ),
      ],
      confirmLabel: 'Add',
    );
    if (result == null || result['code']!.isEmpty || widget.partnerId == null) {
      return;
    }
    await _db.insertPartnerDiscount({
      'partner_id': widget.partnerId,
      'code': result['code']!.toUpperCase(),
      'description': result['description'],
      'status': result['status'],
      'expires_at': (result['expires_at']?.isEmpty ?? true)
          ? null
          : result['expires_at'],
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                onPressed: _add,
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
          child: _codes.isEmpty
              ? Center(
                  child: Text(
                    'No promo codes yet.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _codes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = _codes[i];
                    final active = d['status'] == 'active';
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
                              _s(d['code']),
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
                              _s(d['description']),
                              style: const TextStyle(
                                fontSize: 13,
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
                              color: (active
                                      ? AppTheme.success
                                      : AppTheme.warning)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              active ? 'Active' : 'Paused',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? AppTheme.success
                                    : AppTheme.warning,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            d['expires_at'] == null
                                ? 'No expiry'
                                : 'Expires ${_date(d['expires_at'])}',
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (!await _confirmDelete(
                                context,
                                'code "${d['code']}"',
                              )) {
                                return;
                              }
                              await _db.deletePartnerDiscount(
                                d['id'] as String,
                              );
                              _load();
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
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

class _StorageFeeBody extends StatefulWidget {
  final Map<String, dynamic> account;
  const _StorageFeeBody({required this.account});
  @override
  State<_StorageFeeBody> createState() => _StorageFeeBodyState();
}

class _StorageFeeBodyState extends State<_StorageFeeBody> {
  final _db = DatabaseService();
  late final Map<String, dynamic> _settings = Map<String, dynamic>.from(
    widget.account['settings'] as Map? ?? {},
  );
  late bool _enabled = _settings['storage_fee_enabled'] as bool? ?? true;
  late bool _notify = _settings['storage_fee_notify'] as bool? ?? true;
  late final _graceCtl = TextEditingController(
    text: (_settings['storage_fee_grace_days'] ?? 7).toString(),
  );
  late final _rateCtl = TextEditingController(
    text: (_settings['storage_fee_daily_rate'] ?? 1.00).toString(),
  );
  late final _maxCtl = TextEditingController(
    text: (_settings['storage_fee_max'] ?? 50.00).toString(),
  );
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updatePartnerSettings(widget.account['id'] as String, {
        'storage_fee_enabled': _enabled,
        'storage_fee_notify': _notify,
        'storage_fee_grace_days': int.tryParse(_graceCtl.text) ?? 7,
        'storage_fee_daily_rate': double.tryParse(_rateCtl.text) ?? 1.00,
        'storage_fee_max': double.tryParse(_maxCtl.text) ?? 50.00,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Storage fee settings saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
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
                _ToggleRow(
                  title: 'Enable automatic storage fees',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                const SizedBox(height: 12),
                _SettingsField(
                  label: 'Grace Period (days)',
                  controller: _graceCtl,
                  icon: Icons.hourglass_top,
                ),
                const SizedBox(height: 12),
                _SettingsField(
                  label: 'Daily Storage Rate (USD)',
                  controller: _rateCtl,
                  icon: Icons.attach_money,
                ),
                const SizedBox(height: 12),
                _SettingsField(
                  label: 'Maximum Storage Fee (USD)',
                  controller: _maxCtl,
                  icon: Icons.money_off,
                ),
                const SizedBox(height: 12),
                _ToggleRow(
                  title: 'Notify customer when fees begin accruing',
                  value: _notify,
                  onChanged: (v) => setState(() => _notify = v),
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

class _TermsBody extends StatefulWidget {
  final Map<String, dynamic> account;
  const _TermsBody({required this.account});
  @override
  State<_TermsBody> createState() => _TermsBodyState();
}

class _TermsBodyState extends State<_TermsBody> {
  final _db = DatabaseService();
  static const _defaultTerms =
      '1. Acceptance of Terms\n\nBy registering for an account, you agree '
      'to be bound by these terms.\n\n2. Services\n\nWe provide courier and '
      'warehousing services subject to availability.\n\n3. Liability\n\nOur '
      'liability is limited to the declared value of the package.\n\n'
      '4. Privacy\n\nYour personal information is handled per our privacy '
      'policy.';
  late final Map<String, dynamic> _settings = Map<String, dynamic>.from(
    widget.account['settings'] as Map? ?? {},
  );
  late final _termsCtl = TextEditingController(
    text: (_settings['terms_text'] as String?) ?? _defaultTerms,
  );
  late bool _requireAccept = _settings['terms_require_accept'] as bool? ?? true;
  late bool _requireReaccept =
      _settings['terms_require_reaccept'] as bool? ?? true;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updatePartnerSettings(widget.account['id'] as String, {
        'terms_text': _termsCtl.text,
        'terms_require_accept': _requireAccept,
        'terms_require_reaccept': _requireReaccept,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Terms saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
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
                _SettingsField(
                  label: 'Terms & Conditions',
                  controller: _termsCtl,
                  maxLines: 14,
                ),
                const SizedBox(height: 12),
                _ToggleRow(
                  title: 'Require customer to accept on sign up',
                  value: _requireAccept,
                  onChanged: (v) => setState(() => _requireAccept = v),
                ),
                const SizedBox(height: 4),
                _ToggleRow(
                  title: 'Require re-acceptance when terms change',
                  value: _requireReaccept,
                  onChanged: (v) => setState(() => _requireReaccept = v),
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

class _ShippingAddressesBody extends StatefulWidget {
  final String? partnerId;
  const _ShippingAddressesBody({required this.partnerId});
  @override
  State<_ShippingAddressesBody> createState() =>
      _ShippingAddressesBodyState();
}

class _ShippingAddressesBodyState extends State<_ShippingAddressesBody> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.partnerId == null) {
      setState(() => _loading = false);
      return;
    }
    final addresses = await _db.getPartnerShippingAddresses(
      widget.partnerId!,
    );
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({Map<String, dynamic>? existing}) async {
    final result = await _showFormDialog(
      context,
      title: existing == null ? 'Add Address' : 'Edit Address',
      fields: const [
        _FormField('label', 'Label', hint: 'e.g. Miami Hub — US'),
        _FormField('address', 'Address', hint: 'Street, city, postal, country', maxLines: 2),
      ],
      initialValues: existing == null
          ? null
          : {
              'label': _s(existing['label']),
              'address': _s(existing['address']),
            },
      confirmLabel: existing == null ? 'Add' : 'Save',
    );
    if (result == null || result['label']!.isEmpty) return;
    if (existing == null) {
      if (widget.partnerId == null) return;
      await _db.insertPartnerShippingAddress({
        'partner_id': widget.partnerId,
        'label': result['label'],
        'address': result['address'],
      });
    } else {
      await _db.updatePartnerShippingAddress(existing['id'] as String, {
        'label': result['label'],
        'address': result['address'],
      });
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                onPressed: () => _addOrEdit(),
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
          child: _addresses.isEmpty
              ? Center(
                  child: Text(
                    'No shipping addresses added yet.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = _addresses[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _s(a['label']),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                                Text(
                                  _s(a['address']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _addOrEdit(existing: a),
                            icon: const Icon(
                              Icons.edit,
                              size: 16,
                              color: _muted,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (!await _confirmDelete(
                                context,
                                'address "${a['label']}"',
                              )) {
                                return;
                              }
                              await _db.deletePartnerShippingAddress(
                                a['id'] as String,
                              );
                              _load();
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
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

class _RateCalcBody extends StatefulWidget {
  final Map<String, dynamic> account;
  const _RateCalcBody({required this.account});
  @override
  State<_RateCalcBody> createState() => _RateCalcBodyState();
}

class _RateCalcBodyState extends State<_RateCalcBody> {
  final _db = DatabaseService();
  late final Map<String, dynamic> _settings = Map<String, dynamic>.from(
    widget.account['settings'] as Map? ?? {},
  );
  late final _airCtl = TextEditingController(
    text: (_settings['rate_air_per_lb'] ?? 4.50).toString(),
  );
  late final _seaCtl = TextEditingController(
    text: (_settings['rate_sea_per_lb'] ?? 2.25).toString(),
  );
  late final _dutyCtl = TextEditingController(
    text: (_settings['rate_duty_percent'] ?? 20.0).toString(),
  );
  late bool _volumetric = _settings['rate_use_volumetric'] as bool? ?? true;
  late bool _roundUp = _settings['rate_round_up_half'] as bool? ?? true;
  late bool _fuelSurcharge =
      _settings['rate_fuel_surcharge'] as bool? ?? false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updatePartnerSettings(widget.account['id'] as String, {
        'rate_air_per_lb': double.tryParse(_airCtl.text) ?? 4.50,
        'rate_sea_per_lb': double.tryParse(_seaCtl.text) ?? 2.25,
        'rate_duty_percent': double.tryParse(_dutyCtl.text) ?? 20.0,
        'rate_use_volumetric': _volumetric,
        'rate_round_up_half': _roundUp,
        'rate_fuel_surcharge': _fuelSurcharge,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rate settings saved — used by Quick Quote'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
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
                const Text(
                  'These rates power the "Quick Quote" tool in the top bar.',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsField(
                        label: 'Air Freight (\$ / lb)',
                        controller: _airCtl,
                        icon: Icons.flight_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Sea Freight (\$ / lb)',
                        controller: _seaCtl,
                        icon: Icons.directions_boat_filled_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsField(
                  label: 'Customs Duty (% of declared value)',
                  controller: _dutyCtl,
                  icon: Icons.percent,
                ),
                const SizedBox(height: 16),
                _ToggleRow(
                  title: 'Use volumetric weight when higher',
                  value: _volumetric,
                  onChanged: (v) => setState(() => _volumetric = v),
                ),
                _ToggleRow(
                  title: 'Round up to nearest 0.5 lb',
                  value: _roundUp,
                  onChanged: (v) => setState(() => _roundUp = v),
                ),
                _ToggleRow(
                  title: 'Apply fuel surcharge automatically',
                  value: _fuelSurcharge,
                  onChanged: (v) => setState(() => _fuelSurcharge = v),
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
  final VoidCallback onSave;
  final bool saving;
  const _SettingsSaveBar({required this.onSave, this.saving = false});
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
          ElevatedButton(
            onPressed: saving ? null : onSave,
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

class _BrandingTab extends StatefulWidget {
  final Map<String, dynamic> account;
  const _BrandingTab({required this.account});
  @override
  State<_BrandingTab> createState() => _BrandingTabState();
}

class _BrandingTabState extends State<_BrandingTab> {
  final _db = DatabaseService();
  static const _swatches = [
    0xFF071B33,
    0xFFCC0000,
    0xFF6366F1,
    0xFF10B981,
    0xFFF59E0B,
    0xFFEC4899,
    0xFF0EA5E9,
    0xFF111827,
  ];
  late final Map<String, dynamic> _settings = Map<String, dynamic>.from(
    widget.account['settings'] as Map? ?? {},
  );
  late int _selectedColor =
      (_settings['branding_color'] as num?)?.toInt() ?? 0xFF071B33;
  late final _titleCtl = TextEditingController(
    text:
        (_settings['branding_portal_title'] as String?) ??
        'Welcome to your courier portal',
  );
  late final _senderCtl = TextEditingController(
    text:
        (_settings['branding_email_sender'] as String?) ??
        'One Village Shipping & Freight',
  );
  late final _footerCtl = TextEditingController(
    text:
        (_settings['branding_email_footer'] as String?) ??
        'Thank you for choosing us.',
  );
  late bool _showInEmails =
      _settings['branding_show_in_emails'] as bool? ?? true;
  late bool _allowPdfDownload =
      _settings['branding_allow_pdf_download'] as bool? ?? true;
  late bool _darkMode = _settings['branding_dark_mode'] as bool? ?? false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updatePartnerSettings(widget.account['id'] as String, {
        'branding_color': _selectedColor,
        'branding_portal_title': _titleCtl.text.trim(),
        'branding_email_sender': _senderCtl.text.trim(),
        'branding_email_footer': _footerCtl.text.trim(),
        'branding_show_in_emails': _showInEmails,
        'branding_allow_pdf_download': _allowPdfDownload,
        'branding_dark_mode': _darkMode,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Branding saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
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
                    for (final c in _swatches)
                      InkWell(
                        onTap: () => setState(() => _selectedColor = c),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(c),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedColor == c ? _text : _border,
                              width: _selectedColor == c ? 2 : 1,
                            ),
                          ),
                          child: _selectedColor == c
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsField(
                  label: 'Customer Portal Title',
                  controller: _titleCtl,
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Email Sender Name',
                  controller: _senderCtl,
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Email Footer',
                  controller: _footerCtl,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _ToggleRow(
                  title: 'Show partner branding in customer emails',
                  value: _showInEmails,
                  onChanged: (v) => setState(() => _showInEmails = v),
                ),
                _ToggleRow(
                  title: 'Allow customers to download invoice PDFs',
                  value: _allowPdfDownload,
                  onChanged: (v) => setState(() => _allowPdfDownload = v),
                ),
                _ToggleRow(
                  title: 'Use dark mode in customer portal',
                  value: _darkMode,
                  onChanged: (v) => setState(() => _darkMode = v),
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

class _TaxCurrencyTab extends StatefulWidget {
  final Map<String, dynamic> account;
  const _TaxCurrencyTab({required this.account});
  @override
  State<_TaxCurrencyTab> createState() => _TaxCurrencyTabState();
}

class _TaxCurrencyTabState extends State<_TaxCurrencyTab> {
  final _db = DatabaseService();
  late final Map<String, dynamic> _settings = Map<String, dynamic>.from(
    widget.account['settings'] as Map? ?? {},
  );
  late final _primaryCtl = TextEditingController(
    text:
        (_settings['currency_primary'] as String?) ?? 'JMD — Jamaican Dollar',
  );
  late final _secondaryCtl = TextEditingController(
    text: (_settings['currency_secondary'] as String?) ?? 'USD — US Dollar',
  );
  late final _gctCtl = TextEditingController(
    text: (_settings['gct_rate'] ?? 15.0).toString(),
  );
  late final _dutyCtl = TextEditingController(
    text: (_settings['rate_duty_percent'] ?? 20.0).toString(),
  );
  late final _levyCtl = TextEditingController(
    text: (_settings['environmental_levy'] ?? 0.5).toString(),
  );
  late final _shippingRateCtl = TextEditingController(
    text: (_settings['rate_sea_per_lb'] ?? 2.25).toString(),
  );
  late bool _applyGctToShipping =
      _settings['apply_gct_to_shipping'] as bool? ?? true;
  late bool _showInclusive = _settings['show_prices_inclusive'] as bool? ?? false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updatePartnerSettings(widget.account['id'] as String, {
        'currency_primary': _primaryCtl.text.trim(),
        'currency_secondary': _secondaryCtl.text.trim(),
        'gct_rate': double.tryParse(_gctCtl.text) ?? 15.0,
        'rate_duty_percent': double.tryParse(_dutyCtl.text) ?? 20.0,
        'environmental_levy': double.tryParse(_levyCtl.text) ?? 0.5,
        'rate_sea_per_lb': double.tryParse(_shippingRateCtl.text) ?? 2.25,
        'apply_gct_to_shipping': _applyGctToShipping,
        'show_prices_inclusive': _showInclusive,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Currency & tax settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
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
                    Expanded(
                      child: _SettingsField(
                        label: 'Default Currency',
                        controller: _primaryCtl,
                        icon: Icons.attach_money,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Secondary Currency',
                        controller: _secondaryCtl,
                        icon: Icons.attach_money,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsField(
                        label: 'GCT Rate (%)',
                        controller: _gctCtl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Customs Duty Rate (%)',
                        controller: _dutyCtl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsField(
                        label: 'Environmental Levy (%)',
                        controller: _levyCtl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Default Shipping Rate (\$ / lb)',
                  controller: _shippingRateCtl,
                ),
                const SizedBox(height: 16),
                _ToggleRow(
                  title: 'Apply GCT to shipping fees',
                  value: _applyGctToShipping,
                  onChanged: (v) => setState(() => _applyGctToShipping = v),
                ),
                _ToggleRow(
                  title: 'Show prices inclusive of tax',
                  value: _showInclusive,
                  onChanged: (v) => setState(() => _showInclusive = v),
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

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab();

  static const _items = [
    ('Stripe', 'Payment processing', Icons.credit_card),
    ('PayPal', 'Alternate payments', Icons.account_balance_wallet),
    ('DHL', 'Shipping carrier', Icons.local_shipping),
    ('FedEx', 'Shipping carrier', Icons.local_shipping),
    ('Twilio', 'SMS notifications', Icons.sms),
    ('SendGrid', 'Transactional email', Icons.mail),
    ('QuickBooks', 'Accounting sync', Icons.account_balance),
    ('Zapier', 'Workflow automations', Icons.bolt),
  ];

  void _showNotAvailable(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('$name — not connected'),
        content: Text(
          'This integration isn\'t available yet — it needs real $name API '
          'credentials to connect, which haven\'t been set up for this '
          'account. No live connection exists today, so nothing here is '
          'processing real payments, carriers, messages, or data.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.warning, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'None of these are connected yet. Adding one requires '
                    'real credentials from that provider.',
                    style: TextStyle(fontSize: 12, color: _textSoft),
                  ),
                ),
              ],
            ),
          ),
          for (final i in _items)
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
                  OutlinedButton(
                    onPressed: () => _showNotAvailable(context, i.$1),
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

class _UserManagementTab extends StatefulWidget {
  final Map<String, dynamic> account;
  const _UserManagementTab({required this.account});
  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  static const _roleOptions = ['Admin', 'Manager', 'Cashier', 'Read-only'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final partnerId = widget.account['id']?.toString();
    if (partnerId == null) {
      setState(() => _loading = false);
      return;
    }
    final staff = await _db.getPartnerStaff(partnerId);
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _loading = false;
    });
  }

  Future<void> _invite() async {
    final result = await _showFormDialog(
      context,
      title: 'Invite User',
      fields: const [
        _FormField('name', 'Name', hint: 'Full name'),
        _FormField('email', 'Email', hint: 'name@example.com'),
        _FormField('role', 'Role', options: _roleOptions),
      ],
      confirmLabel: 'Invite',
    );
    if (result == null ||
        result['name']!.isEmpty ||
        result['email']!.isEmpty) {
      return;
    }
    final partnerId = widget.account['id']?.toString();
    if (partnerId == null) return;
    await _db.insertPartnerStaff({
      'partner_id': partnerId,
      'name': result['name'],
      'email': result['email'],
      'role': result['role'],
      'status': 'invited',
    });
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result['name']} added as a pending team member. Separate '
          'staff logins aren\'t wired up yet — share your account login '
          'directly for now.',
        ),
      ),
    );
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'Admin':
        return AppTheme.success;
      case 'Manager':
        return AppTheme.accent;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final ownerName = (widget.account['contact_name'] as String?)?.trim();
    final ownerEmail = (widget.account['email'] as String?) ?? '';
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
                onPressed: _invite,
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _UserRow(
                name: (ownerName?.isNotEmpty ?? false)
                    ? ownerName!
                    : 'Owner Account',
                email: ownerEmail,
                role: 'Owner',
                color: AppTheme.primary,
              ),
              const SizedBox(height: 8),
              for (final u in _staff) ...[
                _UserRow(
                  name: _s(u['name']),
                  email: _s(u['email']),
                  role:
                      '${_s(u['role'])} · ${u['status'] == 'active' ? 'Active' : 'Invited'}',
                  color: _roleColor(u['role'] as String?),
                  onRemove: () async {
                    if (!await _confirmDelete(
                      context,
                      'team member "${u['name']}"',
                    )) {
                      return;
                    }
                    await _db.deletePartnerStaff(u['id'] as String);
                    _load();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final Color color;
  final VoidCallback? onRemove;
  const _UserRow({
    required this.name,
    required this.email,
    required this.role,
    required this.color,
    this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
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
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              name.isEmpty ? '?' : name.substring(0, 1),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                Text(email, style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18, color: _muted),
            ),
        ],
      ),
    );
  }
}

class _ApiKeysTab extends StatefulWidget {
  final Map<String, dynamic> account;
  const _ApiKeysTab({required this.account});

  @override
  State<_ApiKeysTab> createState() => _ApiKeysTabState();
}

class _ApiKeysTabState extends State<_ApiKeysTab> {
  final _db = DatabaseService();
  late String? _apiKey = widget.account['api_key'] as String?;
  bool _regenerating = false;
  bool _saving = false;
  late final Map<String, dynamic> _settings = Map<String, dynamic>.from(
    widget.account['settings'] as Map? ?? {},
  );
  late final _webhookCtl = TextEditingController(
    text: (_settings['webhook_url'] as String?) ?? '',
  );
  late final _rateLimitCtl = TextEditingController(
    text: (_settings['rate_limit'] ?? 120).toString(),
  );

  /// Cryptographically-secure key — Random() (the non-`.secure()` default)
  /// is a predictable PRNG, not safe for anything used as a credential.
  String _generateApiKey() {
    final rand = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buf = StringBuffer('sk_live_');
    for (var i = 0; i < 32; i++) {
      buf.write(chars[rand.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  Future<void> _saveWebhookSettings() async {
    setState(() => _saving = true);
    try {
      await _db.updatePartnerSettings(widget.account['id'] as String, {
        'webhook_url': _webhookCtl.text.trim(),
        'rate_limit': int.tryParse(_rateLimitCtl.text) ?? 120,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Webhook settings saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Future<void> _copy() async {
    final key = _apiKey;
    if (key == null) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key copied to clipboard')),
    );
  }

  Future<void> _generateOrRegenerate() async {
    if (_apiKey != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate API key?'),
          content: const Text(
            'The existing key will stop working immediately. Any '
            'integration using it must be updated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    final wasEmpty = _apiKey == null;
    setState(() => _regenerating = true);
    final newKey = _generateApiKey();
    try {
      await _db.setPartnerApiKey(widget.account['id'] as String, newKey);
      if (!mounted) return;
      setState(() {
        _apiKey = newKey;
        _regenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasEmpty ? 'API key generated' : 'API key regenerated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _regenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate key: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = _apiKey;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                      Icon(
                        Icons.warning_amber,
                        color: AppTheme.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Treat your API keys like passwords. Never commit '
                          'them to source control.',
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
                      if (apiKey == null)
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'No key generated yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _regenerating
                                  ? null
                                  : _generateOrRegenerate,
                              icon: _regenerating
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.key, size: 14),
                              label: const Text('Generate API Key'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                              ),
                            ),
                          ],
                        )
                      else
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
                              onPressed: _copy,
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text('Copy'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _text,
                                side: const BorderSide(color: _border),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _regenerating
                                  ? null
                                  : _generateOrRegenerate,
                              icon: _regenerating
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 14),
                              label: const Text('Regenerate'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.danger,
                                side: BorderSide(
                                  color: AppTheme.danger.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Webhook Endpoint URL',
                  hint: 'https://yourdomain.com/webhooks/applizone',
                  controller: _webhookCtl,
                  icon: Icons.webhook,
                ),
                const SizedBox(height: 12),
                _SettingsField(
                  label: 'Rate Limit (requests / minute)',
                  controller: _rateLimitCtl,
                  icon: Icons.speed,
                ),
              ],
            ),
          ),
        ),
        _SettingsSaveBar(onSave: _saveWebhookSettings, saving: _saving),
      ],
    );
  }
}

class _ToggleRow extends StatefulWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _ToggleRow({required this.title, required this.value, this.onChanged});
  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool _val = widget.value;
  @override
  void didUpdateWidget(_ToggleRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _val = widget.value;
  }

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
            onChanged: (v) {
              setState(() => _val = v);
              widget.onChanged?.call(v);
            },
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
      subtitle: 'Earn rewards by referring other couriers to One Village.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondaryNavy],
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
        'Integrate One Village with your own systems via REST + webhooks.',
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
