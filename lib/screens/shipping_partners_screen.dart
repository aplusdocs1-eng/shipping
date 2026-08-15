import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ShippingPartnersScreen extends StatefulWidget {
  const ShippingPartnersScreen({super.key});

  @override
  State<ShippingPartnersScreen> createState() => _ShippingPartnersScreenState();
}

class _ShippingPartnersScreenState extends State<ShippingPartnersScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _partnerAccounts = [];
  List<ShippingPartner> _shippingPartners = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_loadPartnerAccounts(), _loadShippingPartners()]);
    setState(() => _loading = false);
  }

  Future<void> _loadShippingPartners() async {
    try {
      final rows = await _db.getShippingPartners();
      if (!mounted) return;
      setState(
        () => _shippingPartners = rows.map(ShippingPartner.fromMap).toList(),
      );
    } catch (_) {}
  }

  Future<void> _loadPartnerAccounts() async {
    try {
      final rows = await _db.getAllPartnerAccounts();
      if (!mounted) return;
      setState(() => _partnerAccounts = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _partnerAccounts = []);
    }
  }

  String _generateApiKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(24, (_) => rand.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    return 'az_live_$token';
  }

  Future<void> _openPartnerDialog({ShippingPartner? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ShippingPartnerDialog(db: _db, existing: existing),
    );
    if (saved == true) await _loadShippingPartners();
  }

  Future<void> _openPendingDetails(Map<String, dynamic> account) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _PendingPartnerDialog(account: account, db: _db),
    );
    if (result == null) return;
    await _loadPartnerAccounts();
    if (!mounted) return;
    final msg = result == 'approved'
        ? '${account['company_name']} approved'
        : result == 'rejected'
        ? '${account['company_name']} rejected'
        : 'Saved';
    final color = result == 'approved'
        ? AppTheme.success
        : result == 'rejected'
        ? AppTheme.warning
        : AppTheme.primary;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        width: 260,
      ),
    );
  }

  Future<void> _approvePartner(Map<String, dynamic> account) async {
    try {
      // Issue an API key if one isn't set yet
      if (account['api_key'] == null ||
          (account['api_key'] as String).isEmpty) {
        await _db.setPartnerApiKey(account['id'] as String, _generateApiKey());
      }
      await _db.approvePartnerAccount(account['id'] as String);
      await _loadPartnerAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${account['company_name']} approved'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          width: 260,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approve failed: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectPartner(Map<String, dynamic> account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${account['company_name']}?'),
        content: const Text(
          'The partner will be denied access. You can re-approve them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.rejectPartnerAccount(account['id'] as String);
      await _loadPartnerAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${account['company_name']} rejected'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          width: 260,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reject failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _regenerateKey(Map<String, dynamic> account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Regenerate key for ${account['company_name']}?'),
        content: const Text(
          'The existing API key will stop working immediately. '
          'The partner must be given the new key.',
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
    final newKey = _generateApiKey();
    try {
      await _db.setPartnerApiKey(account['id'] as String, newKey);
      await _loadPartnerAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key regenerated'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          width: 260,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Shipping Partners',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Register third-party shipping companies so scanned packages are automatically matched to them by tracking prefix.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // ── Pending Partner Approvals ────────────────────────────────────
          _PendingApprovalsCard(
            accounts: _partnerAccounts
                .where(
                  (a) => (a['status'] as String? ?? 'pending') == 'pending',
                )
                .toList(),
            onApprove: _approvePartner,
            onReject: _rejectPartner,
            onTap: _openPendingDetails,
          ),
          const SizedBox(height: 24),

          // ── Registered Partners ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Registered Shipping Partners',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openPartnerDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Partner'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Packages with a matching tracking prefix are automatically linked to the partner when scanned in. Tap a row to edit.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(0.8),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(0.8),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.border),
                        ),
                      ),
                      children: const [
                        _TH('Code'),
                        _TH('Company'),
                        _TH('Region'),
                        _TH('Prefix'),
                        _TH('Contact'),
                        _TH('Status'),
                      ],
                    ),
                    ..._shippingPartners.map(_partnerRow),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Partner API Keys (admin view) ────────────────────────────────
          _PartnerApiKeysCard(
            accounts: _partnerAccounts,
            onRegenerate: _regenerateKey,
            onRefresh: _loadPartnerAccounts,
          ),
          const SizedBox(height: 24),

          // ── How It Works ─────────────────────────────────────────────────
          _HowItWorks(),
        ],
      ),
    );
  }

  TableRow _partnerRow(ShippingPartner p) {
    Widget tappable(Widget child) => InkWell(
      onTap: () => _openPartnerDialog(existing: p),
      child: child,
    );
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      children: [
        _TD(
          child: tappable(Text(
            p.code,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          )),
        ),
        _TD(child: tappable(Text(p.name, style: const TextStyle(fontSize: 13)))),
        _TD(child: tappable(Text(p.region, style: const TextStyle(fontSize: 13)))),
        _TD(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p.trackingPrefix,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        _TD(
          child: Text(
            p.contactEmail,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        _TD(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.isActive
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.isActive ? AppTheme.success : AppTheme.danger,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── How It Works Section ────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How Partner Sync Works',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StepCard(
                number: '1',
                title: 'Register Partner',
                desc:
                    'Add the shipping partner\'s company info and tracking prefix so the system knows which packages belong to them.',
                icon: Icons.add_business,
              ),
              const SizedBox(width: 12),
              _StepCard(
                number: '2',
                title: 'Scan Package',
                desc:
                    'When a package arrives, scan it in the Warehouse. The tracking prefix identifies the shipping partner.',
                icon: Icons.qr_code_scanner,
              ),
              const SizedBox(width: 12),
              _StepCard(
                number: '3',
                title: 'Auto-Match',
                desc:
                    'The tracking prefix is matched against your registered partners and the package is tagged with a storage location.',
                icon: Icons.sync,
              ),
              const SizedBox(width: 12),
              _StepCard(
                number: '4',
                title: 'Agent Pickup',
                desc:
                    'Shipping agents check the system, find their packages by location, and pick them up.',
                icon: Icons.local_shipping,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final IconData icon;

  const _StepCard({
    required this.number,
    required this.title,
    required this.desc,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Table helpers ───────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _TD extends StatelessWidget {
  final Widget child;
  const _TD({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: child,
    );
  }
}

// ─── Pending Approvals Card ──────────────────────────────────────────────────

class _PendingApprovalsCard extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final Future<void> Function(Map<String, dynamic>) onApprove;
  final Future<void> Function(Map<String, dynamic>) onReject;
  final Future<void> Function(Map<String, dynamic>) onTap;

  const _PendingApprovalsCard({
    required this.accounts,
    required this.onApprove,
    required this.onReject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accounts.isEmpty ? AppTheme.border : AppTheme.warning,
          width: accounts.isEmpty ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions,
                size: 20,
                color: accounts.isEmpty
                    ? AppTheme.textSecondary
                    : AppTheme.warning,
              ),
              const SizedBox(width: 8),
              const Text(
                'Pending Partner Approvals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (accounts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${accounts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'New 3rd-party shippers that have signed up and are waiting for you to approve them.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (accounts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Text(
                'No partners are waiting for approval.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Column(
              children: accounts.map((a) {
                final submitted = DateTime.tryParse(
                  a['created_at'] as String? ?? '',
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(a),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['company_name'] as String? ?? '(no name)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${a['contact_name'] ?? ''} • ${a['email'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'Prefix: ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        a['tracking_prefix'] as String? ?? '—',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (submitted != null)
                                        Text(
                                          'Submitted ${submitted.toLocal().toString().split('.').first}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => onReject(a),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.danger,
                                side: BorderSide(color: AppTheme.danger),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => onApprove(a),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Partner API Keys Card (admin view) ──────────────────────────────────────

class _PartnerApiKeysCard extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final Future<void> Function(Map<String, dynamic>) onRegenerate;
  final Future<void> Function() onRefresh;

  const _PartnerApiKeysCard({
    required this.accounts,
    required this.onRegenerate,
    required this.onRefresh,
  });

  @override
  State<_PartnerApiKeysCard> createState() => _PartnerApiKeysCardState();
}

class _PartnerApiKeysCardState extends State<_PartnerApiKeysCard> {
  final Set<String> _revealed = {};

  String _mask(String? key) {
    if (key == null || key.isEmpty) return '— not issued —';
    return 'az_live_${'•' * 28}';
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API key copied'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        width: 220,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.vpn_key_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Partner API Keys',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: widget.onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Each third-party partner has a unique API key. Share or rotate it from here.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (widget.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No partner accounts yet.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(3.5),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  children: const [
                    _TH('Company'),
                    _TH('Email'),
                    _TH('API Key'),
                    _TH('Status'),
                    _TH(''),
                  ],
                ),
                ...widget.accounts.map((a) {
                  final id = a['id'] as String;
                  final key = a['api_key'] as String?;
                  final revealed = _revealed.contains(id);
                  final status = (a['status'] as String?) ?? 'pending';
                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.border, width: 0.5),
                      ),
                    ),
                    children: [
                      _TD(
                        child: Text(
                          a['company_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _TD(
                        child: Text(
                          a['email'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      _TD(
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                revealed && key != null ? key : _mask(key),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (key != null && key.isNotEmpty) ...[
                              IconButton(
                                tooltip: revealed ? 'Hide' : 'Reveal',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                icon: Icon(
                                  revealed
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () => setState(() {
                                  if (revealed) {
                                    _revealed.remove(id);
                                  } else {
                                    _revealed.add(id);
                                  }
                                }),
                              ),
                              IconButton(
                                tooltip: 'Copy',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                icon: const Icon(
                                  Icons.copy,
                                  size: 15,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () => _copy(key),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _TD(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'approved'
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : status == 'pending'
                                ? AppTheme.warning.withValues(alpha: 0.1)
                                : AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: status == 'approved'
                                  ? AppTheme.success
                                  : status == 'pending'
                                  ? AppTheme.warning
                                  : AppTheme.danger,
                            ),
                          ),
                        ),
                      ),
                      _TD(
                        child: TextButton.icon(
                          onPressed: () => widget.onRegenerate(a),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text(
                            'Regenerate',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Pending Partner Dialog ──────────────────────────────────────────────────

class _PendingPartnerDialog extends StatefulWidget {
  final Map<String, dynamic> account;
  final DatabaseService db;

  const _PendingPartnerDialog({required this.account, required this.db});

  @override
  State<_PendingPartnerDialog> createState() => _PendingPartnerDialogState();
}

class _PendingPartnerDialogState extends State<_PendingPartnerDialog> {
  late final TextEditingController _companyCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _prefixCtrl;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _companyCtrl = TextEditingController(
      text: widget.account['company_name'] as String? ?? '',
    );
    _contactCtrl = TextEditingController(
      text: widget.account['contact_name'] as String? ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.account['phone'] as String? ?? '',
    );
    _prefixCtrl = TextEditingController(
      text: widget.account['tracking_prefix'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _edits() => {
    'company_name': _companyCtrl.text.trim(),
    'contact_name': _contactCtrl.text.trim(),
    'phone': _phoneCtrl.text.trim(),
    'tracking_prefix': _prefixCtrl.text.trim().toUpperCase(),
  };

  String _generateApiKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(24, (_) => rand.nextInt(256));
    return 'az_live_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.db.updatePartnerAccount(
        widget.account['id'] as String,
        _edits(),
      );
      if (!mounted) return;
      Navigator.of(context).pop('saved');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Save failed: $e';
        _busy = false;
      });
    }
  }

  Future<void> _approve() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = widget.account['id'] as String;
      await widget.db.updatePartnerAccount(id, _edits());
      if ((widget.account['api_key'] as String?)?.isNotEmpty != true) {
        await widget.db.setPartnerApiKey(id, _generateApiKey());
      }
      await widget.db.approvePartnerAccount(id);
      if (!mounted) return;
      Navigator.of(context).pop('approved');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Approve failed: $e';
        _busy = false;
      });
    }
  }

  Future<void> _reject() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.db.rejectPartnerAccount(widget.account['id'] as String);
      if (!mounted) return;
      Navigator.of(context).pop('rejected');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Reject failed: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.account['email'] as String? ?? '';
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.pending_actions, color: AppTheme.warning, size: 20),
          const SizedBox(width: 8),
          const Text('Review Partner Application'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email: $email',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _companyCtrl,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prefixCtrl,
              decoration: const InputDecoration(
                labelText: 'Tracking Prefix',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppTheme.danger, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _reject,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.danger,
            side: BorderSide(color: AppTheme.danger),
          ),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _approve,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 16),
          label: const Text('Approve'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
        ),
      ],
    );
  }
}

class _ShippingPartnerDialog extends StatefulWidget {
  final DatabaseService db;
  final ShippingPartner? existing;
  const _ShippingPartnerDialog({required this.db, this.existing});

  @override
  State<_ShippingPartnerDialog> createState() => _ShippingPartnerDialogState();
}

class _ShippingPartnerDialogState extends State<_ShippingPartnerDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _region;
  late final TextEditingController _prefix;
  late final TextEditingController _email;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _name = TextEditingController(text: e?.name ?? '');
    _region = TextEditingController(text: e?.region ?? '');
    _prefix = TextEditingController(text: e?.trackingPrefix ?? '');
    _email = TextEditingController(text: e?.contactEmail ?? '');
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _region.dispose();
    _prefix.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty || _prefix.text.trim().isEmpty) {
      setState(() => _error = 'Code, name, and tracking prefix are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.db.updateShippingPartner(widget.existing!.id, {
          'code': _code.text.trim().toUpperCase(),
          'name': _name.text.trim(),
          'region': _region.text.trim(),
          'tracking_prefix': _prefix.text.trim().toUpperCase(),
          'contact_email': _email.text.trim(),
          'is_active': _isActive,
        });
      } else {
        await widget.db.insertShippingPartner(
          code: _code.text.trim().toUpperCase(),
          name: _name.text.trim(),
          region: _region.text.trim(),
          trackingPrefix: _prefix.text.trim().toUpperCase(),
          contactEmail: _email.text.trim(),
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Shipping Partner' : 'Add Shipping Partner'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: 'Code (e.g. MYC)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _prefix,
                    decoration: const InputDecoration(labelText: 'Tracking Prefix'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Company Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _region,
              decoration: const InputDecoration(labelText: 'Region'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Contact Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active', style: TextStyle(fontSize: 14)),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdit ? 'Save Changes' : 'Add Partner'),
        ),
      ],
    );
  }
}
