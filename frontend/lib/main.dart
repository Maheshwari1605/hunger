import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/cash_service.dart';
import 'services/connectivity_service.dart';
import 'services/customer_service.dart';
import 'services/local_store.dart';
import 'services/menu_service.dart';
import 'services/order_service.dart';
import 'services/report_service.dart';
import 'services/settings_service.dart';
import 'services/sync_service.dart';
import 'services/table_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.create();
  runApp(HungerApp(store: store));
}

class HungerApp extends StatelessWidget {
  final LocalStore store;
  const HungerApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<LocalStore>.value(value: store),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => AuthService(apiClient)),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => SettingsService(apiClient)),
        ChangeNotifierProvider(create: (_) => CashService(apiClient)),
        Provider(create: (_) => MenuService(apiClient, store)),
        Provider(create: (_) => CustomerService(apiClient)),
        Provider(create: (_) => TableService(apiClient)),
        ChangeNotifierProvider(create: (_) => OrderService(apiClient, store)),
        Provider(create: (_) => ReportService(apiClient)),
        ChangeNotifierProxyProvider<ConnectivityService, SyncService>(
          create: (ctx) => SyncService(
            apiClient,
            store,
            ctx.read<ConnectivityService>(),
          ),
          update: (_, __, prev) => prev!,
        ),
      ],
      child: MaterialApp(
        title: 'Hunger Cafe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5C3A1E),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFFAF3E5),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late Future<void> _restore;

  @override
  void initState() {
    super.initState();
    _restore = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await context.read<AuthService>().restore();
    if (!mounted) return;
    if (context.read<AuthService>().isAuthenticated) {
      final settings = context.read<SettingsService>();
      await settings.load();
      if (!mounted) return;
      context.read<CartService>().setTaxRate(settings.taxRate);
      await context.read<CashService>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _restore,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final auth = context.watch<AuthService>();
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
