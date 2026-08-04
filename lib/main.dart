import 'package:flutter/material.dart';
import 'services/supabase_config.dart';
import 'services/live_data_service.dart';
import 'services/tenant_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/packages_screen.dart';
import 'screens/pre_alerts_screen.dart';
import 'screens/shipments_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/labels_screen.dart';
import 'screens/manifest_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/branches_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/warehouse_screen.dart';
import 'screens/shipping_partners_screen.dart';
import 'screens/partner_login_screen.dart';
import 'screens/partner_dashboard_screen.dart';
import 'screens/customer_login_screen.dart';
import 'screens/customer_portal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  // Resolve current hostname -> tenant (partner) before rendering UI.
  await TenantService().init();
  runApp(const CourierWarehouseApp());
}

class CourierWarehouseApp extends StatelessWidget {
  const CourierWarehouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Applizone Central Jamaica — Courier Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: TenantService().isAdminHost ? '/' : '/partner-login',
      routes: {
        '/': (context) => const _AppRoot(),
        '/partner-login': (context) => const PartnerLoginScreen(),
        '/partner-home': (context) => const PartnerDashboardScreen(),
        '/customer-login': (context) => const CustomerLoginScreen(),
        '/customer-home': (context) => const CustomerPortalScreen(),
      },
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _loggedIn = false;
  bool _loadingData = false;
  bool _showLogin = false;

  Future<void> _handleLogin() async {
    setState(() => _loadingData = true);
    try {
      await LiveDataService().load();
    } catch (e) {
      // ignore: avoid_print
      print('[LiveDataService] load failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _loggedIn = true;
      _loadingData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_loggedIn) {
      if (!_showLogin) {
        return LandingScreen(onGetStarted: () => setState(() => _showLogin = true));
      }
      return LoginScreen(onLogin: _handleLogin);
    }
    return MainShell(onLogout: () => setState(() => _loggedIn = false));
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainShell({super.key, required this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(), // 0
    PackagesScreen(), // 1
    PreAlertsScreen(), // 2
    ShipmentsScreen(), // 3
    CustomersScreen(), // 4
    InvoicesScreen(), // 5
    PosScreen(), // 6
    LabelsScreen(), // 7
    ManifestScreen(), // 8
    ReportsScreen(), // 9
    StaffScreen(), // 10
    BranchesScreen(), // 11
    SettingsScreen(), // 12
    WarehouseScreen(), // 13
    ShippingPartnersScreen(), // 14
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Toggle navigation menu',
          ),
        ),
        title: Image.network(
          AppTheme.logoUrl,
          height: 32,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'Applizone Central JA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border, width: 1.5),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 20,
                color: AppTheme.textPrimary,
              ),
            ),
            tooltip: 'Sign out',
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      drawer: AppNavDrawer(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) => setState(() => _selectedIndex = index),
      ),
      body: _screens[_selectedIndex],
    );
  }
}
