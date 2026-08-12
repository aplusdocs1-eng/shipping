import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Payroll record-keeping — not a payment integration. There's no Stripe
/// Connect (or any other payout capability) wired into this app; "Mark
/// Paid" records that a staff member was paid, it doesn't send money.
/// The actual transfer happens however it does today (bank transfer,
/// check, etc.), outside this app — see the payroll_runs/payroll_entries
/// migration's own comment for why a real-looking "Pay" button that
/// didn't really move money would be actively dangerous.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  List<StaffMember> _staff = [];
  List<Map<String, dynamic>> _runs = [];
  final Map<String, List<Map<String, dynamic>>> _entriesByRun = {};
  final Set<String> _actingOn = {};

  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_db.getStaff(), _db.getPayrollRuns()]);
      final staff = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(StaffMember.fromMap)
          .toList();
      final runs = (results[1] as List).cast<Map<String, dynamic>>().toList();
      final entriesByRun = <String, List<Map<String, dynamic>>>{};
      for (final run in runs) {
        entriesByRun[run['id'] as String] = await _db.getPayrollEntries(
          run['id'] as String,
        );
      }
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _runs = runs;
        _entriesByRun
          ..clear()
          ..addAll(entriesByRun);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load payroll: $e')));
    }
  }

  List<StaffMember> get _eligibleStaff => _staff
      .where((s) => s.isActive && (s.monthlySalary ?? 0) > 0)
      .toList();

  Map<String, dynamic>? get _draftRun {
    final drafts = _runs.where((r) => r['status'] == 'draft').toList();
    return drafts.isEmpty ? null : drafts.first;
  }

  List<Map<String, dynamic>> get _pastRuns =>
      _runs.where((r) => r['status'] != 'draft').toList();

  Future<void> _runPayroll() async {
    final eligible = _eligibleStaff;
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No active staff have a monthly salary set yet — add one from Staff Management first.',
          ),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    final periodLabel = DateFormat('MMMM y').format(start);
    final total = eligible.fold<double>(
      0,
      (s, m) => s + (m.monthlySalary ?? 0),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Payroll'),
        content: Text(
          'This creates a payroll run for $periodLabel covering '
          '${eligible.length} staff member${eligible.length == 1 ? '' : 's'}, '
          'totaling ${_currency.format(total)}.\n\n'
          "It doesn't send any money — you'll mark each staff member paid "
          'once you\'ve actually transferred it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Run'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _db.createPayrollRun(
        periodLabel: periodLabel,
        periodStart: start,
        periodEnd: end,
        entries: eligible
            .map(
              (m) => {
                'staff_id': m.id,
                'staff_name': m.name,
                'amount': m.monthlySalary,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create payroll run: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _cancelDraft(Map<String, dynamic> run) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this payroll run?'),
        content: Text(
          'This deletes the draft run for ${run['period_label']}. Nothing '
          'was paid, so nothing needs to be undone elsewhere.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Cancel Run'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _db.deletePayrollRun(run['id'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    }
  }

  Future<void> _markEntryPaid(Map<String, dynamic> entry) async {
    final id = entry['id'] as String;
    final methodCtl = ValueNotifier<String>('Bank Transfer');
    final referenceCtl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Mark ${entry['staff_name']} paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currency.format((entry['amount'] as num?)?.toDouble() ?? 0),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: methodCtl.value,
                    items: ['Bank Transfer', 'Cash', 'Cheque']
                        .map(
                          (m) => DropdownMenuItem(value: m, child: Text(m)),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => methodCtl.value = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceCtl,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                  hintText: 'Bank confirmation number, cheque #, etc.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('Mark Paid'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _actingOn.add(id));
    try {
      await _db.markPayrollEntryPaid(
        id,
        paymentMethod: methodCtl.value,
        reference: referenceCtl.text.trim().isEmpty
            ? null
            : referenceCtl.text.trim(),
      );
      await _checkRunComplete(entry['payroll_run_id'] as String);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark paid: $e')),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(id));
    }
  }

  Future<void> _markAllPaid(Map<String, dynamic> run) async {
    final runId = run['id'] as String;
    final entries = _entriesByRun[runId] ?? [];
    final pending = entries.where((e) => e['status'] != 'paid').toList();
    if (pending.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark all as paid?'),
        content: Text(
          'Records all ${pending.length} remaining staff in this run as '
          'paid via Bank Transfer. Use this once you\'ve actually sent '
          'every transfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Mark All Paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actingOn.add(runId));
    try {
      for (final e in pending) {
        await _db.markPayrollEntryPaid(
          e['id'] as String,
          paymentMethod: 'Bank Transfer',
        );
      }
      await _db.markPayrollRunPaid(runId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all paid: $e')),
      );
    } finally {
      if (mounted) setState(() => _actingOn.remove(runId));
    }
  }

  Future<void> _checkRunComplete(String runId) async {
    final entries = await _db.getPayrollEntries(runId);
    if (entries.isNotEmpty && entries.every((e) => e['status'] == 'paid')) {
      await _db.markPayrollRunPaid(runId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final draft = _draftRun;
    final draftEntries = draft != null
        ? (_entriesByRun[draft['id']] ?? [])
        : <Map<String, dynamic>>[];
    final pastRuns = _pastRuns;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payroll',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Run payroll and record when staff are paid.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (draft == null)
                ElevatedButton.icon(
                  onPressed: _runPayroll,
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text('Run Payroll'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 760 ? 3 : (c.maxWidth > 480 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  StatCard(
                    title: 'Monthly Payroll',
                    value: _currency.format(
                      _eligibleStaff.fold<double>(
                        0,
                        (s, m) => s + (m.monthlySalary ?? 0),
                      ),
                    ),
                    subtitle:
                        '${_eligibleStaff.length} staff with a salary set',
                    icon: Icons.groups_outlined,
                    iconColor: AppTheme.primary,
                  ),
                  StatCard(
                    title: 'Awaiting Payment',
                    value: draft == null
                        ? '\$0.00'
                        : _currency.format(
                            draftEntries
                                .where((e) => e['status'] != 'paid')
                                .fold<double>(
                                  0,
                                  (s, e) =>
                                      s +
                                      ((e['amount'] as num?)?.toDouble() ?? 0),
                                ),
                          ),
                    subtitle: draft == null
                        ? 'No run in progress'
                        : '${draftEntries.where((e) => e['status'] != 'paid').length} of ${draftEntries.length} staff',
                    icon: Icons.hourglass_empty_rounded,
                    iconColor: AppTheme.warning,
                  ),
                  StatCard(
                    title: 'Paid This Year',
                    value: _currency.format(
                      pastRuns
                          .where(
                            (r) =>
                                DateTime.tryParse(
                                  r['created_at']?.toString() ?? '',
                                )?.year ==
                                DateTime.now().year,
                          )
                          .fold<double>(
                            0,
                            (s, r) =>
                                s + ((r['total_amount'] as num?)?.toDouble() ?? 0),
                          ),
                    ),
                    subtitle: '${pastRuns.length} run${pastRuns.length == 1 ? '' : 's'} completed',
                    icon: Icons.check_circle_outline,
                    iconColor: AppTheme.success,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          if (draft != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payroll for ${draft['period_label']}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Total ${_currency.format((draft['total_amount'] as num?)?.toDouble() ?? 0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _actingOn.contains(draft['id'])
                              ? null
                              : () => _cancelDraft(draft),
                          child: const Text(
                            'Cancel Run',
                            style: TextStyle(color: AppTheme.danger),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed:
                              _actingOn.contains(draft['id']) ||
                                  draftEntries.every(
                                    (e) => e['status'] == 'paid',
                                  )
                              ? null
                              : () => _markAllPaid(draft),
                          icon: const Icon(Icons.done_all, size: 16),
                          label: const Text('Mark All Paid'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final entry in draftEntries)
                      _PayrollEntryRow(
                        entry: entry,
                        currency: _currency,
                        busy: _actingOn.contains(entry['id']),
                        onMarkPaid: () => _markEntryPaid(entry),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          _AccountingSectionHeader(
            title: 'Payroll History',
            subtitle: 'Completed payroll runs.',
          ),
          const SizedBox(height: 12),
          if (pastRuns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No completed payroll runs yet.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final run in pastRuns)
                    _PayrollRunHistoryTile(
                      run: run,
                      entries: _entriesByRun[run['id']] ?? [],
                      currency: _currency,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountingSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AccountingSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _PayrollEntryRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final NumberFormat currency;
  final bool busy;
  final VoidCallback onMarkPaid;
  const _PayrollEntryRow({
    required this.entry,
    required this.currency,
    required this.busy,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = entry['status'] == 'paid';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (entry['staff_name'] as String?) ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (isPaid)
                  Text(
                    'Paid via ${entry['payment_method'] ?? 'unspecified method'}'
                    '${(entry['reference'] as String?)?.isNotEmpty == true ? ' · ${entry['reference']}' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            currency.format((entry['amount'] as num?)?.toDouble() ?? 0),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isPaid)
            const StatusBadge(label: 'PAID', color: AppTheme.success)
          else
            OutlinedButton(
              onPressed: onMarkPaid,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _PayrollRunHistoryTile extends StatefulWidget {
  final Map<String, dynamic> run;
  final List<Map<String, dynamic>> entries;
  final NumberFormat currency;
  const _PayrollRunHistoryTile({
    required this.run,
    required this.entries,
    required this.currency,
  });

  @override
  State<_PayrollRunHistoryTile> createState() =>
      _PayrollRunHistoryTileState();
}

class _PayrollRunHistoryTileState extends State<_PayrollRunHistoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, y');
    final paidAt = DateTime.tryParse(
      widget.run['paid_at']?.toString() ?? '',
    );
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.run['period_label'] as String?) ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.entries.length} staff'
                        '${paidAt != null ? ' · paid ${df.format(paidAt)}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.currency.format(
                    (widget.run['total_amount'] as num?)?.toDouble() ?? 0,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in widget.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (e['staff_name'] as String?) ?? '',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Text(
                          widget.currency.format(
                            (e['amount'] as num?)?.toDouble() ?? 0,
                          ),
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
