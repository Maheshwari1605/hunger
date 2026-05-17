import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/cart_sheet.dart';
import 'pos_screen.dart';
import 'menu_screen.dart';
import 'reports_screen.dart';
import 'kitchen_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user!;

    final tabs = <_NavTab>[
      if (user.isAdmin || user.isCashier)
        _NavTab(
          icon: Icons.point_of_sale,
          label: 'POS',
          builder: () => const PosScreen(),
        ),
      if (user.isAdmin)
        _NavTab(
          icon: Icons.restaurant_menu,
          label: 'Menu',
          builder: () => const MenuScreen(),
        ),
      if (user.isAdmin || user.isKitchen)
        _NavTab(
          icon: Icons.soup_kitchen,
          label: 'Kitchen',
          builder: () => const KitchenScreen(),
        ),
      if (user.isAdmin)
        _NavTab(
          icon: Icons.analytics,
          label: 'Reports',
          builder: () => const ReportsScreen(),
        ),
    ];

    final safeIndex = _index.clamp(0, tabs.length - 1);
    final isPosTab = tabs[safeIndex].label == 'POS';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            // Tap the brand logo to open the account menu (logout etc.)
            _BrandMenuButton(user: user),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tabs[safeIndex].label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isPosTab) const _CartActionButton(),
        ],
      ),
      body: tabs[safeIndex].builder(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: tabs
            .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

class _BrandMenuButton extends StatelessWidget {
  final AppUser user;
  const _BrandMenuButton({required this.user});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${user.email} · ${user.role}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 12),
              Text('Logout'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'logout') {
          context.read<AuthService>().logout();
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: BrandLogo(size: 32),
      ),
    );
  }
}

class _CartActionButton extends StatelessWidget {
  const _CartActionButton();

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartService, int>((c) => c.count);
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => CartSheet.show(context),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: Theme.of(context).colorScheme.error,
        textColor: Colors.white,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  _NavTab({required this.icon, required this.label, required this.builder});
}
