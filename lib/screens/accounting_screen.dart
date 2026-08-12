import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Real financial data only: invoices, customer payment submissions,
/// per-package courier billing (warehouse_entries.partner_charge_*), and
/// point-of-sale transactions — the four places actual money is tracked in
/// this app today. This is a revenue/receivables/courier-billing
/// dashboard, not a general-ledger system — there's no expense tracking
/// anywhere in this app to build a P&L from.
class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _paymentSubmissions = [];
  List<Map<String, dynamic>> _warehouseEntries = [];
  List<Map<String, dynamic>> _partnerAccounts = [];
  List<Map<String, dynamic>> _posTransactions = [];
  final Set<String> _actingOn = {};

  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        // getInvoices() only returns invoice_type == 'partner_billing' —
        // wrong for a revenue dashboard, since it silently excludes every
        // customer_billing invoice (all of them, in real data right now).
        // getAllInvoices() is unscoped by type, which is what "total
        // revenue" actually needs to mean here.
        _db.getAllInvoices(),
        _db.getAllPaymentSubmissions(),
        _db.getWarehouseEntries(),
        _db.getAllPartnerAccounts(),
        _db.getPosTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _invoices = List<Map<String, dynamic>>.from(results[0]);
        _paymentSubmissions = List<Map<String, dynamic>>.from(results[1]);
        _warehouseEntries = List<Map<String, dynamic>>.from(results[2]);
        _partnerAccounts = List<Map<String, dynamic>>.from(
          results[3],
        ).where((p) => p['status'] == 'approved').toList();
        _posTransactions = List<Map<String, dynamic>>.from(results[4]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load accounting data: $e';
      });
    }
  }

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  double get _totalRevenue => _invoices
      .where((i) => i['status'] == 'paid')
      .fold(0.0, (s, i) => s + _num(i['total']));

  // Real invoice status values on this table are 'paid' / 'pending' (not
  // the Dart Invoice model's enum names like "sent" — Invoice.fromMap
  // itself falls back any unrecognized raw status to InvoiceStatus.sent,
  // which is exactly why an allow-list of specific "unpaid" strings here
  // would have been wrong the moment real data didn't literally say
  // "sent"). Treat anything that isn't explicitly a closed status as
  // outstanding, matching that same fallback intent, rather than trying
  // to enumerate every string that might mean "not paid yet".
  static const _closedStatuses = {'paid', 'draft', 'cancelled'};
  bool _isOutstanding(Map<String, dynamic> inv) =>
      !_closedStatuses.contains(inv['status']);

  List<Map<String, dynamic>> get _unpaidInvoices {
    final list = _invoices.where(_isOutstanding).toList();
    list.sort((a, b) {
      final da = _date(a['due_date']) ?? DateTime(2100);
      final db_ = _date(b['due_date']) ?? DateTime(2100);
      return da.compareTo(db_);
    });
    return list;
  }

  double get _outstandingAR =>
      _unpaidInvoices.fold(0.0, (s, i) => s + _num(i['total']));

  bool _isOverdue(Map<String, dynamic> inv) {
    if (!_isOutstanding(inv)) return false;
    if (inv['status'] == 'overdue') return true;
    final due = _date(inv['due_date']);
    return due != null && due.isBefore(DateTime.now());
  }

  double get _overdueTotal => _invoices
      .where(_isOverdue)
      .fold(0.0, (s, i) => s + _num(i['total']));

  List<Map<String, dynamic>> get _pendingSubmissions => _paymentSubmissions
      .where((p) => p['status'] == 'pending_review')
      .toList();

  double get _pendingSubmissionsTotal =>
      _pendingSubmissions.fold(0.0, (s, p) => s + _num(p['amount']));

  Map<String, dynamic>? _matchCourier(String tracking) {
    if (tracking.isEmpty) return null;
    final upper = tracking.toUpperCase();
    for (final p in _partnerAccounts) {
      final prefix = (p['tracking_prefix'] as String?) ?? '';
      if (prefix.isNotEmpty && upper.startsWith(prefix.toUpperCase())) {
        return p;
      }
    }
    return null;
  }

  List<_CourierBilling> get _courierBilling {
    final map = <String, _CourierBilling>{};
    for (final e in _warehouseEntries) {
      final status = (e['partner_charge_status'] as String?) ?? 'unbilled';
      if (status == 'unbilled') continue;
      final amount = _num(e['partner_charge_amount']);
      final courier = _matchCourier((e['tracking_number'] as String?) ?? '');
      final key = (courier?['id'] as String?) ?? 'unmatched';
      final name = (courier?['company_name'] as String?) ?? 'Unmatched courier';
      final summary = map.putIfAbsent(key, () => _CourierBilling(name: name));
      if (status == 'billed') {
        summary.billed += amount;
        summary.unpaidCount++;
      } else if (status == 'paid') {
        summary.paid += amount;
        summary.paidCount++;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => (b.billed + b.paid).compareTo(a.billed + a.paid));
    return list;
  }

  double get _courierOutstanding =>
      _courierBilling.fold(0.0, (s, c) => s + c.billed);

  double get _courierRevenueCollected =>
      _courierBilling.fold(0.0, (s, c) => s + c.paid);

  double get _posRevenue =>
      _posTransactions.fold(0.0, (s, t) => s + _num(t['total']));

  List<MapEntry<DateTime, double>> get _monthlyRevenue {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - (5 - i), 1),
    );
    final totals = {for (final m in months) m: 0.0};
    for (final inv in _invoices) {
      if (inv['status'] != 'paid') continue;
      final paidAt = _date(inv['paid_at']) ?? _date(inv['updated_at']);
      if (paidAt == null) continue;
      final key = DateTime(paidAt.year, paidAt.month, 1);
      if (totals.containsKey(key)) totals[key] = totals[key]! + _num(inv['total']);
    }
    return months.map((m) => MapEntry(m, totals[m]!)).toList();
  }

  List<_LedgerEntry> get _recentTransactions {
    final list = <_LedgerEntry>[];
    for (final inv in _invoices) {
      if (inv['status'] != 'paid') continue;
      final at = _date(inv['paid_at']) ?? _date(inv['updated_at']);
      if (at == null) continue;
      list.add(
        _LedgerEntry(
          date: at,
          label: 'Invoice ${inv['invoice_number'] ?? ''} paid',
          detail: (inv['customer_name'] as String?) ?? '',
          amount: _num(inv['total']),
        ),
      );
    }
    for (final p in _paymentSubmissions) {
      if (p['status'] != 'confirmed') continue;
      final at = _date(p['reviewed_at']);
      if (at == null) continue;
      list.add(
        _LedgerEntry(
          date: at,
          label: 'Payment confirmed · ${p['method'] ?? 'unspecified method'}',
          detail: (p['reference'] as String?) ?? '',
          amount: _num(p['amount']),
        ),
      );
    }
    for (final e in _warehouseEntries) {
      if (e['partner_charge_status'] != 'paid') continue;
      final at = _date(e['partner_paid_at']);
      if (at == null) continue;
      final courier = _matchCourier((e['tracking_number'] as String?) ?? '');
      list.add(
        _LedgerEntry(
          date: at,
          label: 'Courier payment received',
          detail:
              '${(courier?['company_name'] as String?) ?? 'Unmatched courier'} · ${e['tracking_number'] ?? ''}',
          amount: _num(e['partner_charge_amount']),
        ),
      );
    }
    for (final t in _posTransactions) {
      final at = _date(t['created_at']);
      if (at == null) continue;
      list.add(
        _LedgerEntry(
          date: at,
          label: 'POS sale · ${t['payment_method'] ?? 'unspecified method'}',
          detail:
              '${(t['customer_name'] as String?) ?? 'Walk-in customer'} · ${t['receipt_number'] ?? ''}',
          amount: _num(t['total']),
        ),
      );
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list.take(25).toList();
  }

  Future<void> _approveSubmission(Map<String, dynamic> s) async {
    final id = s['id'] as String;
    final invoiceId = s['invoice_id'] as String?;
    if (invoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This submission isn't linked to an invoice — can't auto-confirm it."),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    setState(() => _actingOn.add(id));
    try {
      await _db.confirmPaymentSubmission(id, invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmed — invoice marked paid.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(id));
    }
  }

  Future<void> _rejectSubmission(Map<String, dynamic> s) async {
    final id = s['id'] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this payment?'),
        content: Text(
          'This marks the ${_currency.format(_num(s['amount']))} submission '
          'as rejected. The customer will need to submit payment again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _actingOn.add(id));
    try {
      await _db.rejectPaymentSubmission(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment submission rejected.'), behavior: SnackBarBehavior.floating),
      );
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
                    'Accounting',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Revenue, receivables, and courier billing — real data only.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 1300 ? 6 : (c.maxWidth > 900 ? 3 : (c.maxWidth > 480 ? 2 : 1));
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  StatCard(
                    title: 'Total Revenue',
                    value: _currency.format(_totalRevenue),
                    subtitle: 'From paid invoices',
                    icon: Icons.payments_outlined,
                    iconColor: AppTheme.success,
                  ),
                  StatCard(
                    title: 'Outstanding (AR)',
                    value: _currency.format(_outstandingAR),
                    subtitle: '${_unpaidInvoices.length} unpaid invoice${_unpaidInvoices.length == 1 ? '' : 's'}',
                    icon: Icons.hourglass_empty_rounded,
                    iconColor: AppTheme.accent,
                  ),
                  StatCard(
                    title: 'Overdue',
                    value: _currency.format(_overdueTotal),
                    subtitle: '${_invoices.where(_isOverdue).length} invoice${_invoices.where(_isOverdue).length == 1 ? '' : 's'} past due',
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppTheme.danger,
                  ),
                  StatCard(
                    title: 'Courier Billing Due',
                    value: _currency.format(_courierOutstanding),
                    subtitle: 'Billed, not yet paid',
                    icon: Icons.local_shipping_outlined,
                    iconColor: AppTheme.warning,
                  ),
                  StatCard(
                    title: 'Pending Reviews',
                    value: _currency.format(_pendingSubmissionsTotal),
                    subtitle: '${_pendingSubmissions.length} submission${_pendingSubmissions.length == 1 ? '' : 's'} to review',
                    icon: Icons.fact_check_outlined,
                    iconColor: AppTheme.primary,
                  ),
                  StatCard(
                    title: 'POS Sales',
                    value: _currency.format(_posRevenue),
                    subtitle: '${_posTransactions.length} sale${_posTransactions.length == 1 ? '' : 's'} rung up',
                    icon: Icons.point_of_sale_outlined,
                    iconColor: AppTheme.success,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue — last 6 months',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 200, child: _RevenueBarChart(monthly: _monthlyRevenue, currency: _currency)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth > 760;
              final revenueSources = _AccountingSection(
                title: 'Revenue Sources',
                subtitle: 'Where collected money actually came from',
                child: _DonutChart(
                  currency: _currency,
                  slices: [
                    _ChartSlice(
                      label: 'Invoice payments',
                      value: _totalRevenue,
                      color: AppTheme.primary,
                    ),
                    _ChartSlice(
                      label: 'Courier billing',
                      value: _courierRevenueCollected,
                      color: AppTheme.accent,
                    ),
                    _ChartSlice(
                      label: 'POS sales',
                      value: _posRevenue,
                      color: AppTheme.gold,
                    ),
                  ],
                ),
              );
              final collectionsHealth = _AccountingSection(
                title: 'Collections Health',
                subtitle: 'All invoiced amounts, by where they stand',
                child: _DonutChart(
                  currency: _currency,
                  slices: [
                    _ChartSlice(
                      label: 'Paid',
                      value: _totalRevenue,
                      color: AppTheme.success,
                    ),
                    _ChartSlice(
                      label: 'Outstanding',
                      value: _outstandingAR - _overdueTotal,
                      color: AppTheme.warning,
                    ),
                    _ChartSlice(
                      label: 'Overdue',
                      value: _overdueTotal,
                      color: AppTheme.danger,
                    ),
                  ],
                ),
              );
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: revenueSources),
                        const SizedBox(width: 20),
                        Expanded(child: collectionsHealth),
                      ],
                    )
                  : Column(
                      children: [
                        revenueSources,
                        const SizedBox(height: 20),
                        collectionsHealth,
                      ],
                    );
            },
          ),

          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth > 900;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccountingSection(
                    title: 'Accounts Receivable',
                    subtitle: 'Unpaid invoices, soonest due first',
                    child: _unpaidInvoices.isEmpty
                        ? const _EmptyRow('Nothing outstanding — every invoice is paid.')
                        : Column(
                            children: [
                              for (final inv in _unpaidInvoices)
                                _InvoiceRow(inv: inv, overdue: _isOverdue(inv), currency: _currency),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                  _AccountingSection(
                    title: 'Payment Submissions — Pending Review',
                    subtitle: 'Customer-submitted payments awaiting confirmation',
                    child: _pendingSubmissions.isEmpty
                        ? const _EmptyRow('No submissions waiting for review.')
                        : Column(
                            children: [
                              for (final s in _pendingSubmissions)
                                _SubmissionRow(
                                  submission: s,
                                  currency: _currency,
                                  busy: _actingOn.contains(s['id']),
                                  onApprove: () => _approveSubmission(s),
                                  onReject: () => _rejectSubmission(s),
                                ),
                            ],
                          ),
                  ),
                ],
              );
              final right = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccountingSection(
                    title: 'Courier Billing',
                    subtitle: 'Charges billed to each courier for warehouse-processed packages',
                    child: _courierBilling.isEmpty
                        ? const _EmptyRow('No courier charges billed yet.')
                        : Column(
                            children: [
                              _CourierBarChart(
                                billing: _courierBilling,
                                currency: _currency,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(height: 1, color: AppTheme.border),
                              ),
                              for (final c in _courierBilling)
                                _CourierBillingRow(billing: c, currency: _currency),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                  _AccountingSection(
                    title: 'Recent Transactions',
                    subtitle: 'Paid invoices, confirmed payments, and courier payments received',
                    child: _recentTransactions.isEmpty
                        ? const _EmptyRow('No transactions yet.')
                        : Column(
                            children: [
                              for (final t in _recentTransactions) _LedgerRow(entry: t, currency: _currency),
                            ],
                          ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 20),
                    Expanded(child: right),
                  ],
                );
              }
              return Column(children: [left, const SizedBox(height: 20), right]);
            },
          ),
        ],
      ),
    );
  }
}

