import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../widgets/receipt_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late Future<List<MenuItem>> _itemsFuture;
  final List<CartLine> _cart = [];
  String _search = '';
  String _category = 'All';
  String _payment = 'cash';
  double _discount = 0;

  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _itemsFuture = context.read<MenuService>().list();
  }

  void _addToCart(MenuItem item) {
    setState(() {
      final existing = _cart.indexWhere((c) => c.item.id == item.id);
      if (existing >= 0) {
        _cart[existing].quantity += 1;
      } else {
        _cart.add(CartLine(item: item));
      }
    });
  }

  double get _subtotal => _cart.fold(0, (s, c) => s + c.lineTotal);
  double get _tax => ((_subtotal - _discount).clamp(0, double.infinity)) * 0.05;
  double get _total => (_subtotal - _discount).clamp(0, double.infinity) + _tax;

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    try {
      final order = await context.read<OrderService>().create(
            cart: _cart,
            paymentMethod: _payment,
            discount: _discount,
          );
      if (!mounted) return;
      setState(() => _cart.clear());
      await showDialog(
        context: context,
        builder: (_) => ReceiptDialog(order: order),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MenuItem>>(
      future: _itemsFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error loading menu: ${snap.error}'));
        }
        final all = snap.data ?? [];
        final categories = ['All', ...{for (final i in all) i.category}];
        final filtered = all.where((i) {
          if (_category != 'All' && i.category != _category) return false;
          if (_search.isNotEmpty &&
              !i.name.toLowerCase().contains(_search.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        final isWide = MediaQuery.of(context).size.width >= 900;

        final menuPane = Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _category,
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'All'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final item = filtered[i];
                  return InkWell(
                    onTap: item.available ? () => _addToCart(item) : null,
                    child: Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.category,
                                style: Theme.of(context).textTheme.bodySmall),
                            const Spacer(),
                            Text(item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(_money.format(item.price),
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                            if (!item.available)
                              const Text('Unavailable',
                                  style: TextStyle(color: Colors.red, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

        final cartPane = _CartPanel(
          cart: _cart,
          subtotal: _subtotal,
          tax: _tax,
          total: _total,
          discount: _discount,
          payment: _payment,
          onDiscount: (v) => setState(() => _discount = v),
          onPayment: (v) => setState(() => _payment = v),
          onIncrement: (line) => setState(() => line.quantity += 1),
          onDecrement: (line) => setState(() {
            line.quantity -= 1;
            if (line.quantity <= 0) _cart.remove(line);
          }),
          onClear: () => setState(_cart.clear),
          onCheckout: _checkout,
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: menuPane),
              const VerticalDivider(width: 1),
              SizedBox(width: 380, child: cartPane),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: menuPane),
            const Divider(height: 1),
            SizedBox(height: 320, child: cartPane),
          ],
        );
      },
    );
  }
}

class _CartPanel extends StatelessWidget {
  final List<CartLine> cart;
  final double subtotal, tax, total, discount;
  final String payment;
  final ValueChanged<double> onDiscount;
  final ValueChanged<String> onPayment;
  final void Function(CartLine) onIncrement;
  final void Function(CartLine) onDecrement;
  final VoidCallback onClear;
  final VoidCallback onCheckout;

  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  const _CartPanel({
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.discount,
    required this.payment,
    required this.onDiscount,
    required this.onPayment,
    required this.onIncrement,
    required this.onDecrement,
    required this.onClear,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Text('Cart', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: cart.isEmpty ? null : onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('Tap items to add to cart'))
              : ListView.separated(
                  itemCount: cart.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final line = cart[i];
                    return ListTile(
                      title: Text(line.item.name),
                      subtitle: Text(_money.format(line.item.price)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => onDecrement(line),
                          ),
                          Text('${line.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => onIncrement(line),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(context, 'Subtotal', _money.format(subtotal)),
              Row(
                children: [
                  const Text('Discount'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                          isDense: true, prefixText: '₹'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          onDiscount(double.tryParse(v) ?? 0),
                    ),
                  ),
                ],
              ),
              _row(context, 'Tax (5%)', _money.format(tax)),
              const SizedBox(height: 6),
              _row(context, 'Total', _money.format(total), bold: true),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash')),
                  ButtonSegment(value: 'card', label: Text('Card')),
                  ButtonSegment(value: 'upi', label: Text('UPI')),
                ],
                selected: {payment},
                onSelectionChanged: (s) => onPayment(s.first),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: cart.isEmpty ? null : onCheckout,
                icon: const Icon(Icons.check_circle),
                label: const Text('Charge'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
