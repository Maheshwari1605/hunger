import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../services/table_service.dart';
import '../widgets/cart_body.dart';
import '../widgets/cart_sheet.dart';

const double kWideLayoutBreakpoint = 900;

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  // null = tables grid, non-null = working on that table's order.
  Map<String, dynamic>? _activeTable;
  Future<List<Map<String, dynamic>>>? _tablesFuture;
  bool _loadingTable = false;

  @override
  void initState() {
    super.initState();
    _reloadTables();
  }

  void _reloadTables() {
    setState(() {
      _tablesFuture = context.read<TableService>().list();
    });
  }

  Future<void> _selectTable(Map<String, dynamic> table) async {
    if (_loadingTable) return;
    setState(() => _loadingTable = true);
    final cart = context.read<CartService>();
    try {
      if (table['occupied'] == true && table['openOrderId'] != null) {
        // Resume the held order for this table.
        final order =
            await context.read<OrderService>().get(table['openOrderId'] as String);
        final menu = await context.read<MenuService>().list();
        final byName = {for (final m in menu) m.name: m};
        final lines = <CartLine>[];
        for (final line in order.items) {
          final m = byName[line.name] ??
              MenuItem(
                id: order.id,
                name: line.name,
                description: '',
                price: line.price,
                category: 'Misc',
                sku: '',
                available: true,
                tags: const [],
                stock: null,
              );
          lines.add(CartLine(
              item: m, quantity: line.quantity, notes: line.notes));
        }
        if (!mounted) return;
        cart.loadFromOrder(order, lines);
      } else {
        // Fresh order for this table.
        cart.clear();
        cart.setTable(id: table['_id'] as String, label: table['label'] as String);
      }
      if (!mounted) return;
      setState(() => _activeTable = table);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open table: $e')));
    } finally {
      if (mounted) setState(() => _loadingTable = false);
    }
  }

  Future<bool> _confirmExitIfDirty() async {
    final cart = context.read<CartService>();
    if (cart.isEmpty) return true;
    if (cart.heldOrderId != null) {
      // Order is already in DB; cashier just navigated away — silently allow,
      // they can come back and edits aren't lost (we re-fetch on next select).
      return true;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save this order?'),
        content: Text(
            'You have ${cart.count} item(s) in the cart for ${_activeTable?["label"] ?? "this table"}. Hold the order to save it, or discard to clear.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'hold'),
            child: const Text('Hold'),
          ),
        ],
      ),
    );
    if (action == 'cancel' || action == null) return false;
    if (action == 'discard') {
      cart.clear();
      return true;
    }
    // hold path
    try {
      await context.read<OrderService>().create(
            cart: cart.items,
            paymentMethod: cart.paymentMethod,
            orderType: cart.orderType,
            discountType: cart.discountType,
            discountValue: cart.discountValue,
            tableId: cart.tableId,
            tableLabel: cart.tableLabel,
            hold: true,
          );
      cart.clear();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hold failed: $e')));
      return false;
    }
  }

  Future<void> _backToTables() async {
    final ok = await _confirmExitIfDirty();
    if (!ok) return;
    if (!mounted) return;
    setState(() => _activeTable = null);
    _reloadTables();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTable == null) {
      return _TablesGridView(
        future: _tablesFuture!,
        onTap: _selectTable,
        loading: _loadingTable,
        onRefresh: _reloadTables,
      );
    }
    return _TableOrderView(
      table: _activeTable!,
      onBack: _backToTables,
    );
  }
}

// ---------------- Tables grid ----------------

class _TablesGridView extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final void Function(Map<String, dynamic>) onTap;
  final VoidCallback onRefresh;
  final bool loading;

  const _TablesGridView({
    required this.future,
    required this.onTap,
    required this.onRefresh,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final tables = snap.data ?? const [];
              if (tables.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    Center(child: Text('No tables. Pull to refresh.')),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Select a table to start or resume an order',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: tables.length,
                        itemBuilder: (context, i) {
                          final t = tables[i];
                          final occupied = t['occupied'] == true;
                          return InkWell(
                            onTap: () => onTap(t),
                            borderRadius: BorderRadius.circular(14),
                            child: Card(
                              color: occupied
                                  ? Colors.orange.shade50
                                  : Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: occupied
                                      ? Colors.orange
                                      : Colors.black12,
                                  width: occupied ? 1.5 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      occupied
                                          ? Icons.restaurant
                                          : Icons.table_restaurant,
                                      size: 38,
                                      color: occupied
                                          ? Colors.orange.shade800
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t['label'] ?? '?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Text(
                                      occupied ? 'In progress' : 'Free',
                                      style: TextStyle(
                                        color: occupied
                                            ? Colors.orange.shade800
                                            : Colors.green.shade800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ---------------- Table order view ----------------

class _TableOrderView extends StatefulWidget {
  final Map<String, dynamic> table;
  final VoidCallback onBack;
  const _TableOrderView({required this.table, required this.onBack});

  @override
  State<_TableOrderView> createState() => _TableOrderViewState();
}

class _TableOrderViewState extends State<_TableOrderView> {
  late Future<List<MenuItem>> _itemsFuture;
  String _search = '';
  String _category = 'All';

  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _itemsFuture = context.read<MenuService>().list();
  }

  void _addToCart(MenuItem item) {
    final cart = context.read<CartService>();
    cart.add(item);
    final isWide = MediaQuery.of(context).size.width >= kWideLayoutBreakpoint;
    if (isWide) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Added ${item.name}'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () => CartSheet.show(context),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
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

        final width = MediaQuery.of(context).size.width;
        final isWide = width >= kWideLayoutBreakpoint;

        final menuPane = Column(
          children: [
            // Table header — back button + label + cart count chip
            Material(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to tables',
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.table_restaurant,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Table ${widget.table["label"]}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 12),
                    if (cart.heldOrderId != null)
                      Chip(
                        avatar: const Icon(Icons.pause_circle, size: 16),
                        label: const Text('Resumed'),
                        visualDensity: VisualDensity.compact,
                      ),
                    const Spacer(),
                    Chip(
                      avatar: const Icon(Icons.shopping_cart, size: 16),
                      label: Text('${cart.count} · ${_money.format(cart.total)}'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search menu',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = categories[i];
                  return ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No items match.'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 1.05,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        return InkWell(
                          onTap: item.available ? () => _addToCart(item) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            elevation: 0.5,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const Spacer(),
                                  Text(item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 4),
                                  Text(_money.format(item.price),
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.bold)),
                                  if (!item.available)
                                    const Text('Unavailable',
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 11)),
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

        if (!isWide) return menuPane;

        return Row(
          children: [
            Expanded(child: menuPane),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 380,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: const CartBody(),
              ),
            ),
          ],
        );
      },
    );
  }
}
