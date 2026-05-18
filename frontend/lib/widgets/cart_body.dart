import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/order_service.dart';
import 'receipt_dialog.dart';

class CartBody extends StatefulWidget {
  final bool inSheet;
  const CartBody({super.key, this.inSheet = false});

  @override
  State<CartBody> createState() => _CartBodyState();
}

class _CartBodyState extends State<CartBody> {
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  bool _charging = false;
  bool _holding = false;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _customerNameCtrl;
  late final TextEditingController _customerPhoneCtrl;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartService>();
    _discountCtrl = TextEditingController(
      text: cart.discountValue > 0
          ? cart.discountValue.toStringAsFixed(0)
          : '',
    );
    _customerNameCtrl = TextEditingController(text: cart.customerName);
    _customerPhoneCtrl = TextEditingController(text: cart.customerPhone);
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkout(CartService cart, {required bool hold}) async {
    if (cart.isEmpty) return;
    if (hold && _holding) return;
    if (!hold && _charging) return;
    setState(() {
      if (hold) {
        _holding = true;
      } else {
        _charging = true;
      }
    });
    try {
      final orderSvc = context.read<OrderService>();
      final customerMap = <String, String>{};
      if (cart.customerName.isNotEmpty) customerMap['name'] = cart.customerName;
      if (cart.customerPhone.isNotEmpty)
        customerMap['phone'] = cart.customerPhone;
      if (cart.customerAddress.isNotEmpty)
        customerMap['address'] = cart.customerAddress;

      late final order;
      if (cart.heldOrderId != null && !hold) {
        // Settling a previously held order.
        order =
            await orderSvc.settle(cart.heldOrderId!, cart.paymentMethod);
      } else {
        order = await orderSvc.create(
          cart: cart.items,
          paymentMethod: cart.paymentMethod,
          orderType: cart.orderType,
          discountType: cart.discountType,
          discountValue: cart.discountValue,
          customer: customerMap.isNotEmpty ? customerMap : null,
          tableId: cart.tableId,
          tableLabel: cart.tableLabel,
          hold: hold,
        );
      }
      if (!mounted) return;
      cart.clear();
      _discountCtrl.text = '';
      _customerNameCtrl.text = '';
      _customerPhoneCtrl.text = '';
      if (widget.inSheet) Navigator.of(context).pop();
      if (hold) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Held: bill ${order.billNumber ?? order.orderNumber}')),
        );
      } else {
        await showDialog(
          context: context,
          builder: (_) => ReceiptDialog(order: order),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _charging = false;
          _holding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final isDelivery = cart.orderType == 'delivery';

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text('Cart (${cart.count})',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (cart.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    cart.clear();
                    _discountCtrl.text = '';
                    _customerNameCtrl.text = '';
                    _customerPhoneCtrl.text = '';
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
              if (widget.inSheet)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),

        // Order type tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'dine-in', label: Text('Dine-In')),
              ButtonSegment(value: 'delivery', label: Text('Delivery')),
              ButtonSegment(value: 'pick-up', label: Text('Pick-Up')),
            ],
            selected: {cart.orderType},
            onSelectionChanged: (s) => cart.setOrderType(s.first),
          ),
        ),

        const Divider(height: 1),

        // Items list
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
                            icon: const Icon(Icons.remove_circle_outline),
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

        // Customer fields (collapsible)
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          initiallyExpanded: cart.customerPhone.isNotEmpty || isDelivery,
          title: Text(
            cart.customerName.isEmpty
                ? 'Customer (optional)'
                : '${cart.customerName} · ${cart.customerPhone}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _customerPhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => cart.setCustomer(phone: v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _customerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      isDense: true,
                    ),
                    onChanged: (v) => cart.setCustomer(name: v),
                  ),
                ),
              ],
            ),
            if (isDelivery) ...[
              const SizedBox(height: 6),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                  isDense: true,
                ),
                maxLines: 2,
                onChanged: (v) => cart.setCustomer(address: v),
              ),
            ],
          ],
        ),

        const Divider(height: 1),

        // Totals + controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(context, 'Subtotal', _money.format(cart.subtotal)),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: SegmentedButton<String>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: 'fixed', label: Text('₹')),
                        ButtonSegment(value: 'percent', label: Text('%')),
                      ],
                      selected: {cart.discountType},
                      onSelectionChanged: (s) =>
                          cart.setDiscount(type: s.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      enabled: cart.isNotEmpty,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Discount',
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          cart.setDiscount(value: double.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_money.format(cart.discount),
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 4),
              _row(context,
                  'Tax (${(cart.taxRate * 100).toStringAsFixed(0)}%)',
                  _money.format(cart.tax)),
              const SizedBox(height: 4),
              _row(context, 'Total', _money.format(cart.total), bold: true),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash')),
                  ButtonSegment(value: 'card', label: Text('Card')),
                  ButtonSegment(value: 'upi', label: Text('UPI')),
                ],
                selected: {cart.paymentMethod},
                onSelectionChanged: (s) => cart.setPaymentMethod(s.first),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: cart.isEmpty || _holding || _charging
                          ? null
                          : () => _checkout(cart, hold: true),
                      icon: _holding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.pause_circle_outline),
                      label: const Text('Hold'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: cart.isEmpty || _charging || _holding
                          ? null
                          : () => _checkout(cart, hold: false),
                      icon: _charging
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_charging
                          ? 'Processing…'
                          : 'Charge ${_money.format(cart.total)}'),
                    ),
                  ),
                ],
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
