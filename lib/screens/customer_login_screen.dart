import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/tenant_service.dart';
import '../theme/app_theme.dart';

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

  InputDecoration _dec(String hint, {Widget? suffixIcon}) => InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    suffixIcon: suffixIcon,
  );

  Widget _fieldLabel(String t) =>
      Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

  @override
  Widget build(BuildContext context) {
    final canSignUp = TenantService().partnerId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Portal',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            TenantService().companyName ?? 'One Village Shipping & Freight',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            _isSignUp
                                ? 'Create your account'
                                : 'Sign in to your account',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_success != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _success!,
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_isSignUp) ...[
                  _fieldLabel('Full Name'),
                  const SizedBox(height: 6),
                  TextField(controller: _nameCtl, decoration: _dec('Jane Doe')),
                  const SizedBox(height: 14),
                ],
                _fieldLabel('Email'),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtl,
                  decoration: _dec('you@example.com'),
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 14),
                  _fieldLabel('Phone (optional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: _dec('+1 (876) 555-0100'),
                  ),
                ],
                const SizedBox(height: 14),
                if (!_isSignUp)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel('Password'),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                          ),
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
                      icon: Icon(
                        _showPw ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _showPw = !_showPw),
                    ),
                  ),
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : (_isSignUp ? _signUp : _signIn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isSignUp ? Icons.person_add_alt : Icons.login,
                            size: 18,
                          ),
                    label: Text(_isSignUp ? 'Create Account' : 'Sign In'),
                  ),
                ),
                const SizedBox(height: 14),
                if (canSignUp) ...[
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                        _success = null;
                      }),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : "Don't have an account? Create one",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ] else if (!_isSignUp) ...[
                  const Center(
                    child: Text(
                      'Sign-up is available on your shipping partner\'s portal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushReplacementNamed('/partner-login'),
                    icon: const Icon(Icons.business_center_outlined, size: 16),
                    label: const Text('Shipping partner? Sign in here'),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Protected by industry-standard encryption',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
