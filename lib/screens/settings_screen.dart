import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Every field on this screen used to be either a hardcoded literal or a
/// plain in-memory State variable — nothing loaded from or saved to the
/// database, and "Save Changes" showed a success message regardless. All
/// of it (Company Profile, Regional Settings, Notifications, Security,
/// Integrations) now reads from and writes to `company_settings`, a
/// single shared row every admin sees and edits. The one section that
/// was already real — API for 3rd Party Vendors — is unchanged.
const Map<String, dynamic> _settingsDefaults = {
  'companyName': 'One Village Shipping & Freight',
  'companyEmail': 'admin@applizonecentralja.com',
  'companyPhone': '',
  'companyAddress': '',
  'companyWebsite': '',
  'currency': 'USD',
  'weightUnit': 'lbs',
  'timezone': 'UTC-5 (Eastern)',
  'emailNotifications': true,
  'smsNotifications': false,
  'autoInvoicing': true,
  'twoFactorRequired': false,
  'integrations': {
    'stripe': {'enabled': false, 'key': ''},
    'sendgrid': {'enabled': false, 'key': ''},
    'twilio': {'enabled': false, 'key': ''},
    'webhooks': {'enabled': false, 'key': ''},
  },
};

Map<String, dynamic> _deepMerge(Map<String, dynamic> base, Map<String, dynamic> override) {
  final result = <String, dynamic>{...base};
  override.forEach((key, value) {
    final baseValue = result[key];
    if (value is Map && baseValue is Map) {
      result[key] = _deepMerge(
        Map<String, dynamic>.from(baseValue),
        Map<String, dynamic>.from(value),
      );
    } else if (value != null) {
      result[key] = value;
    }
  });
  return result;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  final _companyNameCtl = TextEditingController();
  final _companyEmailCtl = TextEditingController();
  final _companyPhoneCtl = TextEditingController();
  final _companyAddressCtl = TextEditingController();
  final _companyWebsiteCtl = TextEditingController();

  String _currency = 'USD';
  String _weightUnit = 'lbs';
  String _timezone = 'UTC-5 (Eastern)';
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _autoInvoicing = true;
  bool _twoFactorRequired = false;
  Map<String, Map<String, dynamic>> _integrations = {};

  static const _integrationKeys = ['stripe', 'sendgrid', 'twilio', 'webhooks'];

  @override
  void initState() {
    super.initState();
    _applySettings(_settingsDefaults);
    _load();
  }

  @override
  void dispose() {
    _companyNameCtl.dispose();
    _companyEmailCtl.dispose();
    _companyPhoneCtl.dispose();
    _companyAddressCtl.dispose();
    _companyWebsiteCtl.dispose();
    super.dispose();
  }

  void _applySettings(Map<String, dynamic> s) {
    _companyNameCtl.text = (s['companyName'] as String?) ?? '';
    _companyEmailCtl.text = (s['companyEmail'] as String?) ?? '';
    _companyPhoneCtl.text = (s['companyPhone'] as String?) ?? '';
    _companyAddressCtl.text = (s['companyAddress'] as String?) ?? '';
    _companyWebsiteCtl.text = (s['companyWebsite'] as String?) ?? '';
    _currency = (s['currency'] as String?) ?? 'USD';
    _weightUnit = (s['weightUnit'] as String?) ?? 'lbs';
    _timezone = (s['timezone'] as String?) ?? 'UTC-5 (Eastern)';
    _emailNotifications = (s['emailNotifications'] as bool?) ?? true;
    _smsNotifications = (s['smsNotifications'] as bool?) ?? false;
    _autoInvoicing = (s['autoInvoicing'] as bool?) ?? true;
    _twoFactorRequired = (s['twoFactorRequired'] as bool?) ?? false;
    final rawIntegrations = s['integrations'];
    final defaultIntegrations = _settingsDefaults['integrations'] as Map<String, dynamic>;
    _integrations = {
      for (final key in _integrationKeys)
        key: Map<String, dynamic>.from(
          (rawIntegrations is Map && rawIntegrations[key] is Map)
              ? rawIntegrations[key] as Map
              : defaultIntegrations[key] as Map,
        ),
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _db.getCompanySettings();
      final merged = _deepMerge(_settingsDefaults, raw ?? {});
      if (!mounted) return;
      setState(() {
        _applySettings(merged);
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load saved settings — showing defaults. $e';
      });
    }
  }

  Map<String, dynamic> _currentSettingsMap() => {
    'companyName': _companyNameCtl.text.trim(),
    'companyEmail': _companyEmailCtl.text.trim(),
    'companyPhone': _companyPhoneCtl.text.trim(),
    'companyAddress': _companyAddressCtl.text.trim(),
    'companyWebsite': _companyWebsiteCtl.text.trim(),
    'currency': _currency,
    'weightUnit': _weightUnit,
    'timezone': _timezone,
    'emailNotifications': _emailNotifications,
    'smsNotifications': _smsNotifications,
    'autoInvoicing': _autoInvoicing,
    'twoFactorRequired': _twoFactorRequired,
    'integrations': _integrations,
  };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updateCompanySettings(_currentSettingsMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          width: 280,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reverted to last saved settings.'),
        behavior: SnackBarBehavior.floating,
        width: 280,
      ),
    );
  }

  void _configureIntegration(String key, String label, IconData icon) {
    final current = _integrations[key] ?? {'enabled': false, 'key': ''};
    final keyCtl = TextEditingController(text: current['key'] as String? ?? '');
    bool enabled = current['enabled'] as bool? ?? false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Configure $label'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved for your own records. Actually sending live '
                  '$label requests from this app is separate work that '
                  "hasn't been built yet — this just remembers your "
                  'credential and whether you consider it set up.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '$label API Key',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleSetting(
                  label: 'Configured',
                  subtitle: 'Show this as set up on the Integrations list',
                  value: enabled,
                  onChanged: (v) => setDialogState(() => enabled = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _integrations[key] = {'enabled': enabled, 'key': keyCtl.text.trim()};
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final newPwCtl = TextEditingController();
    final confirmPwCtl = TextEditingController();
    String? error;
    bool saving = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: newPwCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPwCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) {},
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final pw = newPwCtl.text;
                      if (pw.length < 6) {
                        setDialogState(
                          () => error = 'Must be at least 6 characters',
                        );
                        return;
                      }
                      if (pw != confirmPwCtl.text) {
                        setDialogState(() => error = 'Passwords do not match');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _db.updateOwnPassword(pw);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Password changed.'),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                            width: 280,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = 'Failed: $e';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeamActivity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team & Login Activity'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _db.getAllAdminUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Failed to load: ${snapshot.error}');
              }
              final admins = snapshot.data ?? const [];
              if (admins.isEmpty) {
                return const Text('No admin accounts found.');
              }
              return ListView.separated(
                itemCount: admins.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                itemBuilder: (context, i) {
                  final a = admins[i];
                  final name = (a['full_name'] as String?)?.trim();
                  final email = (a['email'] as String?) ?? '';
                  final role = (a['role'] as String?) ?? '';
                  final active = a['is_active'] as bool? ?? true;
                  final lastLogin = a['last_login_at'] as String?;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      (name != null && name.isNotEmpty) ? name : email,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$email · $role${active ? '' : ' · deactivated'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      lastLogin != null
                          ? DateFormat('MMM d, h:mm a').format(DateTime.parse(lastLogin).toLocal())
                          : 'Never logged in',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Manage your platform preferences — changes here are shared by '
            'the whole admin team.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_loadError!, style: const TextStyle(fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 28),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final leftCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsSection(
                    title: 'Company Profile',
                    icon: Icons.business_rounded,
                    children: [
                      _EditableField(label: 'Company Name', controller: _companyNameCtl),
                      _EditableField(label: 'Email', controller: _companyEmailCtl),
                      _EditableField(label: 'Phone', controller: _companyPhoneCtl),
                      _EditableField(label: 'Address', controller: _companyAddressCtl),
                      _EditableField(
                        label: 'Website',
                        controller: _companyWebsiteCtl,
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Regional Settings',
                    icon: Icons.public_rounded,
                    children: [
                      _DropdownSetting(
                        label: 'Currency',
                        value: _currency,
                        items: const ['USD', 'EUR', 'GBP', 'CAD', 'JMD', 'TTD'],
                        onChanged: (v) => setState(() => _currency = v!),
                      ),
                      const SizedBox(height: 12),
                      _DropdownSetting(
                        label: 'Weight Unit',
                        value: _weightUnit,
                        items: const ['kg', 'lbs'],
                        onChanged: (v) => setState(() => _weightUnit = v!),
                      ),
                      const SizedBox(height: 12),
                      _DropdownSetting(
                        label: 'Timezone',
                        value: _timezone,
                        items: const [
                          'UTC-8 (Pacific)',
                          'UTC-7 (Mountain)',
                          'UTC-6 (Central)',
                          'UTC-5 (Eastern)',
                          'UTC+0 (GMT)',
                          'UTC+1 (CET)',
                          'UTC+5:30 (IST)',
                        ],
                        onChanged: (v) => setState(() => _timezone = v!),
                      ),
                    ],
                  ),
                ],
              );

              final rightCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsSection(
                    title: 'Notifications',
                    icon: Icons.notifications_rounded,
                    children: [
                      _ToggleSetting(
                        label: 'Email Notifications',
                        subtitle: 'Receive updates via email',
                        value: _emailNotifications,
                        onChanged: (v) => setState(() => _emailNotifications = v),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _ToggleSetting(
                        label: 'SMS Notifications',
                        subtitle: 'Receive updates via SMS',
                        value: _smsNotifications,
                        onChanged: (v) => setState(() => _smsNotifications = v),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _ToggleSetting(
                        label: 'Auto Invoicing',
                        subtitle: 'Automatically generate invoices',
                        value: _autoInvoicing,
                        onChanged: (v) => setState(() => _autoInvoicing = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Security',
                    icon: Icons.security_rounded,
                    children: [
                      _ToggleSetting(
                        label: 'Require Two-Factor Authentication',
                        subtitle: 'Saved as your security policy — sign-in '
                            "enforcement isn't wired up yet.",
                        value: _twoFactorRequired,
                        onChanged: (v) => setState(() => _twoFactorRequired = v),
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        label: 'Change Password',
                        icon: Icons.lock_outline,
                        onTap: _showChangePassword,
                      ),
                      const SizedBox(height: 8),
                      _ActionButton(
                        label: 'Team & Login Activity',
                        icon: Icons.history_rounded,
                        onTap: _showTeamActivity,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Integrations',
                    icon: Icons.integration_instructions_rounded,
                    children: [
                      _IntegrationTile(
                        name: 'Stripe',
                        description: 'Online payment processing',
                        configured: _integrations['stripe']?['enabled'] as bool? ?? false,
                        icon: Icons.credit_card,
                        onTap: () => _configureIntegration('stripe', 'Stripe', Icons.credit_card),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _IntegrationTile(
                        name: 'SendGrid',
                        description: 'Email delivery service',
                        configured: _integrations['sendgrid']?['enabled'] as bool? ?? false,
                        icon: Icons.email_rounded,
                        onTap: () => _configureIntegration('sendgrid', 'SendGrid', Icons.email_rounded),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _IntegrationTile(
                        name: 'Twilio',
                        description: 'SMS messaging',
                        configured: _integrations['twilio']?['enabled'] as bool? ?? false,
                        icon: Icons.sms_rounded,
                        onTap: () => _configureIntegration('twilio', 'Twilio', Icons.sms_rounded),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _IntegrationTile(
                        name: 'Webhooks API',
                        description: 'Custom event notifications',
                        configured: _integrations['webhooks']?['enabled'] as bool? ?? false,
                        icon: Icons.webhook,
                        onTap: () => _configureIntegration('webhooks', 'Webhooks API', Icons.webhook),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ApiAccessSection(),
                  const SizedBox(height: 20),
                  const _ScannerSettingsSection(),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftCol),
                    const SizedBox(width: 20),
                    Expanded(child: rightCol),
                  ],
                );
              }
              return Column(
                children: [leftCol, const SizedBox(height: 20), rightCol],
              );
            },
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _saving ? null : _discard,
                child: const Text(
                  'Discard Changes',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool last;

  const _EditableField({
    required this.label,
    required this.controller,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }
}

class _DropdownSetting extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownSetting({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Defensive: if a previously-saved value no longer appears in this
    // list (e.g. this screen's currency list changes in a future update),
    // fall back to the first option rather than handing the dropdown a
    // value that isn't among its items, which crashes.
    final safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              items: items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(i, style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSetting({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  final String name;
  final String description;
  final bool configured;
  final IconData icon;
  final VoidCallback onTap;

  const _IntegrationTile({
    required this.name,
    required this.description,
    required this.configured,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 18, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          configured
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Configured',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onTap,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      tooltip: 'Edit',
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                )
              : TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Configure',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// API for 3rd Party Vendors
// ═════════════════════════════════════════════════════════════════

/// Admin controls for the warehouse barcode+OCR scanner — its own
/// load/save cycle against scanner_settings, independent of this screen's
/// main Company Profile save flow so a mistake in one can never affect
/// the other. Only admins can reach Settings at all (see the app's own
/// navigation), and the underlying table is RLS-protected the same way.
class _ScannerSettingsSection extends StatefulWidget {
  const _ScannerSettingsSection();

  @override
  State<_ScannerSettingsSection> createState() => _ScannerSettingsSectionState();
}

class _ScannerSettingsSectionState extends State<_ScannerSettingsSection> {
  final _db = DatabaseService();
  bool _loading = true;
  bool _saving = false;
  double _autoMatchThreshold = 90;
  double _manualReviewThreshold = 70;
  bool _autoCaptureLabel = true;
  bool _rapidScanning = true;
  bool _saveLabelImages = true;
  bool _requireManualConfirmation = true;
  bool _offlineScanning = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _db.getScannerSettings();
      if (!mounted) return;
      setState(() {
        _autoMatchThreshold = (s['auto_match_threshold'] as num?)?.toDouble() ?? 90;
        _manualReviewThreshold = (s['manual_review_threshold'] as num?)?.toDouble() ?? 70;
        _autoCaptureLabel = s['auto_capture_label'] as bool? ?? true;
        _rapidScanning = s['rapid_scanning'] as bool? ?? true;
        _saveLabelImages = s['save_label_images'] as bool? ?? true;
        _requireManualConfirmation = s['require_manual_confirmation'] as bool? ?? true;
        _offlineScanning = s['offline_scanning'] as bool? ?? true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.updateScannerSettings({
        'auto_match_threshold': _autoMatchThreshold,
        'manual_review_threshold': _manualReviewThreshold,
        'auto_capture_label': _autoCaptureLabel,
        'rapid_scanning': _rapidScanning,
        'save_label_images': _saveLabelImages,
        'require_manual_confirmation': _requireManualConfirmation,
        'offline_scanning': _offlineScanning,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanner settings saved.'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SettingsSection(
        title: 'Warehouse Scanner Settings',
        icon: Icons.qr_code_scanner,
        children: [Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))],
      );
    }
    return _SettingsSection(
      title: 'Warehouse Scanner Settings',
      icon: Icons.qr_code_scanner,
      children: [
        Text('Auto-match threshold: ${_autoMatchThreshold.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Slider(
          value: _autoMatchThreshold,
          min: 50,
          max: 100,
          divisions: 50,
          label: '${_autoMatchThreshold.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _autoMatchThreshold = v),
        ),
        Text('Manual review threshold: ${_manualReviewThreshold.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Slider(
          value: _manualReviewThreshold,
          min: 0,
          max: _autoMatchThreshold,
          divisions: _autoMatchThreshold > 0 ? _autoMatchThreshold.toInt() : 1,
          label: '${_manualReviewThreshold.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _manualReviewThreshold = v),
        ),
        const Divider(height: 24, color: AppTheme.border),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Auto-capture label', style: TextStyle(fontSize: 13.5)),
          value: _autoCaptureLabel,
          onChanged: (v) => setState(() => _autoCaptureLabel = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Rapid scanning', style: TextStyle(fontSize: 13.5)),
          value: _rapidScanning,
          onChanged: (v) => setState(() => _rapidScanning = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Save label images', style: TextStyle(fontSize: 13.5)),
          value: _saveLabelImages,
          onChanged: (v) => setState(() => _saveLabelImages = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Require manual confirmation', style: TextStyle(fontSize: 13.5)),
          value: _requireManualConfirmation,
          onChanged: (v) => setState(() => _requireManualConfirmation = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Offline scanning', style: TextStyle(fontSize: 13.5)),
          value: _offlineScanning,
          onChanged: (v) => setState(() => _offlineScanning = v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Scanner Settings'),
          ),
        ),
      ],
    );
  }
}

class _ApiAccessSection extends StatefulWidget {
  @override
  State<_ApiAccessSection> createState() => _ApiAccessSectionState();
}

class _ApiAccessSectionState extends State<_ApiAccessSection> {
  final _db = DatabaseService();
  bool _loading = true;
  String? _keyId;
  String? _apiKey;
  bool _revealed = false;
  bool _sandbox = false;

  // Proxied through this same deployment (see .vercel/output/config.json)
  // to the real vendor-api Edge Function, so vendors never see the raw
  // supabase.co URL. Derived from whichever alias is currently loaded
  // rather than hardcoded, since all aliases of this deployment share it.
  String get _baseUrl => '${Uri.base.origin}/api/v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await _db.getVendorApiKey();
      if (!mounted) return;
      setState(() {
        _keyId = row?['id'] as String?;
        _apiKey = row?['key'] as String?;
        _sandbox = row?['sandbox'] as bool? ?? false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _generateKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(24, (_) => rand.nextInt(256));
    return 'az_live_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        width: 280,
      ),
    );
  }

  Future<void> _generateOrRegenerate() async {
    if (_keyId != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate API key?'),
          content: const Text(
            'Your existing API key will stop working immediately. '
            'Any vendor using it must be updated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    final newKey = _generateKey();
    try {
      final row = await _db.regenerateVendorApiKey(
        existingId: _keyId,
        newKey: newKey,
      );
      if (!mounted) return;
      setState(() {
        _keyId = row['id'] as String?;
        _apiKey = row['key'] as String?;
        _revealed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate key: $e')),
      );
    }
  }

  Future<void> _setSandbox(bool value) async {
    setState(() => _sandbox = value);
    if (_keyId == null) return;
    try {
      await _db.setVendorApiKeySandbox(_keyId!, value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sandbox = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update sandbox mode: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _apiKey != null;
    final displayKey = !hasKey
        ? 'No key generated yet'
        : (_revealed ? _apiKey! : 'az_live_${'•' * 28}');

    return _SettingsSection(
      title: 'API for 3rd Party Vendors',
      icon: Icons.vpn_key_rounded,
      children: [
        const Text(
          'Give your vendors secure, read/write access to your courier data. '
          'Every request is scoped to your account only.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else ...[
          // Base URL
          const Text(
            'Base URL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          _CodeRow(
            value: _baseUrl,
            onCopy: () => _copy(_baseUrl, 'Base URL'),
          ),
          const SizedBox(height: 14),

          // API Key
          const Text(
            'API Key',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _CodeRow(
                  value: displayKey,
                  onCopy: (hasKey && _revealed)
                      ? () => _copy(_apiKey!, 'API key')
                      : null,
                ),
              ),
              if (hasKey) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _revealed ? 'Hide' : 'Reveal',
                  icon: Icon(
                    _revealed ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => setState(() => _revealed = !_revealed),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _generateOrRegenerate,
                icon: Icon(hasKey ? Icons.refresh : Icons.add, size: 16),
                label: Text(
                  hasKey ? 'Regenerate' : 'Generate API Key',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (hasKey) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _copy(_apiKey!, 'API key'),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _ToggleSetting(
            label: 'Sandbox mode',
            subtitle: 'Route vendor requests to fixed sample data instead '
                'of live data — nothing sandbox requests do is persisted.',
            value: _sandbox,
            onChanged: _setSandbox,
          ),
        ],

        const Divider(height: 24, color: AppTheme.border),

        // Endpoints
        const Text(
          'Available Endpoints',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _EndpointRow(method: 'GET', path: '/packages'),
        _EndpointRow(method: 'POST', path: '/packages'),
        _EndpointRow(method: 'GET', path: '/packages/{tracking_number}'),
        _EndpointRow(method: 'GET', path: '/shipments'),
        _EndpointRow(method: 'POST', path: '/shipments'),
        _EndpointRow(method: 'GET', path: '/pre-alerts'),
        _EndpointRow(method: 'POST', path: '/pre-alerts'),
        _EndpointRow(method: 'GET', path: '/invoices'),
        _EndpointRow(method: 'POST', path: '/webhooks'),

        const SizedBox(height: 14),

        // Example request
        const Text(
          'Example request',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            'curl $_baseUrl/packages \\\n'
            '  -H "Authorization: Bearer YOUR_API_KEY" \\\n'
            '  -H "Content-Type: application/json"',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFE2E8F0),
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 12),
        _ActionButton(
          label: 'View full API documentation',
          icon: Icons.menu_book_rounded,
          onTap: () => _showDocs(context),
        ),
      ],
    );
  }

  void _showDocs(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vendor API reference'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Base URL: $_baseUrl',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Authenticate every request with:\n'
                  'Authorization: Bearer YOUR_API_KEY\n\n'
                  'GET /packages — list packages\n'
                  'POST /packages — create a package (tracking_number required)\n'
                  'GET /packages/{tracking_number} — look up one package\n'
                  'GET /shipments — list shipments\n'
                  'POST /shipments — create a shipment (shipment_number required)\n'
                  'GET /pre-alerts — list pre-alerts\n'
                  'POST /pre-alerts — create a pre-alert (tracking_number required)\n'
                  'GET /invoices — list invoices\n'
                  'POST /webhooks — subscribe a URL to package.created events '
                  '(url required; fires a real HTTP POST when a package is '
                  'created)\n\n'
                  'Turn on Sandbox mode above to get fixed sample data back '
                  'instead of live data while you build against the API — '
                  'sandbox requests never write anything real.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final String value;
  final VoidCallback? onCopy;
  const _CodeRow({required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.copy,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final String method;
  final String path;
  const _EndpointRow({required this.method, required this.path});

  Color get _methodColor {
    switch (method) {
      case 'GET':
        return const Color(0xFF2563EB);
      case 'POST':
        return const Color(0xFF16A34A);
      case 'PUT':
      case 'PATCH':
        return const Color(0xFFD97706);
      case 'DELETE':
        return const Color(0xFFDC2626);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: _methodColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _methodColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              method,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _methodColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              path,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
