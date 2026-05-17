import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/order_service.dart';
import 'receipt_dialog.dart';

/// Modal bottom sheet showing the cart, totals, payment method,
/// and the Charge button.
class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CartSheet(),
    );
  }

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  bool _charging = false;
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartService>();
    _discountCtrl = TextEditingController(
      text: cart.discount > 0 ? cart.discount.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkout(CartService cart) async {
    if (cart.isEmpty || _charging) return;
    setState(() => _charging = true);
    try {
      final orderSvc = context.read<OrderService>();
      final order = await orderSvc.create(
        cart: cart.items,
        paymentMethod: cart.paymentMethod,
        discount: cart.discount,
      );
      if (!mounted) return;
      cart.clear();
      Navigator.of(context).pop(); // close sheet
      await showDialog(
        context: context,
        builder: (_) => ReceiptDialog(order: order),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _charging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final mq = MediaQuery.of(context);

    return Padding(
      // Account for the on-screen keyboard when the discount field is focused.
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.85,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Text('Cart (${cart.count})',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (cart.isNotEmpty)
                    TextButton.icon(
                      onPressed: cart.clear,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Items
            Expanded(
              child: cart.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Your cart is empty.\nTap items in the menu to add.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final line = cart.items[i];
                        return ListTile(
                          title: Text(line.item.name),
                          subtitle: Text(
                              '${_money.format(line.item.price)}  ·  ${_money.format(line.lineTotal)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.remove_circle_outline),
                                onPressed: () => cart.decrement(line),
                              ),
                              Text('${line.quantity}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cart.increment(line),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // Totals + controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(context, 'Subtotal', _money.format(cart.subtotal)),
                  Row(
                    children: [
                      const SizedBox(
                          width: 80, child: Text('Discount')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _discountCtrl,
                          enabled: cart.isNotEmpty,
                          decoration: const InputDecoration(
                            isDense: true,
                            prefixText: '₹ ',
                            hintText: '0',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              cart.setDiscount(double.tryParse(v) ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _row(context, 'Tax (5%)', _money.format(cart.tax)),
                  const SizedBox(height: 4),
                  _row(context, 'Total', _money.format(cart.total),
                      bold: true),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('Cash')),
                      ButtonSegment(value: 'card', label: Text('Card')),
                      ButtonSegment(value: 'upi', label: Text('UPI')),
                    ],
                    selected: {cart.paymentMethod},
                    onSelectionChanged: (s) =>
                        cart.setPaymentMethod(s.first),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        cart.isEmpty || _charging ? null : () => _checkout(cart),
                    icon: _charging
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_charging
                        ? 'Processing…'
                        : 'Charge ${_money.format(cart.total)}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
