import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/menu_service.dart';
import 'services/order_service.dart';
import 'services/report_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const HungerApp());
}

class HungerApp extends StatelessWidget {
  const HungerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => AuthService(apiClient)),
        ChangeNotifierProvider(create: (_) => CartService()),
        Provider(create: (_) => MenuService(apiClient)),
        Provider(create: (_) => OrderService(apiClient)),
        Provider(create: (_) => ReportService(apiClient)),
      ],
      child: MaterialApp(
        title: 'Hunger Cafe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5C3A1E), // Hunger brown
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
    _restore = context.read<AuthService>().restore();
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
