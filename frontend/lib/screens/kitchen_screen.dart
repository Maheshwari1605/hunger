import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../services/order_service.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  Future<List<OrderSummary>>? _future;
  Timer? _refreshTimer;
  static final _ts = DateFormat('HH:mm');

  static const _statusOrder = ['queued', 'preparing', 'ready', 'served'];

  @override
  void initState() {
    super.initState();
    _reload();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _reload());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = context.read<OrderService>().list(limit: 100);
    });
  }

  Future<void> _advance(OrderSummary o) async {
    final idx = _statusOrder.indexOf(o.kitchenStatus);
    if (idx < 0 || idx >= _statusOrder.length - 1) return;
    final next = _statusOrder[idx + 1];
    try {
      await context.read<OrderService>().updateKitchenStatus(o.id, next);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrderSummary>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final orders = (snap.data ?? [])
            .where((o) => o.kitchenStatus != 'served')
            .toList();
        if (orders.isEmpty) {
          return const Center(child: Text('No active orders.'));
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('#${o.orderNumber}',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Chip(
                            label: Text(o.kitchenStatus.toUpperCase()),
                            backgroundColor: _statusColor(o.kitchenStatus),
                          ),
                        ],
                      ),
                      Text(_ts.format(o.createdAt),
                          style: Theme.of(context).textTheme.bodySmall),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          children: o.items
                              .map((line) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                        '${line.quantity} × ${line.name}'
                                        '${line.notes.isNotEmpty ? "\n   ↳ ${line.notes}" : ""}'),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => _advance(o),
                        child: Text('Mark ${_nextLabel(o.kitchenStatus)}'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _nextLabel(String current) {
    final i = _statusOrder.indexOf(current);
    if (i < 0 || i >= _statusOrder.length - 1) return 'done';
    return _statusOrder[i + 1];
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'queued':
        return Colors.orange.shade100;
      case 'preparing':
        return Colors.blue.shade100;
      case 'ready':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}
