import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/table_service.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<TableService>().list();
    });
  }

  Future<void> _addTable() async {
    final label = TextEditingController();
    final capacity = TextEditingController(text: '4');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New table'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                decoration:
                    const InputDecoration(labelText: 'Label (e.g. T1)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: capacity,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
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
              'label': label.text.trim(),
              'capacity': int.tryParse(capacity.text) ?? 4,
            }),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == null || (result['label'] as String).isEmpty) return;
    try {
      await context
          .read<TableService>()
          .create(result['label'], capacity: result['capacity']);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _selectTable(Map<String, dynamic> table) {
    context.read<CartService>().setTable(
          id: table['_id'] as String,
          label: table['label'] as String,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected table ${table['label']} for next order')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTable,
        icon: const Icon(Icons.add),
        label: const Text('Table'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
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
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No tables yet. Tap + to add one.')),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final t = rows[i];
                final occupied = t['occupied'] == true;
                return InkWell(
                  onTap: occupied ? null : () => _selectTable(t),
                  child: Card(
                    color: occupied
                        ? Colors.red.shade50
                        : Theme.of(context).colorScheme.surface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            occupied ? Icons.no_meals : Icons.table_restaurant,
                            size: 36,
                            color: occupied ? Colors.red : null,
                          ),
                          const SizedBox(height: 6),
                          Text(t['label'] ?? '?',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          Text('cap ${t['capacity'] ?? 4}',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (occupied)
                            const Text('Occupied',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                )),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
