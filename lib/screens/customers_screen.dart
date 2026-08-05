import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool? _filterActive;
  Customer? _selectedCustomer;
  bool _loading = true;
  List<Customer> _allCustomers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getCustomers(),
        _db.getPackages(),
        _db.getCustomerBillingInvoices(),
      ]);
      final customerRows = (results[0] as List).cast<Map<String, dynamic>>();
      final packageRows = (results[1] as List).cast<Map<String, dynamic>>();
      final invoiceRows = (results[2] as List).cast<Map<String, dynamic>>();

      final packageCounts = <String, int>{};
      for (final p in packageRows) {
        final cid = p['customer_id']?.toString();
        if (cid != null) packageCounts[cid] = (packageCounts[cid] ?? 0) + 1;
      }
      final balances = <String, double>{};
      for (final inv in invoiceRows) {
        if (inv['status']?.toString() == 'paid') continue;
        final cid = inv['customer_id']?.toString();
        if (cid == null) continue;
        final total = (inv['total'] as num?)?.toDouble() ?? 0;
        balances[cid] = (balances[cid] ?? 0) + total;
      }

      final customers = customerRows.map(Customer.fromMap).map((c) {
        return c.copyWith(
          totalPackages: packageCounts[c.id] ?? 0,
          balance: balances[c.id] ?? 0,
        );
      }).toList();

      if (mounted)
        setState(() {
          _allCustomers = customers;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> get _filtered {
    return _allCustomers.where((c) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.address.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesActive =
          _filterActive == null || c.isActive == _filterActive;
      return matchesSearch && matchesActive;
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
                          'Customers',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage your customer accounts',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showNewCustomerDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Customer'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Search + filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Search by name, email, city...',
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
                    _StatusFilterChip(
                      label: 'Active',
                      selected: _filterActive == true,
                      onTap: () => setState(
                        () =>
                            _filterActive = _filterActive == true ? null : true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: 'Inactive',
                      selected: _filterActive == false,
                      onTap: () => setState(
                        () => _filterActive = _filterActive == false
                            ? null
                            : false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Grid or list
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline,
                          title: 'No customers found',
                          subtitle: 'Try adjusting your search',
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final crossCount = constraints.maxWidth > 1000
                                ? 3
                                : (constraints.maxWidth > 650 ? 2 : 1);
                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 2.2,
                                  ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final c = _filtered[index];
                                return _CustomerCard(
                                  customer: c,
                                  isSelected: _selectedCustomer?.id == c.id,
                                  onTap: () => setState(
                                    () => _selectedCustomer =
                                        _selectedCustomer?.id == c.id
                                        ? null
                                        : c,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Detail panel
        if (_selectedCustomer != null)
          _CustomerDetailPanel(
            customer: _selectedCustomer!,
            onClose: () => setState(() => _selectedCustomer = null),
          ),
      ],
    );
  }

  Future<void> _showNewCustomerDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const _NewCustomerDialog(),
    );
    if (result != null) _load();
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary.withOpacity(0.12),
                    child: Text(
                      customer.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          customer.email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: customer.isActive ? 'Active' : 'Inactive',
                    color: customer.isActive
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                  ),
                ],
              ),
              const Divider(height: 16, color: AppTheme.border),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${customer.city}, ${customer.country}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 13,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${customer.totalPackages} pkgs',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (customer.balance > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 13,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Balance: \$${customer.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDetailPanel extends StatefulWidget {
  final Customer customer;
  final VoidCallback onClose;

  const _CustomerDetailPanel({required this.customer, required this.onClose});

  @override
  State<_CustomerDetailPanel> createState() => _CustomerDetailPanelState();
}

class _CustomerDetailPanelState extends State<_CustomerDetailPanel> {
  final _db = DatabaseService();
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _db.getPackagesByCustomer(widget.customer.id).then((rows) {
      if (mounted)
        setState(() => _packages = rows.map(Package.fromMap).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerPackages = _packages;

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Text(
                  'Customer Profile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
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
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primary.withOpacity(0.12),
                    child: Text(
                      widget.customer.name.substring(0, 1),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.customer.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  StatusBadge(
                    label: widget.customer.isActive ? 'Active' : 'Inactive',
                    color: widget.customer.isActive
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),

                  _InfoCard(
                    children: [
                      _InfoRow(Icons.email_outlined, widget.customer.email),
                      _InfoRow(Icons.phone_outlined, widget.customer.phone),
                      _InfoRow(
                        Icons.location_on_outlined,
                        widget.customer.address,
                      ),
                      _InfoRow(
                        Icons.calendar_today_outlined,
                        'Joined ${DateFormat('MMM yyyy').format(widget.customer.joinedAt)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          label: 'Packages',
                          value: _packages.length.toString(),
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStatCard(
                          label: 'Balance',
                          value: '\$${widget.customer.balance.toStringAsFixed(2)}',
                          color: widget.customer.balance > 0
                              ? AppTheme.warning
                              : AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (customerPackages.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recent Packages',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...customerPackages
                        .take(3)
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.trackingNumber,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        Text(
                                          p.description,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(
                                    label: p.status.label,
                                    color: p.status.color,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NewCustomerDialog extends StatefulWidget {
  const _NewCustomerDialog();

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  final _db = DatabaseService();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final addressParts = [
        _address.text.trim(),
        _city.text.trim(),
        _country.text.trim(),
      ].where((p) => p.isNotEmpty).join(', ');
      final row = await _db.insertCustomer({
        'name': _name.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'address': addressParts.isEmpty ? null : addressParts,
        'status': 'active',
      });
      if (!mounted) return;
      Navigator.pop(context, row);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to add customer: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Add Customer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildField('Full Name', 'e.g. John Doe', _name),
            const SizedBox(height: 12),
            _buildRow([
              ('Email', 'john@example.com', _email),
              ('Phone', '+1 000 000 0000', _phone),
            ]),
            const SizedBox(height: 12),
            _buildField('Address', 'Street address', _address),
            const SizedBox(height: 12),
            _buildRow([
              ('City', 'City', _city),
              ('Country', 'Country', _country),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _create,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Customer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController controller) {
    return Column(
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

  Widget _buildRow(List<(String, String, TextEditingController)> fields) {
    return Row(
      children:
          fields
              .expand(
                (f) => [
                  Expanded(child: _buildField(f.$1, f.$2, f.$3)),
                  const SizedBox(width: 12),
                ],
              )
              .toList()
            ..removeLast(),
    );
  }
}
