import 'package:flutter/material.dart';
import '../models/partner_branding.dart';
import '../services/database_service.dart';
import '../services/tenant_service.dart';
import '../widgets/adaptive_image.dart';
import 'landing_screen.dart' show LandingScreen;

const _defaultFeatures = [
  'Real-time tracking on every package',
  'View and pay invoices online',
  'Instant delivery status alerts',
  'Manage multiple shipping addresses',
];

/// bg.computeLuminance() > 0.5 reads as a "light" color needing dark text
/// on top for contrast; otherwise white text. Used for the sign-in button,
/// which sits on a white background and takes on a courier's own brand
/// color — unlike the rest of this page's fixed navy/yellow palette, this
/// one has to stay legible against whatever color a courier picks.
Color _contrastColor(Color bg) =>
    bg.computeLuminance() > 0.5 ? const Color(0xFF111827) : Colors.white;

/// Customer Portal login/sign-up, mirroring applizonecentralja.com/auth/customer/login.
/// Sign-up is only offered when the app has resolved a partner tenant from
/// the current hostname — a customer must register under a specific
/// shipping partner, never on the generic/admin host.
class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _db = DatabaseService();
  final _emailCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _confirmPwCtl = TextEditingController();
  bool _loading = false;
  bool _showPw = false;
  bool _isSignUp = false;
  bool _argsApplied = false;
  String? _error;
  String? _success;
  Color? _brandColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsApplied) {
      _argsApplied = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['signup'] == true) {
        _isSignUp = true;
      }
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _pwCtl.dispose();
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _confirmPwCtl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailCtl.text.trim();
      final pw = _pwCtl.text;
      if (email.isEmpty || pw.isEmpty) {
        throw 'Email and password are required.';
      }
      final res = await _db.signIn(email, pw);
      if (res.user == null) throw 'Invalid credentials.';
      // A successful Supabase Auth sign-in only proves this is *some*
      // valid account — it says nothing about which portal it belongs
      // to. Without this check, an admin or courier's own real
      // credentials would sign in here too and land on a fabricated
      // empty customer view (see the matching fix in
      // customer_portal_screen.dart's _load). Verify a customers row
      // actually exists before treating this as a customer session.
      final partnerId = TenantService().partnerId;
      final cust = await _db.getCustomerByEmail(email, partnerId: partnerId);
      if (cust == null) {
        await _db.signOut();
        throw 'This account is not registered as a customer. '
            'Couriers and staff should use their own sign-in page.';
      }
      // A row existing only proves this really is a customer — it says
      // nothing about whether staff deactivated them since (see
      // approveCustomerDeletion in database_service.dart). Matches
      // Customer.isActive's own "anything but literally 'inactive'
      // counts as active" rule so this can never disagree with what
      // the admin Customers screen itself shows for the same account.
      if ((cust['status']?.toString() ?? 'active') == 'inactive') {
        await _db.signOut();
        throw 'This account has been deactivated. Contact support if you '
            'believe this is a mistake.';
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/customer-home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    final partnerId = TenantService().partnerId;
    if (partnerId == null) {
      setState(
        () => _error = 'Sign-up is only available on your shipping partner\'s portal.',
      );
      return;
    }
    final name = _nameCtl.text.trim();
    final email = _emailCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final pw = _pwCtl.text;
    final confirmPw = _confirmPwCtl.text;
    if (name.isEmpty || email.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pw != confirmPw) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await _db.signUp(email, pw);
      if (!mounted) return;
      if (response.user == null) {
        setState(() {
          _loading = false;
          _error = 'Sign-up failed. Please try again.';
        });
        return;
      }
      // Supabase returns a mocked user (no identities) instead of an error
      // when the email is already registered, to avoid leaking which
      // emails exist. Catch that here rather than hitting a confusing
      // foreign-key error from the account-creation RPC.
      if (response.user!.identities?.isEmpty ?? false) {
        setState(() {
          _loading = false;
          _error =
              'An account with this email already exists. Please sign in instead.';
        });
        return;
      }
      await _db.insertCustomerAccount(
        authUserId: response.user!.id,
        partnerId: partnerId,
        name: name,
        email: email,
        phone: phone.isNotEmpty ? phone : null,
      );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).pushReplacementNamed('/customer-home');
        return;
      }
      await _db.signOut();
      setState(() {
        _loading = false;
        _isSignUp = false;
        _success =
            'Account created! Check your email to confirm your address, then sign in.';
        _nameCtl.clear();
        _phoneCtl.clear();
        _pwCtl.clear();
        _confirmPwCtl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('AuthException: ', '');
      });
    }
  }

  static const _navy = LandingScreen.navy;
  static const _secondaryNavy = LandingScreen.secondaryNavy;
  static const _yellow = LandingScreen.yellow;
  static const _gold = LandingScreen.gold;
  static const _iceGray = LandingScreen.iceGray;
  static const _borderGray = LandingScreen.borderGray;

  InputDecoration _dec(String hint, {Widget? suffixIcon}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB0B9C4), fontSize: 13.5),
    filled: true,
    fillColor: _iceGray,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _borderGray),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _borderGray),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _brandColor ?? _gold, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    suffixIcon: suffixIcon,
  );

  Widget _fieldLabel(String t) => Text(
    t,
    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _navy),
  );

  @override
  Widget build(BuildContext context) {
    final canSignUp = TenantService().partnerId != null;
    final wide = MediaQuery.of(context).size.width > 920;
    final companyName = TenantService().companyName ?? 'One Village Shipping & Freight';
    final branding = PartnerBranding.from(TenantService().branding);
    _brandColor = branding.color != null ? Color(branding.color!) : null;

    final form = _buildFormPanel(canSignUp, companyName, branding);

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 5, child: _BrandPanel(branding: branding)),
                Expanded(
                  flex: 4,
                  child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: form)),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _CompactBrandHeader(branding: branding),
                  Padding(padding: const EdgeInsets.all(24), child: form),
                ],
              ),
            ),
    );
  }

  Widget _buildFormPanel(bool canSignUp, String companyName, PartnerBranding branding) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: _brandColor ?? _navy, borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.antiAlias,
                child: branding.logoUrl != null
                    ? AdaptiveImage(url: branding.logoUrl, assetPath: 'assets/images/one_village_logo.png', fit: BoxFit.cover)
                    : Image.asset(
                        'assets/images/one_village_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping_outlined, color: _yellow),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CUSTOMER PORTAL',
                      style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                    Text(
                      companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (canSignUp) _ModeToggle(
            isSignUp: _isSignUp,
            onChanged: (v) => setState(() {
              _isSignUp = v;
              _error = null;
              _success = null;
            }),
          ) else
            Text(
              _isSignUp ? 'Create your account' : 'Sign in to your account',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy),
            ),
          const SizedBox(height: 22),
          if (_success != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFF16845B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF16845B).withValues(alpha: 0.25)),
              ),
              child: Text(
                _success!,
                style: const TextStyle(color: Color(0xFF16845B), fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isSignUp) ...[
            _fieldLabel('Full Name'),
            const SizedBox(height: 6),
            TextField(controller: _nameCtl, decoration: _dec('Jane Doe')),
            const SizedBox(height: 16),
          ],
          _fieldLabel('Email'),
          const SizedBox(height: 6),
          TextField(controller: _emailCtl, decoration: _dec('you@example.com')),
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            _fieldLabel('Phone (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: _dec('+1 (876) 555-0100'),
            ),
          ],
          const SizedBox(height: 16),
          if (!_isSignUp)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _fieldLabel('Password'),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 12, color: _secondaryNavy, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else
            _fieldLabel('Password'),
          const SizedBox(height: 6),
          TextField(
            controller: _pwCtl,
            obscureText: !_showPw,
            onSubmitted: (_) => _isSignUp ? _signUp() : _signIn(),
            decoration: _dec(
              '••••••••',
              suffixIcon: IconButton(
                icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF8792A2)),
                onPressed: () => setState(() => _showPw = !_showPw),
              ),
            ),
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            _fieldLabel('Confirm Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmPwCtl,
              obscureText: !_showPw,
              onSubmitted: (_) => _signUp(),
              decoration: _dec('••••••••'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFB83A3A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB83A3A).withValues(alpha: 0.25)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB83A3A), fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : (_isSignUp ? _signUp : _signIn),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor ?? _yellow,
                foregroundColor: _brandColor != null ? _contrastColor(_brandColor!) : _navy,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              child: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _brandColor != null ? _contrastColor(_brandColor!) : _navy,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN'),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 17),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (!canSignUp && !_isSignUp) ...[
            const Center(
              child: Text(
                'Sign-up is available on your shipping partner\'s portal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/partner-login'),
              style: TextButton.styleFrom(foregroundColor: _secondaryNavy),
              icon: const Icon(Icons.business_center_outlined, size: 16),
              label: const Text('Shipping partner? Sign in here', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 12, color: Color(0xFF9CA3AF)),
                SizedBox(width: 5),
                Text(
                  'Protected by industry-standard encryption',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.isSignUp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: LandingScreen.iceGray, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(child: _tab('Sign In', !isSignUp, () => onChanged(false))),
          Expanded(child: _tab('Create Account', isSignUp, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? LandingScreen.navy : const Color(0xFF8792A2),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final PartnerBranding branding;
  const _BrandPanel({required this.branding});

  @override
  Widget build(BuildContext context) {
    final features = branding.features.isNotEmpty ? branding.features : _defaultFeatures;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [LandingScreen.navy, LandingScreen.secondaryNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.22,
            child: AdaptiveImage(url: branding.heroImageUrl, assetPath: 'assets/images/hero_port.jpg', fit: BoxFit.cover),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [LandingScreen.navy.withValues(alpha: 0.55), LandingScreen.navy],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 56, 48, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                branding.logoUrl != null
                    ? SizedBox(
                        height: 56,
                        child: AdaptiveImage(url: branding.logoUrl, assetPath: 'assets/images/one_village_logo.png', fit: BoxFit.contain),
                      )
                    : Image.asset(
                        'assets/images/one_village_logo.png',
                        height: 56,
                        errorBuilder: (_, __, ___) => const Text(
                          'ONE VILLAGE',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                const SizedBox(height: 44),
                Text(
                  branding.portalTitle ?? 'Track every shipment.\nAnywhere you are.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  branding.subtitle ?? 'Your personal dashboard for packages, invoices, and delivery updates — all in one place.',
                  style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 36),
                for (final f in features) ...[
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: LandingScreen.yellow, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check, size: 14, color: LandingScreen.navy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  final PartnerBranding branding;
  const _CompactBrandHeader({required this.branding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [LandingScreen.navy, LandingScreen.secondaryNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          branding.logoUrl != null
              ? SizedBox(
                  height: 48,
                  child: AdaptiveImage(url: branding.logoUrl, assetPath: 'assets/images/one_village_logo.png', fit: BoxFit.contain),
                )
              : Image.asset(
                  'assets/images/one_village_logo.png',
                  height: 48,
                  errorBuilder: (_, __, ___) => const Text(
                    'ONE VILLAGE',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
          const SizedBox(height: 12),
          Text(
            (branding.subtitle ?? 'Track every shipment, anywhere you are.').split('\n').first,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
