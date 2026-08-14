import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'services/font_scale_controller.dart';
import 'services/supabase_config.dart';
import 'services/live_data_service.dart';
import 'services/tenant_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'widgets/video_backdrop.dart';
import 'screens/landing_screen.dart';
import 'screens/about_page.dart';
import 'screens/services_page.dart';
import 'screens/rates_page.dart';
import 'screens/contact_page.dart';
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
import 'screens/site_content_screen.dart';
import 'screens/accounting_screen.dart';
import 'screens/payroll_screen.dart';
import 'screens/warehouse_scanner_screen.dart';
import 'screens/unknown_packages_screen.dart';
import 'screens/partner_login_screen.dart';
import 'screens/partner_dashboard_screen.dart';
import 'screens/customer_login_screen.dart';
import 'screens/customer_portal_screen.dart';
import 'screens/reset_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read *before* SupabaseConfig.init() — on success it consumes and
  // cleans up a recovery/confirmation token from the fragment as a side
  // effect of detecting it. Confirmed live, twice: a top-level `final`
  // holding this same expression looked like it should run "at startup"
  // but Dart only initializes top-level fields lazily, on first read —
  // which in the original version was from build(), well after that
  // cleanup had already run, i.e. no earlier than doing it inline here
  // would have been. An explicit local read, before the await that
  // triggers the cleanup, is the only thing that's actually early enough.
  final rawInitialFragment = Uri.base.fragment;
  await SupabaseConfig.init();
  // Resolve current hostname -> tenant (partner) before rendering UI.
  await TenantService().init();
  await FontScaleController().load();
  runApp(CourierWarehouseApp(rawInitialFragment: rawInitialFragment));
}

/// Reachable from anywhere (see CourierWarehouseApp's auth listener)
/// without needing a BuildContext of its own.
final navigatorKey = GlobalKey<NavigatorState>();

class CourierWarehouseApp extends StatefulWidget {
  final String rawInitialFragment;
  const CourierWarehouseApp({super.key, required this.rawInitialFragment});

  @override
  State<CourierWarehouseApp> createState() => _CourierWarehouseAppState();
}

class _CourierWarehouseAppState extends State<CourierWarehouseApp> {
  StreamSubscription<AuthState>? _authSub;

  /// MaterialApp.initialRoute is used verbatim on first load *instead
  /// of* whatever's actually in the URL bar — confirmed live, the hard
  /// way: a password-recovery email link landing with #access_token=...
  /// in the fragment was silently ignored and the app opened on '/'
  /// regardless, because initialRoute said to unconditionally. Used as
  /// a first attempt (still worth keeping — it's an honest reflection
  /// of the URL Flutter is about to discard) but not relied on alone:
  /// the auth listener below is the mechanism actually confirmed live
  /// to work, reacting to Supabase successfully establishing the
  /// recovery session rather than trying to out-guess exactly when
  /// Flutter's router vs. Supabase's own URL cleanup runs first.
  String get _initialRoute {
    if (widget.rawInitialFragment.contains('type=recovery')) {
      return '/reset-password';
    }
    return TenantService().isAdminHost ? '/' : '/partner-login';
  }

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushNamed('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app (cheap — just a text-scale multiplier, not
    // reloading any data) whenever the admin changes the font-size
    // control, so every screen picks up the new scale immediately.
    return ListenableBuilder(
      listenable: FontScaleController(),
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'One Village Shipping & Freight — Courier Portal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // MediaQuery's textScaler applies to every widget in the tree
        // below it — this is the one place a single setting reaches the
        // "entire website" rather than needing to be wired into each
        // screen individually.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(FontScaleController().scale)),
          child: child!,
        ),
        initialRoute: _initialRoute,
        routes: {
          '/': (context) => const LandingScreen(),
          '/about': (context) => const AboutPage(),
          '/services': (context) => const ServicesPage(),
          '/rates': (context) => const RatesPage(),
          '/contact': (context) => const ContactPage(),
          '/team': (context) => const _TeamPortalRoot(),
          '/partner-login': (context) => const PartnerLoginScreen(),
          '/partner-home': (context) => const PartnerDashboardScreen(),
          '/customer-login': (context) => const CustomerLoginScreen(),
          '/customer-home': (context) => const CustomerPortalScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
        },
      ),
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
  final _db = DatabaseService();
  bool _loggedIn = false;
  // Starts true: a page refresh reruns main() and rebuilds this widget
  // from scratch, but Supabase's own auth session persists in the
  // browser regardless — without checking for it first, we'd flash (or
  // outright show) the login screen for an admin who is still validly
  // signed in. Stays true until _restoreSession decides one way or the
  // other, so nothing is shown until that's settled.
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      if (_db.isAuthenticated) {
        final admin = await _db.getAdminUser(_db.currentUser!.id);
        if (admin != null && admin['is_active'] != false) {
          await LiveDataService().load();
          if (!mounted) return;
          setState(() {
            _loggedIn = true;
            _loadingData = false;
          });
          return;
        }
        // A session exists but isn't a valid, active admin — e.g. a
        // partner/customer session from the same browser, or a
        // deactivated admin account. Don't trust it here; make sure it's
        // actually cleared rather than leaving a half-authenticated state.
        await _db.signOut();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[TeamPortal] session restore failed: $e');
    }
    if (!mounted) return;
    setState(() => _loadingData = false);
  }

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

  Future<void> _handleLogout() async {
    await _db.signOut();
    if (!mounted) return;
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_loggedIn) {
      return LoginScreen(onLogin: _handleLogin);
    }
    return MainShell(onLogout: _handleLogout);
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
    const SiteContentScreen(), // 15
    const AccountingScreen(), // 16
    const PayrollScreen(), // 17
    const WarehouseScannerScreen(), // 18
    const UnknownPackagesScreen(), // 19
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
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
          const _FontSizeControl(),
          const SizedBox(width: 4),
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
      // Same clip/ship footage as the public site's hero, but heavily
      // tinted toward the ordinary page background — this is a working
      // tool staff use all day, not a marketing page, so the video only
      // shows as a faint moving texture in the page margins around each
      // screen's own cards/tables. Nothing about any individual screen's
      // content changes: they already render on transparent backgrounds
      // over the Scaffold, so this is a drop-in backdrop swap, not a
      // per-screen edit.
      body: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: VideoBackdrop(
                enabled: wide,
                assetPath: 'assets/videos/hero_background.mp4',
                fallback: const ColoredBox(color: AppTheme.surface),
              ),
            ),
          ),
          const Positioned.fill(
            child: ColoredBox(color: Color(0xE6FFF9FA)), // AppTheme.surface @ ~90% alpha
          ),
          _screens[_selectedIndex],
        ],
      ),
    );
  }
}

/// A- / A+ in the admin app bar — always visible, one tap, no digging
/// through Settings to find it. Reads the current step from
/// FontScaleController so the button greys out at the top/bottom of the
/// range instead of doing nothing silently.
class _FontSizeControl extends StatelessWidget {
  const _FontSizeControl();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FontScaleController(),
      builder: (context, _) {
        final controller = FontScaleController();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: controller.canDecrease ? controller.decrease : null,
              icon: const Icon(Icons.text_decrease, size: 20),
              tooltip: 'Decrease text size',
            ),
            Text(
              controller.label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              onPressed: controller.canIncrease ? controller.increase : null,
              icon: const Icon(Icons.text_increase, size: 20),
              tooltip: 'Increase text size',
            ),
          ],
        );
      },
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
