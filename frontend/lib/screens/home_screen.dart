import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/brand_logo.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandLogo(size: 28),
            const SizedBox(width: 10),
            Text('Hunger · ${tabs[safeIndex].label}'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '${user.name} (${user.role})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().logout(),
          ),
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

class _NavTab {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  _NavTab({required this.icon, required this.label, required this.builder});
}
