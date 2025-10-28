import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/secrets_active_screen.dart';
import 'screens/tambah_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/api_config_screen.dart';
import 'screens/system_resource_screen.dart';
import 'screens/log_screen.dart';
import 'screens/traffic_screen.dart';
import 'screens/ppp_profile_page.dart';
import 'screens/all_users_screen.dart';
import 'screens/export_ppp_screen.dart';
import 'screens/odp_screen.dart';
import 'screens/billing_screen.dart';
import 'services/mikrotik_service.dart';
import 'providers/mikrotik_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

// Reusable widget to eliminate code duplication
class MikrotikScreenWrapper extends StatelessWidget {
  final Widget child;
  
  const MikrotikScreenWrapper({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MikrotikService>(
      future: _initializeMikrotikService(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: Text('No data available'),
            ),
          );
        }
        final service = snapshot.data!;
        return ChangeNotifierProvider(
          create: (_) => MikrotikProvider(service),
          child: child,
        );
      },
    );
  }
}

// Add ThemeProvider
class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
    return MaterialApp(
      title: 'Mikrotik Monitor',
      theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              cardColor: Colors.white,
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.black87),
                bodyMedium: TextStyle(color: Colors.black87),
                titleLarge: TextStyle(color: Colors.black87),
                titleMedium: TextStyle(color: Colors.black87),
                titleSmall: TextStyle(color: Colors.black54),
              ),
              dividerTheme: const DividerThemeData(
                color: Colors.black12,
              ),
              listTileTheme: const ListTileThemeData(
                iconColor: Colors.blue,
                textColor: Colors.black87,
                subtitleTextStyle: TextStyle(color: Colors.black54),
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              cardColor: Color(0xFF1E1E1E),
              scaffoldBackgroundColor: Colors.black,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white),
                titleLarge: TextStyle(color: Colors.white),
                titleMedium: TextStyle(color: Colors.white),
                titleSmall: TextStyle(color: Colors.white70),
              ),
              dividerTheme: const DividerThemeData(
                color: Colors.white12,
              ),
              listTileTheme: const ListTileThemeData(
                iconColor: Colors.blue,
                textColor: Colors.white,
                subtitleTextStyle: TextStyle(color: Colors.white70),
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                contentTextStyle: TextStyle(color: Colors.white),
              ),
              snackBarTheme: const SnackBarThemeData(
                backgroundColor: Colors.blue,
                contentTextStyle: TextStyle(color: Colors.white),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.white70),
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
        useMaterial3: true,
      ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LoginScreen(),
      routes: {
        '/dashboard': (context) => const MikrotikScreenWrapper(
              child: DashboardScreen(),
            ),
        '/secrets-active': (context) => const MikrotikScreenWrapper(
              child: SecretsActiveScreen(),
            ),
        '/tambah': (context) => const MikrotikScreenWrapper(
              child: TambahScreen(),
                  ),
        '/setting': (context) => const SettingScreen(),
        '/api-config': (context) => const ApiConfigScreen(),
        '/system-resource': (context) => const MikrotikScreenWrapper(
              child: SystemResourceScreen(),
            ),
        '/traffic': (context) => const MikrotikScreenWrapper(
              child: TrafficScreen(),
            ),
        '/log': (context) => const MikrotikScreenWrapper(
              child: LogScreen(),
            ),
        '/ppp-profile': (context) => const MikrotikScreenWrapper(
              child: PPPProfilePage(),
            ),
        '/all-users': (context) => const MikrotikScreenWrapper(
              child: AllUsersScreen(),
            ),
        '/export-ppp': (context) => const MikrotikScreenWrapper(
              child: ExportPPPScreen(),
            ),
        '/odp': (context) => const ODPScreen(),
        '/billing': (context) => const BillingScreen(), // Ganti userId sesuai kebutuhan
      },
          );
        },
      ),
    );
  }
}

Future<MikrotikService> _initializeMikrotikService() async {
  final prefs = await SharedPreferences.getInstance();
  final ip = prefs.getString('ip');
  final port = prefs.getString('port');
  final username = prefs.getString('username');
  final password = prefs.getString('password');

  if (ip == null || port == null || username == null || password == null) {
    throw Exception('Missing connection details');
  }

  return MikrotikService(
    ip: ip,
    port: port,
    username: username,
    password: password,
  );
}
