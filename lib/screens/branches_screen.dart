import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final _db = DatabaseService();
  Branch? _selected;
  bool _loading = true;
  List<Branch> _allBranches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_db.getBranches(), _db.getStaff()]);
      final branchRows = (results[0] as List).cast<Map<String, dynamic>>();
      final staffRows = (results[1] as List).cast<Map<String, dynamic>>();
      final staffCounts = <String, int>{};
      for (final s in staffRows) {
        final bid = s['branch_id']?.toString();
        if (bid != null) staffCounts[bid] = (staffCounts[bid] ?? 0) + 1;
      }
      final branches = branchRows
          .map(Branch.fromMap)
          .map((b) => b.copyWith(staffCount: staffCounts[b.id] ?? 0))
          .toList();
      if (mounted)
        setState(() {
          _allBranches = branches;
          _loading = false;
          if (_selected != null) {
            final match = branches.where((b) => b.id == _selected!.id);
            _selected = match.isEmpty ? null : match.first;
          }
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setActive(Branch branch, bool active) async {
    try {
      await _db.updateBranch(branch.id, {'is_active': active});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update branch: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = _allBranches;
    return Padding(
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
                    'Branches',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage branch locations',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddBranchDialog(context),
                icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                label: const Text('Add Branch'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary
          Row(
            children: [
              _BranchStat(
                'Total Branches',
                branches.length.toString(),
                Icons.store_outlined,
                AppTheme.primary,
              ),
              const SizedBox(width: 12),
              _BranchStat(
                'Active',
                branches.where((b) => b.isActive).length.toString(),
                Icons.check_circle_outline,
                AppTheme.success,
              ),
              const SizedBox(width: 12),
              _BranchStat(
                'Total Staff',
                branches.fold(0, (s, b) => s + b.staffCount).toString(),
                Icons.people_outline,
                AppTheme.accent,
              ),
              const SizedBox(width: 12),
              _BranchStat(
                'Packages This Month',
                branches.fold(0, (s, b) => s + b.packagesThisMonth).toString(),
                Icons.inventory_2_outlined,
                AppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _selected != null
                ? Row(
                    children: [
                      Expanded(
                        child: _BranchGrid(
                          branches: branches,
                          selected: _selected,
                          onSelect: (b) => setState(() => _selected = b),
                        ),
                      ),
                      _BranchDetail(
                        branch: _selected!,
                        onClose: () => setState(() => _selected = null),
                        onToggleActive: () => _setActive(_selected!, !_selected!.isActive),
                      ),
                    ],
                  )
                : _BranchGrid(
                    branches: branches,
                    selected: null,
                    onSelect: (b) => setState(() => _selected = b),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBranchDialog(BuildContext context) async {
    final name = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    bool saving = false;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Add New Branch',
                      style: TextStyle(
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
                const SizedBox(height: 20),
                _DField('Branch Name', 'e.g. Spanish Town Branch', controller: name),
                const SizedBox(height: 12),
                _DField('Address', '123 Main Street', controller: address),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _DField('City', 'Kingston', controller: city)),
                    const SizedBox(width: 12),
                    Expanded(child: _DField('Phone', '+1 876 ...', controller: phone)),
                  ],
                ),
                const SizedBox(height: 12),
                _DField('Email', 'branch@company.com', controller: email),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (name.text.trim().isEmpty) {
                                setDialogState(() => error = 'Branch name is required.');
                                return;
                              }
                              setDialogState(() {
                                saving = true;
                                error = null;
                              });
                              try {
                                await _db.insertBranch({
                                  'name': name.text.trim(),
                                  'address': address.text.trim(),
                                  'city': city.text.trim(),
                                  'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
                                  'email': email.text.trim().isEmpty ? null : email.text.trim(),
                                  'is_active': true,
                                });
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx, true);
                              } catch (e) {
                                setDialogState(() {
                                  saving = false;
                                  error = 'Failed to create branch: $e';
                                });
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Branch'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (created == true) _load();
  }
}

class _BranchGrid extends StatelessWidget {
  final List<Branch> branches;
  final Branch? selected;
  final ValueChanged<Branch> onSelect;
  const _BranchGrid({
    required this.branches,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        childAspectRatio: 1.5,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: branches.length,
      itemBuilder: (context, i) {
        final b = branches[i];
        return _BranchCard(
          branch: b,
          isSelected: selected?.id == b.id,
          onTap: () => onSelect(b),
        );
      },
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Branch branch;
  final bool isSelected;
  final VoidCallback onTap;
  const _BranchCard({
    required this.branch,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.store_outlined,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        branch.city,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (branch.isMainBranch)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HQ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 3),
                    StatusBadge(
                      label: branch.isActive ? 'Active' : 'Inactive',
                      color: branch.isActive
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(
              branch.address,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _BranchMetric(
                  icon: Icons.people_outline,
                  value: branch.staffCount.toString(),
                  label: 'Staff',
                ),
                const SizedBox(width: 16),
                _BranchMetric(
                  icon: Icons.inventory_2_outlined,
                  value: branch.packagesThisMonth.toString(),
                  label: 'Pkgs/mo',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _BranchMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 12, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Text(
        '$value $label',
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    ],
  );
}

class _BranchDetail extends StatelessWidget {
  final Branch branch;
  final VoidCallback onClose;
  final VoidCallback onToggleActive;
  const _BranchDetail({
    required this.branch,
    required this.onClose,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Text(
                  'Branch Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store_outlined,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      branch.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (branch.isMainBranch)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Headquarters',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _DKV('Address', branch.address),
                  _DKV('City', branch.city),
                  _DKV('Phone', branch.phone),
                  _DKV('Email', branch.email),
                  _DKV('Status', branch.isActive ? 'Active' : 'Inactive'),
                  const Divider(height: 24),
                  _StatRow(
                    'Staff Members',
                    branch.staffCount.toString(),
                    Icons.people_outline,
                    AppTheme.accent,
                  ),
                  const SizedBox(height: 8),
                  _StatRow(
                    'Packages This Month',
                    branch.packagesThisMonth.toString(),
                    Icons.inventory_2_outlined,
                    AppTheme.primary,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onToggleActive,
                      icon: Icon(
                        branch.isActive
                            ? Icons.block
                            : Icons.check_circle_outline,
                        size: 14,
                        color: branch.isActive
                            ? AppTheme.danger
                            : AppTheme.success,
                      ),
                      label: Text(
                        branch.isActive ? 'Deactivate' : 'Activate',
                        style: TextStyle(
                          color: branch.isActive
                              ? AppTheme.danger
                              : AppTheme.success,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: branch.isActive
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

class _DKV extends StatelessWidget {
  final String k;
  final String v;
  const _DKV(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatRow(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );
}

class _BranchStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _BranchStat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
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
