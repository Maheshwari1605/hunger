import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/customer_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _q = '';
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<CustomerService>().list(q: _q);
    });
  }

  Future<void> _addOrEdit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['name'] ?? '');
    final phone = TextEditingController(text: existing?['phone'] ?? '');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'New customer' : 'Edit customer'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'name': name.text.trim(),
              'phone': phone.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result['name']!.isEmpty || result['phone']!.isEmpty) {
      return;
    }
    try {
      final svc = context.read<CustomerService>();
      if (existing == null) {
        await svc.create(result);
      } else {
        await svc.update(existing['_id'], result);
      }
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                _q = v;
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('No customers yet.'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    return ListTile(
                      title: Text(c['name'] ?? '—'),
                      subtitle: Text(
                        '${c['phone'] ?? ''} · ${c['totalOrders'] ?? 0} orders · ${_money.format((c['totalSpent'] as num?)?.toDouble() ?? 0)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _addOrEdit(c),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
