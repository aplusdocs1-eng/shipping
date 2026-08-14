import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://biuydcyyqeutfddxtruu.supabase.co';
  static const String anonKey =
      'sb_publishable_vsEIUhzsOGFY6HYKGeDGMA_eZ_ffdp-';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // PKCE (the default) ties a recovery/confirmation link to a code
      // verifier stored in whichever browser requested it — a customer
      // who asks for a password reset on desktop and opens the email on
      // their phone hits a dead end, since that verifier never leaves
      // the original browser's localStorage (confirmed live: requesting
      // a reset writes exactly one key,
      // "flutter.supabase.auth.token-code-verifier", scoped to that
      // browser only). This app has no external OAuth providers, where
      // PKCE's extra protection actually matters — every auth flow here
      // is plain email/password plus these email links — so implicit
      // flow's stateless links are the correct choice, not a downgrade.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }
}
