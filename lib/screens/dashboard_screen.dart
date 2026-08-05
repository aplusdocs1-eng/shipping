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

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _db.getAllPartnerAccounts(),
        _db.getPackages(),
        _db.getCustomers(),
        _db.getShipments(),
        _db.getInvoices(),
      ]);
      if (!mounted) return;
      final invoices = (results[4] as List)
          .cast<Map<String, dynamic>>()
          .map(Invoice.fromMap)
          .toList();
      setState(() {
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
                  const Text(
                    'One Village Shipping & Freight',
                    style: TextStyle(
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
                    shipments: _shipments.take(10).toList(),
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

  const _RecentShipmentsTable({required this.shipments});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          children: ['Shipment Number', 'Description', 'Edit']
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
                child: Text(
                  s.shipmentNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'View',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
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
