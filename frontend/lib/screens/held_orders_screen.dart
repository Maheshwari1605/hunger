import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';

class HeldOrdersScreen extends StatefulWidget {
  const HeldOrdersScreen({super.key});

  @override
  State<HeldOrdersScreen> createState() => _HeldOrdersScreenState();
}

class _HeldOrdersScreenState extends State<HeldOrdersScreen> {
  late Future<List<OrderSummary>> _future;
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  static final _ts = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context
          .read<OrderService>()
          .list(limit: 100)
          .then((orders) =>
              orders.where((o) => o.paymentStatus == 'open').toList());
    });
  }

  Future<void> _resume(OrderSummary o) async {
    final menu = await context.read<MenuService>().list();
    final byId = {for (final m in menu) m.id: m};
    final lines = <CartLine>[];
    for (final line in o.items) {
      // Re-find by name as a fallback if menuItemId isn't surfaced.
      final found = byId.values.firstWhere(
        (m) => m.name == line.name,
        orElse: () => MenuItem(
          id: o.id,
          name: line.name,
          description: '',
          price: line.price,
          category: 'Misc',
          sku: '',
          available: true,
          tags: const [],
          stock: null,
        ),
      );
      lines.add(CartLine(
        item: found,
        quantity: line.quantity,
        notes: line.notes,
      ));
    }
    if (!mounted) return;
    context.read<CartService>().loadFromOrder(o, lines);
    Navigator.of(context).pop(); // back to POS
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<OrderSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final orders = snap.data ?? const [];
          if (orders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No held orders.')),
              ],
            );
          }
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final o = orders[i];
              return ListTile(
                title: Text('Bill ${o.billNumber ?? o.orderNumber} · ${o.orderType}'),
                subtitle: Text(
                    '${_ts.format(o.createdAt)} · ${o.items.length} items · ${o.customerName?.isNotEmpty == true ? o.customerName : "-"}'),
                trailing: Text(_money.format(o.total),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _resume(o),
              );
            },
          );
        },
      ),
    );
  }
}
