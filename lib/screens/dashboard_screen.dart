import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewShipments;
  const DashboardScreen({super.key, this.onViewShipments});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _pendingPartners = [];
  bool _loading = true;
  List<Package> _packages = [];
  List<Customer> _customers = [];
  List<Shipment> _shipments = [];
  double _totalRevenue = 0;
  // Real company name from Settings -> Company Profile — falls back to
  // the platform default until settings load.
  String _companyName = 'One Village Shipping & Freight';
  Map<String, int>? _receivingStats;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadReceivingStats();
  }

  // Fetched separately from _loadAll's Future.wait — a failure here (e.g.
  // during a migration rollout edge case) shouldn't take down the rest of
  // the dashboard, which has nothing to do with package scanning.
  Future<void> _loadReceivingStats() async {
    try {
      final stats = await _db.getReceivingStats();
      if (mounted) setState(() => _receivingStats = stats);
    } catch (_) {
      // Stat block just doesn't render — see _receivingStats == null below.
    }
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _db.getAllPartnerAccounts(),
        _db.getPackages(),
        _db.getCustomers(),
        _db.getShipments(),
        // getInvoices() only returns invoice_type == 'partner_billing',
        // which silently excludes every customer_billing invoice (all of
        // them, in real data) from this dashboard's headline revenue
        // figure. getAllInvoices() is unscoped by type.
        _db.getAllInvoices(),
        _db.getCompanySettings(),
      ]);
      if (!mounted) return;
      final invoices = (results[4] as List)
          .cast<Map<String, dynamic>>()
          .map(Invoice.fromMap)
          .toList();
      final settings = results[5] as Map<String, dynamic>?;
      final loadedCompanyName = settings?['companyName'] as String?;
      setState(() {
        if (loadedCompanyName != null && loadedCompanyName.trim().isNotEmpty) {
          _companyName = loadedCompanyName.trim();
        }
        _pendingPartners = (results[0] as List)
            .cast<Map<String, dynamic>>()
            .where((a) => (a['status'] as String? ?? 'pending') == 'pending')
            .toList();
        _packages = (results[1] as List)
            .cast<Map<String, dynamic>>()
            .map(Package.fromMap)
            .toList();
        _customers = (results[2] as List)
            .cast<Map<String, dynamic>>()
            .map(Customer.fromMap)
            .toList();
        _shipments = (results[3] as List)
            .cast<Map<String, dynamic>>()
            .map(Shipment.fromMap)
            .toList();
        _totalRevenue = invoices
            .where((i) => i.status == InvoiceStatus.paid)
            .fold(0.0, (s, i) => s + i.total);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Once a shipment has arrived at the Jamaican warehouse (or moved past
  // that into customs clearance / closed), it's no longer "in progress" —
  // Recent Shipments is meant to show what's still moving, not a
  // permanent log of everything ever shipped.
  List<Shipment> get _activeShipments => _shipments
      .where(
        (s) =>
            s.status == ShipmentStatus.preparing ||
            s.status == ShipmentStatus.inTransit,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section (matches website)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Company avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 32,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _companyName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Account  ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          'ACJAM',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Pending partner approvals notice
          if (_pendingPartners.isNotEmpty) ...[
            _PendingPartnersBanner(
              count: _pendingPartners.length,
              firstCompany:
                  _pendingPartners.first['company_name'] as String? ?? '',
            ),
            const SizedBox(height: 20),
          ],

          // Stat cards (matching website: Account Balance, Customers, Shipments, Outstanding, Total Packages)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 1000
                  ? 5
                  : (constraints.maxWidth > 700
                        ? 3
                        : (constraints.maxWidth > 400 ? 2 : 1));
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _DashStatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppTheme.accent,
                    title: 'Account Balance',
                    value: 'Total ${currencyFormat.format(_totalRevenue)} USD',
                  ),
                  _DashStatCard(
                    icon: Icons.people_outline,
                    iconColor: AppTheme.success,
                    title: 'Customers',
                    value: _customers.length.toString(),
                    subtitle: 'Total in dashboard',
                  ),
                  _DashStatCard(
                    icon: Icons.flight_takeoff_rounded,
                    iconColor: AppTheme.warning,
                    title: 'Shipments',
                    value: _shipments.length.toString(),
                    subtitle: 'Total shipments',
                  ),
                  _DashStatCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppTheme.danger,
                    title: 'Outstanding',
                    value: _packages
                        .where((p) => p.status == PackageStatus.pending)
                        .length
                        .toString(),
                    subtitle: 'Not in shipment',
                  ),
                  _DashStatCard(
                    icon: Icons.all_inbox_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Total Packages',
                    value: _packages.length.toString(),
                    subtitle: 'Received to date',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          if (_receivingStats != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WAREHOUSE RECEIVING — TODAY',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 700;
                        final tiles = [
                          _ReceivingStatTile('Received Today', _receivingStats!['receivedToday'] ?? 0, AppTheme.primary),
                          _ReceivingStatTile('Received This Week', _receivingStats!['receivedThisWeek'] ?? 0, AppTheme.accent),
                          _ReceivingStatTile('Needs Review', _receivingStats!['needsReview'] ?? 0, AppTheme.warning),
                          _ReceivingStatTile('Unmatched', _receivingStats!['unmatched'] ?? 0, AppTheme.danger),
                          _ReceivingStatTile('Duplicate Scans Today', _receivingStats!['duplicatesToday'] ?? 0, AppTheme.textSecondary),
                        ];
                        return Wrap(
                          spacing: wide ? 32 : 20,
                          runSpacing: 16,
                          children: tiles,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Recent Shipments table (matches website)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SectionHeader(
                    title: 'Recent Shipments',
                    actionLabel: 'View all',
                    onAction: widget.onViewShipments ?? () {},
                  ),
                  const SizedBox(height: 12),
                  _RecentShipmentsTable(
                    shipments: _activeShipments.take(10).toList(),
                    onView: widget.onViewShipments ?? () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ReceivingStatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ReceivingStatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _DashStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;

  const _DashStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentShipmentsTable extends StatelessWidget {
  final List<Shipment> shipments;
  final VoidCallback onView;

  const _RecentShipmentsTable({required this.shipments, required this.onView});

  @override
  Widget build(BuildContext context) {
    if (shipments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'No shipments in progress right now — anything preparing or '
            'in transit will show up here.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          children: ['Shipment Number', 'Route', '']
              .map(
                (h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...shipments.map(
          (s) => TableRow(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.border, width: 0.5),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.shipmentNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(
                      label: s.status.label.toUpperCase(),
                      color: s.status.color,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      s.type == ShipmentType.air
                          ? Icons.flight_outlined
                          : Icons.directions_boat_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (s.origin.isEmpty && s.destination.isEmpty)
                                ? 'No route set'
                                : '${s.origin.isEmpty ? '—' : s.origin} → '
                                      '${s.destination.isEmpty ? '—' : s.destination}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${s.packageCount} pkg${s.packageCount == 1 ? '' : 's'} · '
                                '${s.totalWeight.toStringAsFixed(0)} lbs',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(6),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward, size: 13, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Pending Partners Banner ─────────────────────────────────────────────────

class _PendingPartnersBanner extends StatelessWidget {
  final int count;
  final String firstCompany;

  const _PendingPartnersBanner({
    required this.count,
    required this.firstCompany,
  });

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? '$firstCompany is waiting for approval'
        : '$count shipping partners are waiting for approval';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.warning,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.pending_actions,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Open the Shipping Partners page in the sidebar to review and approve.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
