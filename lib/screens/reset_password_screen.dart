import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Landing page for the link in a "forgot password" email
/// (see showForgotPasswordDialog / sendPasswordResetEmail). Works the
/// same regardless of which of the three portals the request started
/// from — Supabase's client SDK detects the recovery token in this
/// page's own URL on load and establishes a real (recovery-scoped)
/// session automatically; this screen just waits for that, then lets
/// the user set a new password with it.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _db = DatabaseService();
  final _pwCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  StreamSubscription<AuthState>? _authSub;
  bool _ready = false;
  bool _saving = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The SDK may have already processed the recovery link by the time
    // this widget builds (typical) or may fire the event a moment
    // later — cover both rather than assuming either ordering.
    if (Supabase.instance.client.auth.currentSession != null) {
      _ready = true;
    }
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery ||
          (state.session != null && !_ready)) {
        if (mounted) setState(() => _ready = true);
      }
    });
    // If neither the current session nor an event confirms a recovery
    // session within a few seconds, the link was invalid/expired —
    // stop waiting and show that instead of a permanent spinner.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_ready) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pwCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _pwCtl.text;
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pw != _confirmCtl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _db.updatePassword(pw);
      await _db.signOut();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('AuthException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _done
                ? _buildDone(context)
                : _ready
                ? _buildForm()
                : _buildWaitingOrInvalid(),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingOrInvalid() {
    // The 4-second delayed setState in initState has nothing left to
    // wait on by the time this branch re-renders without _ready ever
    // having flipped true — that's the "give up and explain" state.
    final gaveUp = !_ready;
    if (!gaveUp) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.danger, size: 32),
        const SizedBox(height: 12),
        const Text(
          'This link is invalid or has expired',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Password reset links only work once and expire after a while. '
          'Go back to sign in and request a new one.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/customer-login'),
            child: const Text('Back to Sign In'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set a new password',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a new password for your account.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        const Text(
          'New Password',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _pwCtl,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '••••••••',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Confirm Password',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmCtl,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '••••••••',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppTheme.danger, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Reset Password'),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppTheme.success, size: 32),
        const SizedBox(height: 12),
        const Text(
          'Password updated',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          "You're signed out for now — sign back in with your new "
          'password wherever you normally do.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        _PortalLink(
          label: 'Customer Sign In',
          route: '/customer-login',
        ),
        const SizedBox(height: 8),
        _PortalLink(
          label: 'Courier Sign In',
          route: '/partner-login',
        ),
        const SizedBox(height: 8),
        _PortalLink(label: 'Staff Sign In', route: '/team'),
      ],
    );
  }
}

class _PortalLink extends StatelessWidget {
  final String label;
  final String route;
  const _PortalLink({required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pushReplacementNamed(route),
        child: Text(label),
      ),
    );
  }
}
