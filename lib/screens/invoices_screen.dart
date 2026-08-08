import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  InvoiceStatus? _filterStatus;
  Invoice? _selectedInvoice;
  bool _loading = true;

  // Tab 0 = Partner Billing (admin→partner), Tab 1 = Customer Invoices (partner→customer, read-only)
  late final TabController _tabController;
  List<Invoice> _partnerInvoices = []; // invoice_type = partner_billing
  List<Invoice> _customerInvoices = []; // invoice_type = customer_billing

  // Partners fetched from partner_accounts for Bill Partner dialog
  List<Map<String, dynamic>> _partnerAccounts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getInvoices(), // partner_billing
        _db.getCustomerBillingInvoices(), // customer_billing
        _db.getPartnerAccounts(),
      ]);
      if (mounted) {
        setState(() {
          _partnerInvoices = (results[0] as List<Map<String, dynamic>>)
              .map(Invoice.fromMap)
              .toList();
          _customerInvoices = (results[1] as List<Map<String, dynamic>>)
              .map(Invoice.fromMap)
              .toList();
          _partnerAccounts = results[2] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Invoice> get _activeInvoices =>
      _tabController.index == 0 ? _partnerInvoices : _customerInvoices;

  Future<void> _markPaid(Invoice invoice) async {
    try {
      await _db.markInvoicePaid(invoice.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${invoice.invoiceNumber} marked as paid')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark paid: $e')),
      );
    }
  }

  List<Invoice> get _filtered {
    return _activeInvoices.where((inv) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          inv.invoiceNumber.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          inv.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _filterStatus == null || inv.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _openBillPartnerDialog() async {
    String? selectedPartnerId;
    String selectedPartnerName = '';
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? dueDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text(
            'Bill Partner',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Partner',
                  ),
                  value: selectedPartnerId,
                  hint: const Text('Choose a partner'),
                  items: _partnerAccounts
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['id'] as String,
                          child: Text(
                            p['company_name'] as String? ??
                                p['email'] as String? ??
                                '',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setDlg(() {
                      selectedPartnerId = v;
                      final match = _partnerAccounts.firstWhere(
                        (p) => p['id'] == v,
                        orElse: () => {},
                      );
                      selectedPartnerName =
                          match['company_name'] as String? ??
                          match['email'] as String? ??
                          '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount (USD)',
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Due Date:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) setDlg(() => dueDate = picked);
                      },
                      child: Text(
                        dueDate != null
                            ? DateFormat('MMM d, yyyy').format(dueDate!)
                            : 'Pick date',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (selectedPartnerId == null ||
                    amount == null ||
                    amount <= 0) {
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _db.createPartnerInvoice(
                    partnerAccountId: selectedPartnerId!,
                    partnerName: selectedPartnerName,
                    amount: amount,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                    dueDate: dueDate?.toIso8601String(),
                  );
                  await _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Create Invoice'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final totalInvoiced = _activeInvoices.fold(0.0, (s, i) => s + i.total);
    final paidAmt = _activeInvoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0.0, (s, i) => s + i.total);
    final overdueAmt = _activeInvoices
        .where((i) => i.status == InvoiceStatus.overdue)
        .fold(0.0, (s, i) => s + i.total);
    final outstanding = totalInvoiced - paidAmt - overdueAmt;
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
                          'Invoices',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage billing and payments',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_tabController.index == 0)
                      ElevatedButton.icon(
                        onPressed: _openBillPartnerDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Bill Partner'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tabs
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  tabs: const [
                    Tab(text: 'Partner Billing'),
                    Tab(text: 'Customer Invoices'),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 700 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.4,
                      children: [
                        _InvoiceSummaryCard(
                          label: 'Total Invoiced',
                          value: currencyFormat.format(totalInvoiced),
                          color: AppTheme.primary,
                          icon: Icons.receipt_long,
                        ),
                        _InvoiceSummaryCard(
                          label: 'Paid',
                          value: currencyFormat.format(paidAmt),
                          color: AppTheme.success,
                          icon: Icons.check_circle_outline,
                        ),
                        _InvoiceSummaryCard(
                          label: 'Outstanding',
                          value: currencyFormat.format(outstanding),
                          color: AppTheme.accent,
                          icon: Icons.hourglass_empty,
                        ),
                        _InvoiceSummaryCard(
                          label: 'Overdue',
                          value: currencyFormat.format(overdueAmt),
                          color: AppTheme.danger,
                          icon: Icons.warning_amber_outlined,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Search and filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: _tabController.index == 0
                              ? 'Search by invoice # or partner...'
                              : 'Search by invoice # or customer...',
                          hintStyle: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 42,
                            minHeight: 42,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _InvoiceStatusFilter(
                      value: _filterStatus,
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Column header label for partner tab
                if (_tabController.index == 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Showing invoices billed to shipping partners by admin. Partners cannot see these.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Read-only view of invoices that partners sent to their customers.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Invoices list
                Expanded(
                  child: Card(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            color: AppTheme.surface,
                            border: Border(
                              bottom: BorderSide(color: AppTheme.border),
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(flex: 2, child: _TH('Invoice #')),
                              Expanded(
                                flex: 2,
                                child: _TH(
                                  _tabController.index == 0
                                      ? 'Partner'
                                      : 'Customer',
                                ),
                              ),
                              const Expanded(flex: 1, child: _TH('Date')),
                              const Expanded(flex: 1, child: _TH('Due Date')),
                              const Expanded(flex: 1, child: _TH('Amount')),
                              const Expanded(flex: 1, child: _TH('Status')),
                              const SizedBox(width: 36),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _filtered.isEmpty
                              ? const EmptyState(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'No invoices found',
                                  subtitle: 'Try adjusting your filters',
                                )
                              : ListView.builder(
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    final inv = _filtered[index];
                                    return _InvoiceRow(
                                      invoice: inv,
                                      isSelected:
                                          _selectedInvoice?.id == inv.id,
                                      onTap: () => setState(
                                        () => _selectedInvoice =
                                            _selectedInvoice?.id == inv.id
                                            ? null
                                            : inv,
                                      ),
                                      onMarkPaid: _tabController.index == 0
                                          ? () => _markPaid(inv)
                                          : null,
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

        // Invoice detail panel
        if (_selectedInvoice != null)
          _InvoiceDetailPanel(
            invoice: _selectedInvoice!,
            onClose: () => setState(() => _selectedInvoice = null),
          ),
      ],
    );
  }
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

class _InvoiceSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _InvoiceSummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
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
    );
  }
}

class _InvoiceStatusFilter extends StatelessWidget {
  final InvoiceStatus? value;
  final ValueChanged<InvoiceStatus?> onChanged;

  const _InvoiceStatusFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<InvoiceStatus?>(
          value: value,
          hint: const Text(
            'All Statuses',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('All Statuses', style: TextStyle(fontSize: 13)),
            ),
            ...InvoiceStatus.values.map(
              (s) => DropdownMenuItem(
                value: s,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(s.label, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Invoice invoice;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onMarkPaid;

  const _InvoiceRow({
    required this.invoice,
    required this.isSelected,
    required this.onTap,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isOverdue = invoice.status == InvoiceStatus.overdue;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.05)
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
              child: Text(
                invoice.invoiceNumber,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(flex: 2, child: _cell(invoice.customerName)),
            Expanded(
              flex: 1,
              child: _cell(dateFormat.format(invoice.createdAt)),
            ),
            Expanded(
              flex: 1,
              child: Text(
                invoice.dueAt == null
                    ? 'No due date'
                    : dateFormat.format(invoice.dueAt!),
                style: TextStyle(
                  fontSize: 13,
                  color: isOverdue ? AppTheme.danger : AppTheme.textPrimary,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '\$${invoice.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: StatusBadge(
                label: invoice.status.label,
                color: invoice.status.color,
              ),
            ),
            SizedBox(
              width: 36,
              child: onMarkPaid == null || invoice.status == InvoiceStatus.paid
                  ? const SizedBox.shrink()
                  : PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'mark_paid',
                          child: ListTile(
                            leading: Icon(Icons.check_circle_outline, size: 18),
                            title: Text('Mark as Paid', style: TextStyle(fontSize: 13)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'mark_paid') onMarkPaid?.call();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
    overflow: TextOverflow.ellipsis,
  );
}

class _InvoiceDetailPanel extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onClose;

  const _InvoiceDetailPanel({required this.invoice, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    return Container(
      width: 340,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      StatusBadge(
                        label: invoice.status.label,
                        color: invoice.status.color,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoSection(
                    children: [
                      _KV('Customer', invoice.customerName),
                      _KV('Issue Date', dateFormat.format(invoice.createdAt)),
                      _KV(
                        'Due Date',
                        invoice.dueAt == null
                            ? 'No due date'
                            : dateFormat.format(invoice.dueAt!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Line items
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Description',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                'Qty',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              SizedBox(width: 40),
                              Text(
                                'Amount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...invoice.lineItems.map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.border,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    '\$${item.total.toStringAsFixed(2)}',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppTheme.surface,
                            border: Border(
                              top: BorderSide(color: AppTheme.border),
                            ),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                          ),
                          child: Column(
                            children: [
                              _AmountRow(
                                'Subtotal',
                                '\$${invoice.subtotal.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 4),
                              _AmountRow(
                                'Tax (10%)',
                                '\$${invoice.tax.toStringAsFixed(2)}',
                              ),
                              const Divider(height: 16, color: AppTheme.border),
                              Row(
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    currencyFormat.format(invoice.total),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadInvoicePdf(invoice),
                      icon: const Icon(Icons.download_outlined, size: 14),
                      label: const Text(
                        'Download PDF',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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

  Future<void> _downloadInvoicePdf(Invoice invoice) async {
    final dateFormat = DateFormat('MMM d, yyyy');
    await ExportService.downloadPdf(
      filename: '${invoice.invoiceNumber}.pdf',
      title: 'Invoice ${invoice.invoiceNumber}',
      subtitle:
          '${invoice.customerName} · Created ${dateFormat.format(invoice.createdAt)} · '
          '${invoice.dueAt == null ? 'No due date' : 'Due ${dateFormat.format(invoice.dueAt!)}'}',
      headers: const ['Item', 'Qty', 'Unit Price', 'Total'],
      rows: [
        for (final li in invoice.lineItems)
          [
            li.description,
            li.quantity.toString(),
            '\$${li.unitPrice.toStringAsFixed(2)}',
            '\$${(li.quantity * li.unitPrice).toStringAsFixed(2)}',
          ],
      ],
      summary: {
        'Subtotal': '\$${invoice.subtotal.toStringAsFixed(2)}',
        'Tax': '\$${invoice.tax.toStringAsFixed(2)}',
        'Total': '\$${invoice.total.toStringAsFixed(2)}',
        'Status': invoice.status.label,
      },
    );
  }
}

class _InfoSection extends StatelessWidget {
  final List<Widget> children;
  const _InfoSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _KV extends StatelessWidget {
  final String key2;
  final String value;
  const _KV(this.key2, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              key2,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String amount;
  const _AmountRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          amount,
          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}
