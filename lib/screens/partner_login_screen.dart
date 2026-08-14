import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/applizone_api.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Standalone login page for third-party shipping partners.
/// Accessible at /partner-login
class PartnerLoginScreen extends StatefulWidget {
  const PartnerLoginScreen({super.key});

  @override
  State<PartnerLoginScreen> createState() => _PartnerLoginScreenState();
}

class _PartnerLoginScreenState extends State<PartnerLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _prefixController = TextEditingController();
  final _domainController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _api = ApplizoneApi();
  final _db = DatabaseService();
  bool _obscure = true;
  bool _loading = false;
  bool _isSignUp = false;
  bool _argsApplied = false;
  String _selectedPlan = 'courier';
  String? _error;
  String? _success;

  static const _plans = [
    (
      'courier',
      'Courier Platform',
      'Manage all your customers and packages in one place',
      [
        'Customer Portal',
        'iOS & Android Apps',
        'Advanced Package Tracking',
        'Backoffice Portal',
        'Pre-Alert System',
        'Invoice Management',
        'Unlimited Staff Users',
        'Multiple Branch Locations',
        'Point of Sale',
        'Label Generation',
        'Manifest Generation',
        'Advanced Reporting',
        'No Setup Fee',
        'Partner Branding',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsApplied) {
      _argsApplied = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args['signup'] == true) _isSignUp = true;
        if (args['plan'] is String) _selectedPlan = args['plan'] as String;
      }
    }
  }

  Future<void> _checkSession() async {
    await _api.init();
    if (_db.isAuthenticated) {
      // Only auto-redirect if this is an approved partner account.
      // An admin/other Supabase session should not skip the partner login.
      try {
        final account = await _db.getPartnerAccount(_db.currentUser!.id);
        if (account != null && account['status'] == 'approved') {
          if (mounted)
            Navigator.of(context).pushReplacementNamed('/partner-home');
          return;
        }
      } catch (_) {}
      // No partner account found (or not approved) — sign out and show login form
      await _db.signOut();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _prefixController.dispose();
    _domainController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _generatePartnerApiKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(24, (_) => rand.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    return 'az_live_$token';
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await _db.signIn(email, pass);
      if (!mounted) return;
      if (response.user != null) {
        final account = await _db.getPartnerAccount(response.user!.id);
        if (account == null) {
          setState(() {
            _loading = false;
            _error = 'No partner account found. Please sign up first.';
          });
          await _db.signOut();
          return;
        }
        if (account['status'] == 'pending') {
          setState(() {
            _loading = false;
            _error =
                'Your account is pending approval. You will be notified once approved.';
          });
          await _db.signOut();
          return;
        }
        if (account['status'] != 'approved') {
          setState(() {
            _loading = false;
            _error = 'Your account is not active. Please contact support.';
          });
          await _db.signOut();
          return;
        }
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).pushReplacementNamed('/partner-home');
      } else {
        setState(() {
          _loading = false;
          _error = 'Login failed. Please check your credentials.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('AuthException: ', '');
      });
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirmPass = _confirmPasswordController.text;
    final companyName = _companyNameController.text.trim();
    final contactName = _contactNameController.text.trim();
    final phone = _phoneController.text.trim();
    final prefix = _prefixController.text.trim().toUpperCase();
    if (companyName.isEmpty ||
        contactName.isEmpty ||
        email.isEmpty ||
        pass.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirmPass) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (prefix.isEmpty || prefix.length < 2 || prefix.length > 5) {
      setState(
        () => _error = 'Tracking prefix must be 2-5 characters (e.g. MYC).',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await _db.signUp(email, pass);
      if (!mounted) return;
      // Supabase returns a mocked user (no identities) instead of an error
      // when the email is already registered, to avoid leaking which
      // emails exist. Catch that here rather than hitting a confusing
      // foreign-key/unique-constraint error from the account RPC.
      if (response.user != null &&
          (response.user!.identities?.isEmpty ?? false)) {
        setState(() {
          _loading = false;
          _error =
              'An account with this email already exists. Please log in instead.';
        });
        return;
      }
      if (response.user != null) {
        final apiKey = _generatePartnerApiKey();
        // create_partner_account also creates the linked shipping_partners
        // row and auto-approves the account server-side.
        final account = await _db.insertPartnerAccount(
          authUserId: response.user!.id,
          companyName: companyName,
          contactName: contactName,
          email: email,
          phone: phone.isNotEmpty ? phone : null,
          trackingPrefix: '$prefix-',
          domain: _domainController.text.trim(),
          plan: _selectedPlan,
        );
        try {
          await _db.regenerateOwnPartnerApiKey(apiKey);
        } catch (_) {}

        String? domainInstructions;
        final domain = _domainController.text.trim();
        if (domain.isNotEmpty && response.session != null) {
          try {
            final result = await _db.provisionPartnerDomain(
              domain: domain,
              partnerAccountId: account['id'] as String,
            );
            domainInstructions = result['instructions'] as String?;
          } catch (e) {
            domainInstructions =
                'We could not register $domain automatically ($e). '
                'You can retry this from Settings in your dashboard.';
          }
        }

        if (!mounted) return;
        if (response.session != null) {
          if (domainInstructions != null) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Almost there — one more step'),
                content: Text(domainInstructions!),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            );
          }
          if (!mounted) return;
          setState(() => _loading = false);
          Navigator.of(context).pushReplacementNamed('/partner-home');
        } else {
          await _db.signOut();
          setState(() {
            _loading = false;
            _isSignUp = false;
            _success =
                'Account created! Check your email to confirm your address, then sign in.';
            _companyNameController.clear();
            _contactNameController.clear();
            _phoneController.clear();
            _prefixController.clear();
            _domainController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
        }
      } else {
        setState(() {
          _loading = false;
          _error = 'Sign-up failed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('AuthException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/one_village_logo.png',
                height: 68,
                errorBuilder: (_, __, ___) => const _AzLogo(),
              ),
              const SizedBox(height: 32),
              Container(
                width: 420,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSignUp ? _buildSignUpForm() : _buildLoginForm(),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final plan = _plans.firstWhere(
                    (p) => p.$1 == _selectedPlan,
                    orElse: () => _plans.first,
                  );
                  return _WhatsIncludedCard(
                    planTitle: plan.$2,
                    planSubtitle: plan.$3,
                    features: plan.$4,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Copyright ${DateTime.now().year} One Village Shipping & Freight LLC. All rights reserved.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Login to Partner Portal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your email below to login to your account',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 28),
        if (_success != null) ...[
          _alert(_success!, AppTheme.success, Icons.check_circle_outline),
          const SizedBox(height: 16),
        ],
        _label('Email'),
        const SizedBox(height: 6),
        _field(
          controller: _emailController,
          hint: 'm@example.com',
          type: TextInputType.emailAddress,
          onSubmit: (_) => _login(),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('Password'),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot your password?',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _pwdField(controller: _passwordController, onSubmit: (_) => _login()),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _alert(_error!, AppTheme.danger, Icons.error_outline),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: _loading ? null : _login,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account? ",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _isSignUp = true;
                _error = null;
                _success = null;
              }),
              child: const Text(
                'Sign up',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/customer-login'),
            icon: const Icon(Icons.person_outline, size: 16),
            label: const Text('Shipping customer? Sign in here'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Courier Account',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Register your shipping company to connect with our warehouse',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 24),
        _label('Company Name *'),
        const SizedBox(height: 6),
        _field(
          controller: _companyNameController,
          hint: 'e.g. Island Express Freight',
        ),
        const SizedBox(height: 16),
        _label('Contact Person *'),
        const SizedBox(height: 6),
        _field(controller: _contactNameController, hint: 'Full name'),
        const SizedBox(height: 16),
        _label('Email *'),
        const SizedBox(height: 6),
        _field(
          controller: _emailController,
          hint: 'm@example.com',
          type: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _label('Phone'),
        const SizedBox(height: 6),
        _field(
          controller: _phoneController,
          hint: '+1 (876) 555-0100',
          type: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _label('Tracking Prefix * (2-5 chars)'),
        const SizedBox(height: 6),
        _field(controller: _prefixController, hint: 'e.g. MYC'),
        const SizedBox(height: 4),
        const Text(
          'Packages with this prefix will be auto-linked to your company.',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 16),
        _label('Website / Portal Domain'),
        const SizedBox(height: 6),
        _field(
          controller: _domainController,
          hint: 'e.g. track.yourcompany.com',
        ),
        const SizedBox(height: 4),
        const Text(
          'The domain your customers will visit. We\'ll register it automatically — '
          'point it to us via CNAME to finish setup.',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 16),
        _label('Password *'),
        const SizedBox(height: 6),
        _pwdField(controller: _passwordController),
        const SizedBox(height: 16),
        _label('Confirm Password *'),
        const SizedBox(height: 6),
        _field(
          controller: _confirmPasswordController,
          hint: 'Re-enter password',
          obscure: true,
          onSubmit: (_) => _signUp(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _alert(_error!, AppTheme.danger, Icons.error_outline),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: _loading ? null : _signUp,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _isSignUp = false;
                _error = null;
              }),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF374151),
    ),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    ValueChanged<String>? onSubmit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      onSubmitted: onSubmit,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: _dec(hint),
    );
  }

  Widget _pwdField({
    required TextEditingController controller,
    ValueChanged<String>? onSubmit,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      onSubmitted: onSubmit,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: _dec('Password').copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: const Color(0xFF9CA3AF),
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  Widget _alert(String msg, Color color, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg, style: TextStyle(fontSize: 13, color: color)),
        ),
      ],
    ),
  );
}

class _AzLogo extends StatelessWidget {
  const _AzLogo();
  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Center(
      child: Text(
        'OV',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    ),
  );
}

class _WhatsIncludedCard extends StatelessWidget {
  final String planTitle;
  final String planSubtitle;
  final List<String> features;
  const _WhatsIncludedCard({
    required this.planTitle,
    required this.planSubtitle,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's included — $planTitle",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            planSubtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