class _CourierBilling {
  final String name;
  double billed = 0;
  double paid = 0;
  int unpaidCount = 0;
  int paidCount = 0;
  _CourierBilling({required this.name});
}

class _LedgerEntry {
  final DateTime date;
  final String label;
  final String detail;
  final double amount;
  _LedgerEntry({required this.date, required this.label, required this.detail, required this.amount});
}

class _AccountingSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _AccountingSection({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String message;
  const _EmptyRow(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(message, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Map<String, dynamic> inv;
  final bool overdue;
  final NumberFormat currency;
  const _InvoiceRow({required this.inv, required this.overdue, required this.currency});

  @override
  Widget build(BuildContext context) {
    final due = inv['due_date'] != null ? DateTime.tryParse(inv['due_date'].toString()) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (inv['invoice_number'] as String?) ?? '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                Text(
                  (inv['customer_name'] as String?) ?? '',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              due != null ? DateFormat('MMM d, y').format(due) : 'No due date',
              style: TextStyle(fontSize: 11.5, color: overdue ? AppTheme.danger : AppTheme.textSecondary),
            ),
          ),
          Text(
            currency.format((inv['total'] as num?)?.toDouble() ?? 0),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: overdue ? 'OVERDUE' : 'UNPAID', color: overdue ? AppTheme.danger : AppTheme.warning),
        ],
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final Map<String, dynamic> submission;
  final NumberFormat currency;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _SubmissionRow({
    required this.submission,
    required this.currency,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final submitted = submission['submitted_at'] != null
        ? DateTime.tryParse(submission['submitted_at'].toString())
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currency.format((submission['amount'] as num?)?.toDouble() ?? 0)} · ${(submission['method'] as String?) ?? 'Unspecified'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                Text(
                  [
                    if ((submission['reference'] as String?)?.isNotEmpty == true) submission['reference'],
                    if (submitted != null) DateFormat('MMM d, y').format(submitted),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            IconButton(
              onPressed: onReject,
              icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
              tooltip: 'Reject',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onApprove,
              icon: const Icon(Icons.check, size: 18, color: AppTheme.success),
              tooltip: 'Confirm',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _CourierBillingRow extends StatelessWidget {
  final _CourierBilling billing;
  final NumberFormat currency;
  const _CourierBillingRow({required this.billing, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              billing.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currency.format(billing.billed)} due',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.warning),
              ),
              Text(
                '${currency.format(billing.paid)} paid',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final _LedgerEntry entry;
  final NumberFormat currency;
  const _LedgerRow({required this.entry, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_downward, size: 14, color: AppTheme.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(
                  '${entry.detail.isNotEmpty ? '${entry.detail} · ' : ''}${DateFormat('MMM d, y').format(entry.date)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '+${currency.format(entry.amount)}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.success),
          ),
        ],
      ),
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  final List<MapEntry<DateTime, double>> monthly;
  final NumberFormat currency;
  const _RevenueBarChart({required this.monthly, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxVal = monthly.fold(0.0, (m, e) => e.value > m ? e.value : m);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal <= 0 ? 10 : maxVal * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) => Text(
                currency.format(value),
                style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= monthly.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MMM').format(monthly[idx].key),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: monthly
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value,
                    color: AppTheme.primary,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChartSlice {
  final String label;
  final double value;
  final Color color;
  const _ChartSlice({required this.label, required this.value, required this.color});
}

/// A small donut + legend, built from whatever real $ amounts the caller
/// passes in (revenue by source, invoices by collection status, etc.).
/// Zero-value slices are dropped from the ring and legend entirely rather
/// than drawn as a sliver, and an all-zero total shows a plain empty
/// state instead of a chart with nothing in it.
class _DonutChart extends StatelessWidget {
  final List<_ChartSlice> slices;
  final NumberFormat currency;
  const _DonutChart({required this.slices, required this.currency});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0.0, (s, x) => s + x.value);
    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No data yet.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
      );
    }
    final nonZero = slices.where((s) => s.value > 0).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: nonZero
                  .map(
                    (s) => PieChartSectionData(
                      value: s.value,
                      color: s.color,
                      radius: 24,
                      showTitle: false,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in nonZero)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${currency.format(s.value)} · ${(s.value / total * 100).round()}%',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Total: ${currency.format(total)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grouped billed-vs-paid bars, one pair per courier — the visual
/// complement to the exact-figures list rendered right below it.
class _CourierBarChart extends StatelessWidget {
  final List<_CourierBilling> billing;
  final NumberFormat currency;
  const _CourierBarChart({required this.billing, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxVal = billing.fold(
      0.0,
      (m, c) => [m, c.billed, c.paid].reduce((a, b) => a > b ? a : b),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal <= 0 ? 10 : maxVal * 1.25,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) => Text(
                      currency.format(value),
                      style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= billing.length) return const SizedBox.shrink();
                      final name = billing[idx].name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          name.length > 12 ? '${name.substring(0, 11)}…' : name,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: billing
                  .asMap()
                  .entries
                  .map(
                    (e) => BarChartGroupData(
                      x: e.key,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.billed,
                          color: AppTheme.warning,
                          width: 11,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        BarChartRodData(
                          toY: e.value.paid,
                          color: AppTheme.success,
                          width: 11,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            _LegendDot(color: AppTheme.warning, label: 'Billed (due)'),
            SizedBox(width: 16),
            _LegendDot(color: AppTheme.success, label: 'Paid'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
      ],
    );
  }
}
