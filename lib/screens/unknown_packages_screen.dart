import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/live_data_service.dart';
import '../theme/app_theme.dart';

/// Admin queue for packages that were received but couldn't be confidently
/// matched to a customer — see the UNKNOWN PACKAGE REQUIREMENT: nothing
/// here was ever discarded or assigned to a fake customer. Every field
/// the scanner extracted is preserved and this screen is how staff
/// resolve it later: match it to a real customer, create a new customer
/// from what was extracted, correct the OCR fields, view the original
/// label, or reject it outright.
class UnknownPackagesScreen extends StatefulWidget {
  const UnknownPackagesScreen({super.key});

  @override
  State<UnknownPackagesScreen> createState() => _UnknownPackagesScreenState();
}

class _UnknownPackagesScreenState extends State<UnknownPackagesScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  bool _showReviewToo = false;
  List<Map<String, dynamic>> _unknown = [];
  List<Map<String, dynamic>> _review = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getUnknownPackages(),
        _db.getPackagesNeedingReview(),
      ]);
      setState(() {
        _unknown = results[0];
        _review = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load packages: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _visible => _showReviewToo ? [..._unknown, ..._review] : _unknown;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unknown Packages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text(
                    'Received packages with no confident customer match — nothing here was discarded.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              FilterChip(
                label: Text('Also show Needs Review (${_review.length})'),
                selected: _showReviewToo,
                onSelected: (v) => setState(() => _showReviewToo = v),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _visible.isEmpty
                ? const Center(
                    child: Text('No unknown packages — everything received has been matched.', style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: _visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _PackageCard(entry: _visible[i], db: _db, onChanged: _load),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final DatabaseService db;
  final VoidCallback onChanged;
  const _PackageCard({required this.entry, required this.db, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isReview = entry['match_status'] == 'needs_review';
    final scannedAt = DateTime.tryParse(entry['scanned_in_at']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry['recipient_name']?.toString().isNotEmpty == true
                              ? entry['recipient_name'].toString()
                              : '(No recipient name extracted)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(isReview: isReview, score: (entry['match_score'] as num?)?.toDouble() ?? 0),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if ((entry['address_line_1'] as String?)?.isNotEmpty == true)
                      Text(
                        [
                          entry['address_line_1'],
                          entry['city'],
                          entry['state'] ?? entry['province'],
                          entry['postal_code'],
                        ].where((s) => s != null && s.toString().isNotEmpty).join(', '),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _kv('Tracking', entry['tracking_number']?.toString() ?? '—'),
                        _kv('Carrier', entry['carrier']?.toString() ?? 'Unknown'),
                        _kv(
                          'Scanned',
                          scannedAt != null ? DateFormat('MMM d, y  h:mm a').format(scannedAt) : '—',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _showMatchDialog(context),
                icon: const Icon(Icons.person_search_outlined, size: 16),
                label: const Text('Match Customer'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCreateCustomerDialog(context),
                icon: const Icon(Icons.person_add_alt_outlined, size: 16),
                label: const Text('Create Customer'),
              ),
              OutlinedButton.icon(
                onPressed: entry['label_image_path'] == null ? null : () => _viewLabel(context),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('View Label'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showEditDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showNoteDialog(context),
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: const Text('Add Note'),
              ),
              TextButton.icon(
                onPressed: () => _showRejectDialog(context),
                icon: const Icon(Icons.block, size: 16, color: AppTheme.danger),
                label: const Text('Reject', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
          if ((entry['internal_notes'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(6)),
              child: Text('Note: ${entry['internal_notes']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '$k: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        TextSpan(text: v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Future<void> _showMatchDialog(BuildContext context) async {
    final customers = LiveDataService().customers;
    final query = TextEditingController();
    List<Customer> filtered = customers.take(20).toList();
    final picked = await showDialog<Customer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Match Customer'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: query,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search by name, email, or customer ID',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (q) {
                    setDialogState(() {
                      filtered = customers
                          .where(
                            (c) =>
                                c.name.toLowerCase().contains(q.toLowerCase()) ||
                                c.email.toLowerCase().contains(q.toLowerCase()) ||
                                c.mailboxNumber.toLowerCase().contains(q.toLowerCase()),
                          )
                          .take(20)
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.mailboxNumber.isNotEmpty ? '${c.mailboxNumber} · ${c.address}' : c.address,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
        ),
      ),
    );
    if (picked == null) return;
    await db.assignPackageToCustomer(
      warehouseEntryId: entry['id'].toString(),
      customerId: picked.id,
      customerName: picked.name,
    );
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Package assigned to ${picked.name}'), backgroundColor: AppTheme.success),
      );
    }
  }

  Future<void> _showCreateCustomerDialog(BuildContext context) async {
    final nameCtrl = TextEditingController(text: entry['recipient_name']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: entry['recipient_email']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: entry['recipient_phone']?.toString() ?? '');
    final addressCtrl = TextEditingController(
      text: [entry['address_line_1'], entry['city'], entry['state'] ?? entry['province'], entry['postal_code'], entry['country']]
          .where((s) => s != null && s.toString().isNotEmpty)
          .join(', '),
    );
    // Admin-wide screen, no single courier's tracking prefix applies here
    // — falls back to DatabaseService's generic "CUST" prefix.
    final mailboxCtrl = TextEditingController(text: await db.suggestNextMailboxNumber());
    if (!context.mounted) return;

    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> regenerateMailbox() async {
            final suggestion = await db.suggestNextMailboxNumber();
            setDialogState(() => mailboxCtrl.text = suggestion);
          }

          Future<void> createAndAssign() async {
            if (nameCtrl.text.trim().isEmpty) {
              setDialogState(() => error = 'Name is required.');
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final row = await db.insertCustomer({
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'mailbox_number': mailboxCtrl.text.trim().isEmpty ? null : mailboxCtrl.text.trim(),
                'status': 'active',
              });
              await db.assignPackageToCustomer(
                warehouseEntryId: entry['id'].toString(),
                customerId: row['id'].toString(),
                customerName: nameCtrl.text.trim(),
              );
              onChanged();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Created ${nameCtrl.text.trim()} and assigned the package'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            } catch (e) {
              if (db.isMailboxNumberConflict(e)) {
                await regenerateMailbox();
                setDialogState(() {
                  saving = false;
                  error = 'That mailbox number is already in use — '
                      'suggested a new one below, try again.';
                });
                return;
              }
              setDialogState(() {
                saving = false;
                error = 'Failed to create customer: $e';
              });
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Create Customer From Extracted Data'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 10),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 10),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 10),
                  TextField(controller: addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mailboxCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mailbox Number',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: 'Unique ID this customer gives merchants',
                      suffixIcon: IconButton(
                        tooltip: 'Suggest another',
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: saving ? null : regenerateMailbox,
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : createAndAssign,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create & Assign'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _viewLabel(BuildContext context) async {
    try {
      final url = await db.getPackageLabelSignedUrl(entry['label_image_path'].toString());
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load label image: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final fields = {
      'recipient_name': entry['recipient_name']?.toString() ?? '',
      'address_line_1': entry['address_line_1']?.toString() ?? '',
      'city': entry['city']?.toString() ?? '',
      'postal_code': entry['postal_code']?.toString() ?? '',
      'tracking_number': entry['tracking_number']?.toString() ?? '',
      'carrier': entry['carrier']?.toString() ?? '',
    };
    final controllers = fields.map((k, v) => MapEntry(k, TextEditingController(text: v)));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Edit Extracted Information'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in controllers.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: entry.key.replaceAll('_', ' '),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    await db.updateWarehouseEntryFields(
      entry['id'].toString(),
      controllers.map((k, v) => MapEntry(k, v.text.trim())),
    );
    onChanged();
  }

  Future<void> _showNoteDialog(BuildContext context) async {
    final noteCtrl = TextEditingController(text: entry['internal_notes']?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Internal Note'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Visible to staff only'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    await db.updateWarehouseEntryFields(entry['id'].toString(), {'internal_notes': noteCtrl.text.trim()});
    onChanged();
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reject Package'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await db.rejectPackage(warehouseEntryId: entry['id'].toString(), reason: reasonCtrl.text.trim());
    onChanged();
  }
}

class _StatusPill extends StatelessWidget {
  final bool isReview;
  final double score;
  const _StatusPill({required this.isReview, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = isReview ? AppTheme.warning : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        isReview ? 'NEEDS REVIEW · ${score.toStringAsFixed(0)}%' : 'UNKNOWN',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
