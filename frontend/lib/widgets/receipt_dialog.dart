import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';

class ReceiptDialog extends StatelessWidget {
  final OrderSummary order;
  ReceiptDialog({super.key, required this.order});

  final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _ts = DateFormat('dd MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receipt'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hunger Cafe',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Order #${order.orderNumber}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              Text(_ts.format(order.createdAt),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              if (order.pendingSync) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Saved offline — will sync when online',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(),
              ...order.items.map(
                (line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            Text('${line.quantity} × ${line.name}'),
                      ),
                      Text(_money.format(line.price * line.quantity)),
                    ],
                  ),
                ),
              ),
              const Divider(),
              _row('Subtotal', _money.format(order.subtotal)),
              if (order.discount > 0)
                _row('Discount', '- ${_money.format(order.discount)}'),
              _row('Tax', _money.format(order.taxAmount)),
              const SizedBox(height: 6),
              _row('Total', _money.format(order.total), bold: true),
              const SizedBox(height: 8),
              Text('Paid via ${order.paymentMethod.toUpperCase()}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Thank you — visit again!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
