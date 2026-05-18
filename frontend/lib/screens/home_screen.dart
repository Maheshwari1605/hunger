import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/cart_sheet.dart';
import 'pos_screen.dart' show PosScreen, kWideLayoutBreakpoint;
import 'menu_screen.dart';
import 'reports_screen.dart';
import 'kitchen_screen.dart';
import 'held_orders_screen.dart';
import 'customers_screen.dart';
import 'tables_screen.dart';
import 'cash_session_screen.dart';
import 'settings_screen.dart';

class _NavTab {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  _NavTab({required this.icon, required this.label, required this.builder});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  List<_NavTab> _tabsForUser(AppUser user) {
    return <_NavTab>[
      if (user.isAdmin || user.isCashier)
        _NavTab(icon: Icons.point_of_sale, label: 'POS', builder: () => const PosScreen()),
      if (user.isAdmin || user.isCashier)
        _NavTab(icon: Icons.pause_circle_outline, label: 'Held', builder: () => const HeldOrdersScreen()),
      if (user.isAdmin || user.isCashier)
        _NavTab(icon: Icons.table_restaurant, label: 'Tables', builder: () => const TablesScreen()),
      if (user.isAdmin || user.isKitchen)
        _NavTab(icon: Icons.soup_kitchen, label: 'Kitchen', builder: () => const KitchenScreen()),
      if (user.isAdmin)
        _NavTab(icon: Icons.restaurant_menu, label: 'Menu', builder: () => const MenuScreen()),
      if (user.isAdmin || user.isCashier)
        _NavTab(icon: Icons.savings_outlined, label: 'Cash', builder: () => const CashSessionScreen()),
      if (user.isAdmin)
        _NavTab(icon: Icons.people_outline, label: 'Customers', builder: () => const CustomersScreen()),
      if (user.isAdmin)
        _NavTab(icon: Icons.analytics, label: 'Reports', builder: () => const ReportsScreen()),
      if (user.isAdmin)
        _NavTab(icon: Icons.settings, label: 'Settings', builder: () => const SettingsScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user!;
    final tabs = _tabsForUser(user);
    final safeIndex = _index.clamp(0, tabs.length - 1);
    final current = tabs[safeIndex];
    final isPosTab = current.label == 'POS';
    final isWide = MediaQuery.of(context).size.width >= kWideLayoutBreakpoint;
    final showHeaderCart = isPosTab && !isWide;
    final useDrawer = tabs.length > 4 || isWide;

    return Scaffold(
      drawer: useDrawer
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    DrawerHeader(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandLogo(size: 60),
                          const SizedBox(height: 8),
                          Text(user.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('${user.email} · ${user.role}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            ListTile(
                              leading: Icon(tabs[i].icon),
                              title: Text(tabs[i].label),
                              selected: i == safeIndex,
                              onTap: () {
                                setState(() => _index = i);
                                Navigator.of(context).pop();
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: () => context.read<AuthService>().logout(),
                    ),
                  ],
                ),
              ),
            )
          : null,
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            _BrandMenuButton(user: user),
            const SizedBox(width: 10),
            Expanded(
              child: Text(current.label, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          const _NetworkStatusButton(),
          if (showHeaderCart) const _CartActionButton(),
        ],
      ),
      body: current.builder(),
      bottomNavigationBar: useDrawer
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: tabs
                  .map((t) =>
                      NavigationDestination(icon: Icon(t.icon), label: t.label))
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

class _NetworkStatusButton extends StatelessWidget {
  const _NetworkStatusButton();

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().online;
    final sync = context.watch<SyncService>();
    final pending = sync.pendingCount;

    final icon = online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;
    final color = online
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return IconButton(
      tooltip: online
          ? (pending == 0
              ? 'Online'
              : '$pending order${pending == 1 ? '' : 's'} pending sync')
          : 'Offline — orders will queue',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => _NetworkInfoSheet(),
        );
      },
      icon: Badge(
        isLabelVisible: pending > 0,
        label: Text('$pending'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _NetworkInfoSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().online;
    final sync = context.watch<SyncService>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    color: online
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error),
                const SizedBox(width: 10),
                Text(online ? 'Online' : 'Offline',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(online
                ? 'The app is connected to the server.'
                : 'No network detected. New orders are queued locally and will sync automatically.'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.sync),
                const SizedBox(width: 10),
                Text('${sync.pendingCount} order(s) pending sync'),
                const Spacer(),
                if (online && sync.pendingCount > 0)
                  FilledButton.tonal(
                    onPressed: sync.isRunning ? null : sync.flush,
                    child: Text(sync.isRunning ? 'Syncing…' : 'Sync now'),
                  ),
              ],
            ),
            if (sync.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last sync error: ${sync.lastError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
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
