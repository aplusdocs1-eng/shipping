import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _db = DatabaseService();
  String _query = '';
  StaffRole? _filterRole;
  StaffMember? _selected;
  bool _loading = true;
  List<StaffMember> _allStaff = [];
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_db.getStaff(), _db.getBranches()]);
      if (mounted)
        setState(() {
          _allStaff = (results[0] as List)
              .cast<Map<String, dynamic>>()
              .map(StaffMember.fromMap)
              .toList();
          _branches = (results[1] as List).cast<Map<String, dynamic>>();
          _loading = false;
          if (_selected != null) {
            final match = _allStaff.where((s) => s.id == _selected!.id);
            _selected = match.isEmpty ? null : match.first;
          }
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setActive(StaffMember member, bool active) async {
    try {
      await _db.updateStaff(member.id, {'is_active': active});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update staff: $e')),
      );
    }
  }

  List<StaffMember> get _filtered {
    return _allStaff.where((s) {
      final matchQ =
          _query.isEmpty ||
          s.name.toLowerCase().contains(_query.toLowerCase()) ||
          s.email.toLowerCase().contains(_query.toLowerCase()) ||
          s.branchName.toLowerCase().contains(_query.toLowerCase());
      final matchRole = _filterRole == null || s.role == _filterRole;
      return matchQ && matchRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
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
                          'Staff Management',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage team members and roles',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showStaffFormDialog(context),
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text('Add Staff'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Role summary
                Row(
                  children: StaffRole.values.map((role) {
                    final count = _allStaff.where((s) => s.role == role).length;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: role.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  role.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: role.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search staff by name, email, branch...',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          prefixIconConstraints: BoxConstraints(
                            minWidth: 42,
                            minHeight: 42,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DropFilter<StaffRole?>(
                      hint: 'All Roles',
                      value: _filterRole,
                      items: [null, ...StaffRole.values],
                      itemLabel: (v) => v == null ? 'All Roles' : v.label,
                      onChanged: (v) => setState(() => _filterRole = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table
                Expanded(
                  child: Card(
                    child: Column(
                      children: [
                        _StaffTableHead(),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _filtered.isEmpty
                              ? const EmptyState(
                                  icon: Icons.people_outline,
                                  title: 'No staff found',
                                  subtitle: 'No staff match your search',
                                )
                              : ListView.builder(
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, i) {
                                    final s = _filtered[i];
                                    return _StaffRow(
                                      member: s,
                                      isSelected: _selected?.id == s.id,
                                      onTap: () => setState(
                                        () => _selected = _selected?.id == s.id
                                            ? null
                                            : s,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_selected != null)
          _StaffDetail(
            member: _selected!,
            onClose: () => setState(() => _selected = null),
            onToggleActive: () => _setActive(_selected!, !_selected!.isActive),
            onEdit: () => _showStaffFormDialog(context, existing: _selected),
          ),
      ],
    );
  }

  Future<void> _showStaffFormDialog(
    BuildContext context, {
    StaffMember? existing,
  }) async {
    final isEdit = existing != null;
    final nameParts = (existing?.name ?? '').split(' ');
    final firstName = TextEditingController(
      text: nameParts.isNotEmpty ? nameParts.first : '',
    );
    final lastName = TextEditingController(
      text: nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
    );
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final salary = TextEditingController(
      text: existing?.monthlySalary != null
          ? existing!.monthlySalary!.toStringAsFixed(2)
          : '',
    );
    final bankName = TextEditingController(text: existing?.bankName ?? '');
    final bankAccountName = TextEditingController(
      text: existing?.bankAccountName ?? '',
    );
    final bankAccountNumber = TextEditingController(
      text: existing?.bankAccountNumber ?? '',
    );
    final bankRoutingNumber = TextEditingController(
      text: existing?.bankRoutingNumber ?? '',
    );
    StaffRole role = existing?.role ?? StaffRole.agent;
    String? branchId =
        existing?.branchId.isNotEmpty == true
            ? existing!.branchId
            : (_branches.isNotEmpty ? _branches.first['id'] as String : null);
    bool saving = false;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEdit ? 'Edit Staff Member' : 'Add Staff Member',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DField(
                                'First Name',
                                'John',
                                controller: firstName,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DField(
                                'Last Name',
                                'Smith',
                                controller: lastName,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DField(
                          'Email Address',
                          'john.smith@company.com',
                          controller: email,
                        ),
                        const SizedBox(height: 12),
                        _DField(
                          'Phone',
                          '+1 (876) 555-0100',
                          controller: phone,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DDrop<StaffRole>(
                                'Role',
                                StaffRole.values,
                                (r) => r.label,
                                value: role,
                                onChanged: (v) => setDialogState(
                                  () => role = v ?? StaffRole.agent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DDrop<String>(
                                'Branch',
                                _branches.map((b) => b['id'] as String).toList(),
                                (id) => _branches.firstWhere(
                                  (b) => b['id'] == id,
                                )['name'] as String,
                                value: branchId,
                                onChanged: (v) =>
                                    setDialogState(() => branchId = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DField(
                          'Address',
                          '12 Hope Road, Kingston',
                          controller: address,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'PAYROLL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DField(
                          'Monthly Salary (USD)',
                          '0.00',
                          controller: salary,
                        ),
                        const SizedBox(height: 12),
                        _DField(
                          'Bank Name',
                          'National Commercial Bank',
                          controller: bankName,
                        ),
                        const SizedBox(height: 12),
                        _DField(
                          'Account Holder Name',
                          'As it appears on the account',
                          controller: bankAccountName,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DField(
                                'Account Number',
                                '000123456789',
                                controller: bankAccountNumber,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DField(
                                'Routing / Branch Number',
                                '',
                                controller: bankRoutingNumber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final name =
                                  '${firstName.text.trim()} ${lastName.text.trim()}'
                                      .trim();
                              if (name.isEmpty || email.text.trim().isEmpty) {
                                setDialogState(
                                  () =>
                                      error = 'Name and email are required.',
                                );
                                return;
                              }
                              final salaryValue = salary.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(salary.text.trim());
                              if (salary.text.trim().isNotEmpty &&
                                  salaryValue == null) {
                                setDialogState(
                                  () => error =
                                      'Enter a valid monthly salary, or leave it blank.',
                                );
                                return;
                              }
                              setDialogState(() {
                                saving = true;
                                error = null;
                              });
                              final payload = {
                                'name': name,
                                'email': email.text.trim(),
                                'phone': phone.text.trim(),
                                'role': role.name,
                                'branch_id': branchId,
                                'address': address.text.trim(),
                                'monthly_salary': salaryValue,
                                'bank_name': bankName.text.trim(),
                                'bank_account_name': bankAccountName.text
                                    .trim(),
                                'bank_account_number': bankAccountNumber.text
                                    .trim(),
                                'bank_routing_number': bankRoutingNumber.text
                                    .trim(),
                              };
                              try {
                                if (isEdit) {
                                  await _db.updateStaff(existing.id, payload);
                                } else {
                                  await _db.insertStaff({
                                    ...payload,
                                    'is_active': true,
                                  });
                                }
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx, true);
                              } catch (e) {
                                setDialogState(() {
                                  saving = false;
                                  error =
                                      'Failed to save staff member: $e';
                                });
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isEdit
                                  ? Icons.save_outlined
                                  : Icons.person_add_outlined,
                              size: 14,
                            ),
                      label: Text(isEdit ? 'Save Changes' : 'Add Staff'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }
}

class _StaffTableHead extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(
      color: AppTheme.surface,
      border: Border(bottom: BorderSide(color: AppTheme.border)),
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    child: const Row(
      children: [
        Expanded(flex: 2, child: _TH('Name')),
        Expanded(flex: 2, child: _TH('Email')),
        Expanded(child: _TH('Role')),
        Expanded(child: _TH('Branch')),
        Expanded(child: _TH('Joined')),
        Expanded(child: _TH('Last Login')),
        Expanded(child: _TH('Status')),
      ],
    ),
  );
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
      letterSpacing: 0.4,
    ),
  );
}

class _StaffRow extends StatelessWidget {
  final StaffMember member;
  final bool isSelected;
  final VoidCallback onTap;
  const _StaffRow({
    required this.member,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.04)
              : Colors.transparent,
          border: Border(
            bottom: const BorderSide(color: AppTheme.border, width: 0.5),
            left: isSelected
                ? const BorderSide(color: AppTheme.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: member.role.color.withOpacity(0.15),
                    child: Text(
                      member.name[0],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: member.role.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                member.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: StatusBadge(
                label: member.role.label,
                color: member.role.color,
              ),
            ),
            Expanded(
              child: Text(
                member.branchName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                df.format(member.joinedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                member.lastLogin != null
                    ? df.format(member.lastLogin!)
                    : 'Never',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: StatusBadge(
                label: member.isActive ? 'Active' : 'Inactive',
                color: member.isActive
                    ? AppTheme.success
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffDetail extends StatelessWidget {
  final StaffMember member;
  final VoidCallback onClose;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  const _StaffDetail({
    required this.member,
    required this.onClose,
    required this.onToggleActive,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Text(
                  'Staff Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: member.role.color.withOpacity(0.15),
                      child: Text(
                        member.name[0],
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: member.role.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: StatusBadge(
                      label: member.role.label,
                      color: member.role.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _KV('Email', member.email),
                  _KV('Phone', member.phone),
                  _KV('Branch', member.branchName),
                  _KV('Joined', df.format(member.joinedAt)),
                  _KV(
                    'Last Login',
                    member.lastLogin != null
                        ? df.format(member.lastLogin!)
                        : 'Never',
                  ),
                  _KV('Status', member.isActive ? 'Active' : 'Inactive'),
                  if (member.address.isNotEmpty)
                    _KV('Address', member.address),
                  const SizedBox(height: 8),
                  const Text(
                    'PAYROLL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _KV(
                    'Monthly Pay',
                    member.monthlySalary != null
                        ? NumberFormat.currency(
                            symbol: '\$',
                          ).format(member.monthlySalary)
                        : 'Not set',
                  ),
                  if (member.hasBankingInfo) ...[
                    _KV(
                      'Bank',
                      member.bankName.isEmpty ? '—' : member.bankName,
                    ),
                    _KV(
                      'Account',
                      member.bankAccountNumber.isEmpty
                          ? '—'
                          : '${member.bankAccountName.isEmpty ? '' : '${member.bankAccountName} · '}${member.maskedAccountNumber}',
                    ),
                  ] else
                    _KV('Banking', 'Not set'),
                  const SizedBox(height: 20),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onToggleActive,
                      icon: Icon(
                        member.isActive
                            ? Icons.block
                            : Icons.check_circle_outline,
                        size: 14,
                        color: member.isActive
                            ? AppTheme.danger
                            : AppTheme.success,
                      ),
                      label: Text(
                        member.isActive ? 'Deactivate' : 'Activate',
                        style: TextStyle(
                          color: member.isActive
                              ? AppTheme.danger
                              : AppTheme.success,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: member.isActive
                              ? AppTheme.danger
                              : AppTheme.success,
                        ),
                      ),
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

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DropFilter<T> extends StatelessWidget {
  final String hint;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;
  const _DropFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hint,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: AppTheme.textSecondary,
        ),
        items: items
            .map(
              (i) => DropdownMenuItem<T>(
                value: i,
                child: Text(itemLabel(i), style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null || null is T) onChanged(v as T);
        },
      ),
    ),
  );
}

class _DField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  const _DField(this.label, this.hint, {this.controller});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );
}

class _DDrop<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? value;
  final ValueChanged<T?>? onChanged;
  const _DDrop(this.label, this.items, this.itemLabel, {this.value, this.onChanged});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            hint: items.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 13))
                : Text(itemLabel(items.first), style: const TextStyle(fontSize: 13)),
            items: items
                .map(
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(itemLabel(i), style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}
