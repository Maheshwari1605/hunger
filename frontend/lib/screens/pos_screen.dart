import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../services/cart_service.dart';
import '../services/menu_service.dart';
import '../widgets/cart_body.dart';
import '../widgets/cart_sheet.dart';

/// Screen-width threshold above which we show a permanent side-cart panel.
const double kWideLayoutBreakpoint = 900;

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
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
    // No need for a "view cart" snackbar on wide layouts — the cart is already visible.
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

        final menuPane = _MenuPane(
          filtered: filtered,
          categories: categories,
          selectedCategory: _category,
          search: _search,
          money: _money,
          onSearchChanged: (v) => setState(() => _search = v),
          onCategoryChanged: (c) => setState(() => _category = c),
          onTapItem: _addToCart,
        );

        if (!isWide) return menuPane;

        // Wide layout: menu on the left, cart panel on the right.
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

class _MenuPane extends StatelessWidget {
  final List<MenuItem> filtered;
  final List<String> categories;
  final String selectedCategory;
  final String search;
  final NumberFormat money;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<MenuItem> onTapItem;

  const _MenuPane({
    required this.filtered,
    required this.categories,
    required this.selectedCategory,
    required this.search,
    required this.money,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search menu',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onSearchChanged,
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
                selected: selectedCategory == c,
                onSelected: (_) => onCategoryChanged(c),
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
                      onTap: item.available ? () => onTapItem(item) : null,
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
                              Text(money.format(item.price),
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
  }
}
