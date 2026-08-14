import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Shared "forgot password" popup for all three login screens (customer,
/// courier, staff) — the request itself isn't portal-specific, it's a
/// plain Supabase Auth email keyed off whatever account owns the address.
/// Deliberately reports success even if [initialEmail] doesn't match any
/// account: Supabase's own resetPasswordForEmail already does this (it
/// never errors on an unknown email), so this just doesn't undo that by
/// wrapping it in a try/catch that would leak which emails are and
/// aren't registered.
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String? initialEmail,
}) async {
  final emailCtl = TextEditingController(text: initialEmail ?? '');
  final db = DatabaseService();
  bool sending = false;
  bool sent = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> send() async {
          final email = emailCtl.text.trim();
          if (email.isEmpty) {
            setState(() => error = 'Enter your email address.');
            return;
          }
          setState(() {
            sending = true;
            error = null;
          });
          try {
            await db.sendPasswordResetEmail(email);
            setState(() {
              sending = false;
              sent = true;
            });
          } catch (e) {
            setState(() {
              sending = false;
              error = e.toString();
            });
          }
        }

        return AlertDialog(
          title: const Text('Reset your password'),
          content: SizedBox(
            width: 340,
            child: sent
                ? const Text(
                    'If an account exists for that email, a password reset '
                    'link is on its way. Check your inbox (and spam '
                    'folder) — the link is valid for a limited time.',
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Enter the email address on your account and '
                        "we'll send you a link to set a new password.",
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailCtl,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => sending ? null : send(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFFB83A3A),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(sent ? 'Close' : 'Cancel'),
            ),
            if (!sent)
              FilledButton(
                onPressed: sending ? null : send,
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Reset Link'),
              ),
          ],
        );
      },
    ),
  );
  emailCtl.dispose();
}
