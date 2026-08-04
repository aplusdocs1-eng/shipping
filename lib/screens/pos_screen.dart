import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final List<PosCartItem> _cart = [];
  String? _selectedCategory;
  String _paymentMethod = 'Cash';
  String _query = '';

  final currencyFormat = NumberFormat.currency(symbol: '\$');

  List<String> get _categories {
    final cats = MockDataService().posItems
        .map((i) => i.category)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<PosItem> get _filteredItems {
    return MockDataService().posItems.where((i) {
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

  void _checkout() {
    if (_cart.isEmpty) return;
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
              const SizedBox(height: 8),
              Text(
                currencyFormat.format(_total),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Paid via $_paymentMethod',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.print_outlined, size: 14),
                      label: const Text('Print Receipt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _cart.clear());
                      },
                      child: const Text('New Sale'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
                  child: GridView.builder(
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
                      final inCart = _cart.any((c) => c.item.id == item.id);
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
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: MockDataService().posTransactions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final t = MockDataService().posTransactions[i];
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
                        onPressed: _cart.isEmpty ? null : _checkout,
                        icon: const Icon(Icons.point_of_sale, size: 16),
                        label: const Text('Complete Sale'),
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
          color: inCart ? AppTheme.primary.withOpacity(0.05) : Colors.white,
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
            transaction.id,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontFamily: 'monospace',
            ),
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
            transaction.paymentMethod,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          Text(
            df.format(transaction.createdAt),
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
