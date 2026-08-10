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
      title: 'One Village Shipping & Freight — Courier Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: TenantService().isAdminHost ? '/' : '/partner-login',
      routes: {
        '/': (context) => const LandingScreen(),
        '/team': (context) => const _TeamPortalRoot(),
        '/partner-login': (context) => const PartnerLoginScreen(),
        '/partner-home': (context) => const PartnerDashboardScreen(),
        '/customer-login': (context) => const CustomerLoginScreen(),
        '/customer-home': (context) => const CustomerPortalScreen(),
      },
    );
  }
}

/// Internal entry point for One Village staff and warehouse operations.
/// Deliberately not linked from the public landing page — reach it directly
/// via /#/team.
class _TeamPortalRoot extends StatefulWidget {
  const _TeamPortalRoot();

  @override
  State<_TeamPortalRoot> createState() => _TeamPortalRootState();
}

class _TeamPortalRootState extends State<_TeamPortalRoot> {
  bool _loggedIn = false;
  bool _loadingData = false;

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

  List<Widget> get _screens => [
    DashboardScreen(onViewShipments: () => setState(() => _selectedIndex = 3)), // 0
    const PackagesScreen(), // 1
    const PreAlertsScreen(), // 2
    const ShipmentsScreen(), // 3
    const CustomersScreen(), // 4
    const InvoicesScreen(), // 5
    const PosScreen(), // 6
    const LabelsScreen(), // 7
    const ManifestScreen(), // 8
    const ReportsScreen(), // 9
    const StaffScreen(), // 10
    const BranchesScreen(), // 11
    const SettingsScreen(), // 12
    const WarehouseScreen(), // 13
    const ShippingPartnersScreen(), // 14
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
        title: Image.asset(
          'assets/images/one_village_logo.png',
          height: 40,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'One Village Shipping & Freight',
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
          preferredSize: Size.fromHeight(30),
          child: _DashboardKindBanner(
            label: 'ADMIN / WAREHOUSE DASHBOARD',
            icon: Icons.admin_panel_settings,
            background: AppTheme.primary,
            foreground: Colors.white,
          ),
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

/// Bold, always-visible strip identifying which portal is currently on
/// screen — admin/warehouse staff and couriers both sometimes have more
/// than one of this app's dashboards open, and the two look similar
/// enough at a glance to mix up.
class _DashboardKindBanner extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  const _DashboardKindBanner({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 30,
      color: background,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
