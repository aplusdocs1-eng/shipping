import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _db = DatabaseService();
  final List<PosCartItem> _cart = [];
  String? _selectedCategory;
  String _paymentMethod = 'Cash';
  String _query = '';
  bool _loading = true;
  bool _checkingOut = false;
  List<PosItem> _items = [];
  List<PosTransaction> _transactions = [];
  List<Customer> _customers = [];
  Customer? _selectedCustomer;

  final currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getPosItems(),
        _db.getPosTransactions(),
        _db.getCustomers(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (results[0] as List)
            .cast<Map<String, dynamic>>()
            .map(PosItem.fromMap)
            .toList();
        _transactions = (results[1] as List)
            .cast<Map<String, dynamic>>()
            .map(PosTransaction.fromMap)
            .toList();
        _customers = (results[2] as List)
            .cast<Map<String, dynamic>>()
            .map(Customer.fromMap)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load POS data: $e')));
    }
  }

  List<String> get _categories {
    final cats = _items
        .where((i) => i.isActive)
        .map((i) => i.category)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<PosItem> get _filteredItems {
    return _items.where((i) {
      final matchCat =
          _selectedCategory == null || i.category == _selectedCategory;
      final matchQ =
          _query.isEmpty ||
          i.name.toLowerCase().contains(_query.toLowerCase()) ||
          i.category.toLowerCase().contains(_query.toLowerCase());
      return matchCat && matchQ && i.isActive;
    }).toList();
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.total);
  double get _tax => _subtotal * 0.15;
  double get _total => _subtotal + _tax;

  void _addToCart(PosItem item) {
    setState(() {
      final existingIdx = _cart.indexWhere((c) => c.item.id == item.id);
      if (existingIdx >= 0) {
        final existing = _cart[existingIdx];
        _cart[existingIdx] = PosCartItem(
          item: item,
          quantity: existing.quantity + 1,
        );
      } else {
        _cart.add(PosCartItem(item: item, quantity: 1));
      }
    });
  }

  void _removeFromCart(String itemId) {
    setState(() {
      _cart.removeWhere((c) => c.item.id == itemId);
    });
  }

  void _updateQty(String itemId, int delta) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.item.id == itemId);
      if (idx < 0) return;
      final current = _cart[idx];
      final newQty = current.quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(idx);
      } else {
        _cart[idx] = PosCartItem(item: current.item, quantity: newQty);
      }
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _checkingOut) return;
    setState(() => _checkingOut = true);
    final receiptNumber =
        'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final customerName = _selectedCustomer?.name ?? 'Walk-in customer';
    final subtotal = _subtotal;
    final tax = _tax;
    final total = _total;
    final method = _paymentMethod;
    try {
      await _db.insertPosTransaction(
        receiptNumber: receiptNumber,
        customerId: _selectedCustomer?.id,
        customerName: customerName,
        subtotal: subtotal,
        tax: tax,
        total: total,
        paymentMethod: method,
        items: _cart
            .map(
              (c) => {
                'pos_item_id': c.item.id,
                'item_name': c.item.name,
                'unit_price': c.item.price,
                'quantity': c.quantity,
                'line_total': c.total,
              },
            )
            .toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete sale: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _checkingOut = false;
      _cart.clear();
      _selectedCustomer = null;
    });
    unawaited(_load());
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Transaction Complete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                receiptNumber,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currencyFormat.format(total),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Paid via $method · $customerName',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('New Sale'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManageItemsDialog() {
    showDialog(
      context: context,
      builder: (context) => _ManageItemsDialog(db: _db, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Row(
      children: [
        // Left: catalog
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Point of Sale',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Select services to add to cart',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showManageItemsDialog,
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Manage Items'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search services...',
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
                const SizedBox(height: 12),
                // Category filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CatChip(
                        label: 'All',
                        selected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      ..._categories.map(
                        (c) => _CatChip(
                          label: c,
                          selected: _selectedCategory == c,
                          onTap: () => setState(
                            () => _selectedCategory = _selectedCategory == c
                                ? null
                                : c,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            _items.isEmpty
                                ? 'No items in the catalog yet — add one with "Manage Items".'
                                : 'No items match your search.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                                childAspectRatio: 1.4,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, i) {
                            final item = _filteredItems[i];
                            final inCart = _cart.any(
                              (c) => c.item.id == item.id,
                            );
                            return _ServiceCard(
                              item: item,
                              inCart: inCart,
                              onTap: () => _addToCart(item),
                            );
                          },
                        ),
                ),
                // Recent transactions
                const SizedBox(height: 16),
                const SectionHeader(title: 'Recent Transactions'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: _transactions.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No sales yet — completed sales will show up here.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _transactions.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final t = _transactions[i];
                            return _TransactionChip(transaction: t);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Right: cart
        Container(
          width: 320,
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
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Cart',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_cart.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _cart.clear()),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _cart.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              color: AppTheme.border,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Cart is empty',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              'Tap a service to add it',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _cart.length,
                        itemBuilder: (context, i) {
                          final item = _cart[i];
                          return _CartRow(
                            cartItem: item,
                            onRemove: () => _removeFromCart(item.item.id),
                            onPlus: () => _updateQty(item.item.id, 1),
                            onMinus: () => _updateQty(item.item.id, -1),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Customer?>(
                          isExpanded: true,
                          value: _selectedCustomer,
                          hint: const Text(
                            'Walk-in customer',
                            style: TextStyle(fontSize: 13),
                          ),
                          items: [
                            const DropdownMenuItem<Customer?>(
                              value: null,
                              child: Text(
                                'Walk-in customer',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            for (final c in _customers)
                              DropdownMenuItem<Customer?>(
                                value: c,
                                child: Text(
                                  c.name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedCustomer = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_subtotal),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'GCT (15%)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_tax),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _paymentMethod,
                          items: ['Cash', 'Card', 'Bank Transfer']
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: (_cart.isEmpty || _checkingOut)
                            ? null
                            : _checkout,
                        icon: _checkingOut
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.point_of_sale, size: 16),
                        label: Text(
                          _checkingOut ? 'Processing…' : 'Complete Sale',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class _ServiceCard extends StatelessWidget {
  final PosItem item;
  final bool inCart;
  final VoidCallback onTap;
  const _ServiceCard({
    required this.item,
    required this.inCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: inCart
              ? AppTheme.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: inCart ? AppTheme.primary : AppTheme.border,
            width: inCart ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (inCart)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.primary,
                    size: 14,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '\$${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final PosCartItem cartItem;
  final VoidCallback onRemove;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  const _CartRow({
    required this.cartItem,
    required this.onRemove,
    required this.onPlus,
    required this.onMinus,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cartItem.item.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '\$${cartItem.total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.primary),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _QtyBtn(icon: Icons.remove, onTap: onMinus),
            SizedBox(
              width: 28,
              child: Text(
                cartItem.quantity.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _QtyBtn(icon: Icons.add, onTap: onPlus),
          ],
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(
            Icons.close,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(icon, size: 12, color: AppTheme.textSecondary),
    ),
  );
}

class _TransactionChip extends StatelessWidget {
  final PosTransaction transaction;
  const _TransactionChip({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, h:mm a');
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.receiptNumber,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '\$${transaction.total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            transaction.customerName,
            style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${transaction.paymentMethod} · ${df.format(transaction.createdAt)}',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Manage Items ────────────────────────────────────────────────────────

/// Lets an admin add, edit, and activate/deactivate catalog items without
/// needing direct database access. Deactivating (not deleting) keeps
/// historical transaction line items — which store their own copy of the
/// item's name/price at time of sale — intact and meaningful.
class _ManageItemsDialog extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onChanged;
  const _ManageItemsDialog({required this.db, required this.onChanged});

  @override
  State<_ManageItemsDialog> createState() => _ManageItemsDialogState();
}

class _ManageItemsDialogState extends State<_ManageItemsDialog> {
  List<PosItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.db.getPosItems();
    if (!mounted) return;
    setState(() {
      _items = rows.map(PosItem.fromMap).toList();
      _loading = false;
    });
  }

  Future<void> _toggleActive(PosItem item) async {
    await widget.db.updatePosItem(item.id, {'is_active': !item.isActive});
    widget.onChanged();
    await _load();
  }

  void _showItemForm({PosItem? existing}) {
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final categoryCtl = TextEditingController(text: existing?.category ?? '');
    final priceCtl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final unitCtl = TextEditingController(text: existing?.unit ?? '');
    String? error;
    bool saving = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Item' : 'Edit Item'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryCtl,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Shipping, Delivery, Add-on',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitCtl,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'e.g. per lb, per delivery, per box',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtl.text.trim();
                      final price = double.tryParse(priceCtl.text.trim());
                      if (name.isEmpty) {
                        setDialogState(() => error = 'Enter a name.');
                        return;
                      }
                      if (price == null || price < 0) {
                        setDialogState(
                          () => error = 'Enter a valid, non-negative price.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final payload = {
                        'name': name,
                        'category': categoryCtl.text.trim(),
                        'price': price,
                        'unit': unitCtl.text.trim(),
                      };
                      try {
                        if (existing == null) {
                          await widget.db.insertPosItem(payload);
                        } else {
                          await widget.db.updatePosItem(
                            existing.id,
                            payload,
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = 'Failed to save: $e';
                        });
                        return;
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      widget.onChanged();
                      _load();
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Items'),
      content: SizedBox(
        width: 480,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showItemForm(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item'),
                    ),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              'No items yet — add your first one above.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: item.isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                    color: item.isActive
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.category.isEmpty ? 'Uncategorized' : item.category} · '
                                  '\$${item.price.toStringAsFixed(2)}'
                                  '${item.unit.isEmpty ? '' : ' ${item.unit}'}',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      tooltip: 'Edit',
                                      onPressed: () =>
                                          _showItemForm(existing: item),
                                    ),
                                    Switch(
                                      value: item.isActive,
                                      onChanged: (_) => _toggleActive(item),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
