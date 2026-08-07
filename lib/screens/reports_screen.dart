import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  List<Package> _packages = [];
  List<Invoice> _invoices = [];
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _db.getPackages(),
        _db.getAllInvoices(),
        _db.getCustomers(),
      ]);
      if (mounted)
        setState(() {
          _packages = (results[0] as List)
              .cast<Map<String, dynamic>>()
              .map(Package.fromMap)
              .toList();
          _invoices = (results[1] as List)
              .cast<Map<String, dynamic>>()
              .map(Invoice.fromMap)
              .toList();
          _customers = (results[2] as List)
              .cast<Map<String, dynamic>>()
              .map(Customer.fromMap)
              .toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final packages = _packages;
    final invoices = _invoices;
    final customers = _customers;
    final totalRevenue = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0.0, (sum, i) => sum + i.total);
    // Generate simple chart data: last 7 days package counts
    final now = DateTime.now();
    final packageChartData = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final count = packages.where((p) {
        final d = p.createdAt;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
      return {'date': day, 'count': count};
    });
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    // Delivery performance metrics computed from real data.
    final terminalPackages = packages.where(
      (p) =>
          p.status == PackageStatus.delivered ||
          p.status == PackageStatus.exception ||
          p.status == PackageStatus.returned,
    );
    final onTimeRate = terminalPackages.isEmpty
        ? 0.0
        : packages.where((p) => p.status == PackageStatus.delivered).length /
              terminalPackages.length;
    final exceptionRate = packages.isEmpty
        ? 0.0
        : packages.where((p) => p.status == PackageStatus.exception).length /
              packages.length;
    final invoiceCollectionRate = invoices.isEmpty
        ? 0.0
        : invoices.where((i) => i.status == InvoiceStatus.paid).length /
              invoices.length;
    final packagesPerCustomer = <String, int>{};
    for (final p in packages) {
      if (p.customerId.isEmpty) continue;
      packagesPerCustomer[p.customerId] =
          (packagesPerCustomer[p.customerId] ?? 0) + 1;
    }
    final repeatCustomers = packagesPerCustomer.values.where((c) => c > 1).length;
    final customerRetention = packagesPerCustomer.isEmpty
        ? 0.0
        : repeatCustomers / packagesPerCustomer.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Analytics and performance insights',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top stats
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                children: [
                  StatCard(
                    title: 'Total Packages',
                    value: packages.length.toString(),
                    icon: Icons.inventory_2_rounded,
                    iconColor: AppTheme.primary,
                    subtitle: 'All time',
                  ),
                  StatCard(
                    title: 'Delivered',
                    value: packages
                        .where((p) => p.status == PackageStatus.delivered)
                        .length
                        .toString(),
                    icon: Icons.check_circle_rounded,
                    iconColor: AppTheme.success,
                    subtitle: 'Successfully delivered',
                  ),
                  StatCard(
                    title: 'Total Revenue',
                    value: currencyFormat.format(totalRevenue),
                    icon: Icons.trending_up_rounded,
                    iconColor: AppTheme.success,
                    subtitle: 'All invoices',
                  ),
                  StatCard(
                    title: 'Exceptions',
                    value: packages
                        .where((p) => p.status == PackageStatus.exception)
                        .length
                        .toString(),
                    icon: Icons.warning_rounded,
                    iconColor: AppTheme.danger,
                    subtitle: 'Need attention',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Charts row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final packageChart = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Package Volume Trend'),
                      const SizedBox(height: 4),
                      const Text(
                        'Daily packages over the last 2 weeks',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: _BarChartWidget(chartData: packageChartData),
                      ),
                    ],
                  ),
                ),
              );

              final revenueChart = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Revenue Breakdown'),
                      const SizedBox(height: 4),
                      const Text(
                        'Invoice status distribution',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: _RevenueDonutChart(invoices: invoices),
                      ),
                    ],
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: packageChart),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: revenueChart),
                  ],
                );
              }
              return Column(
                children: [
                  packageChart,
                  const SizedBox(height: 16),
                  revenueChart,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Top customers + delivery performance
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final topCustomers = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Top Customers'),
                      const SizedBox(height: 16),
                      ...() {
                        int pkgsFor(Customer c) =>
                            packagesPerCustomer[c.id] ?? 0;
                        final sorted =
                            customers.where((c) => c.isActive).toList()..sort(
                              (a, b) => pkgsFor(b).compareTo(pkgsFor(a)),
                            );
                        final maxPkgs = customers.isEmpty
                            ? 1
                            : customers
                                  .map(pkgsFor)
                                  .fold(1, (a, b) => a > b ? a : b);
                        return sorted.take(5).map((c) {
                          final pkgs = pkgsFor(c);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.primary.withOpacity(
                                    0.12,
                                  ),
                                  child: Text(
                                    c.name.substring(0, 1),
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      LinearProgressIndicator(
                                        value: pkgs / maxPkgs,
                                        backgroundColor: AppTheme.border,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              AppTheme.primary,
                                            ),
                                        minHeight: 4,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$pkgs pkgs',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      }(),
                    ],
                  ),
                ),
              );

              final deliveryPerf = Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Delivery Performance'),
                      const SizedBox(height: 16),
                      _PerformanceRow(
                        'On-Time Delivery Rate',
                        onTimeRate,
                        AppTheme.success,
                      ),
                      const SizedBox(height: 12),
                      _PerformanceRow(
                        'Package Exception Rate',
                        exceptionRate,
                        AppTheme.danger,
                      ),
                      const SizedBox(height: 12),
                      _PerformanceRow(
                        'Invoice Collection Rate',
                        invoiceCollectionRate,
                        AppTheme.primary,
                      ),
                      const SizedBox(height: 12),
                      _PerformanceRow(
                        'Customer Retention',
                        customerRetention,
                        AppTheme.accent,
                      ),
                      const SizedBox(height: 20),
                      Builder(
                        builder: (context) {
                          const benchmark = 0.85;
                          final aboveBenchmark = onTimeRate >= benchmark;
                          final color = aboveBenchmark ? AppTheme.success : AppTheme.warning;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  aboveBenchmark
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color: color,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    aboveBenchmark
                                        ? 'On-time delivery is above the 85% benchmark'
                                        : terminalPackages.isEmpty
                                        ? 'Not enough delivered/exception packages yet to measure performance'
                                        : 'On-time delivery is below the 85% benchmark',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: topCustomers),
                    const SizedBox(width: 16),
                    Expanded(child: deliveryPerf),
                  ],
                );
              }
              return Column(
                children: [
                  topCustomers,
                  const SizedBox(height: 16),
                  deliveryPerf,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _PerformanceRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

class _BarChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;

  const _BarChartWidget({required this.chartData});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppTheme.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < chartData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat(
                        'd',
                      ).format(chartData[idx]['date'] as DateTime),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: chartData
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: (e.value['count'] as int).toDouble(),
                    color: AppTheme.primary,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RevenueDonutChart extends StatelessWidget {
  final List<Invoice> invoices;

  const _RevenueDonutChart({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final paid = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0.0, (s, i) => s + i.total);
    final sent = invoices
        .where((i) => i.status == InvoiceStatus.sent)
        .fold(0.0, (s, i) => s + i.total);
    final overdue = invoices
        .where((i) => i.status == InvoiceStatus.overdue)
        .fold(0.0, (s, i) => s + i.total);
    final draft = invoices
        .where((i) => i.status == InvoiceStatus.draft)
        .fold(0.0, (s, i) => s + i.total);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: [
                PieChartSectionData(
                  value: paid,
                  color: AppTheme.success,
                  radius: 30,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: sent,
                  color: AppTheme.accent,
                  radius: 30,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: overdue,
                  color: AppTheme.danger,
                  radius: 30,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: draft,
                  color: AppTheme.border,
                  radius: 30,
                  showTitle: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Legend('Paid', AppTheme.success, '\$${paid.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            _Legend('Sent', AppTheme.accent, '\$${sent.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            _Legend(
              'Overdue',
              AppTheme.danger,
              '\$${overdue.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 8),
            _Legend('Draft', AppTheme.border, '\$${draft.toStringAsFixed(0)}'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  final String amount;

  const _Legend(this.label, this.color, this.amount);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 6),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
