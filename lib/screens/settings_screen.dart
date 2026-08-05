import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _autoInvoicing = true;
  bool _twoFactorAuth = false;
  String _currency = 'USD';
  String _weightUnit = 'kg';
  String _timezone = 'UTC-5 (Eastern)';

  @override
  Widget build(BuildContext context) {
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
            'Manage your platform preferences',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
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
                      _SettingsField(
                        label: 'Company Name',
                        value: 'One Village Shipping & Freight',
                      ),
                      _SettingsField(
                        label: 'Email',
                        value: 'admin@applizonecentralja.com',
                      ),
                      _SettingsField(
                        label: 'Phone',
                        value: '+1 (305) 000-0000',
                      ),
                      _SettingsField(
                        label: 'Address',
                        value: '123 Logistics Ave, Miami, FL',
                      ),
                      _SettingsField(
                        label: 'Website',
                        value: 'https://courier.applizonecentralja.com',
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
                        onChanged: (v) =>
                            setState(() => _emailNotifications = v),
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
                        label: 'Two-Factor Authentication',
                        subtitle: 'Add an extra layer of security',
                        value: _twoFactorAuth,
                        onChanged: (v) => setState(() => _twoFactorAuth = v),
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        label: 'Change Password',
                        icon: Icons.lock_outline,
                        onTap: () {},
                      ),
                      const SizedBox(height: 8),
                      _ActionButton(
                        label: 'View Audit Log',
                        icon: Icons.history_rounded,
                        onTap: () {},
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
                        isConnected: true,
                        icon: Icons.credit_card,
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _IntegrationTile(
                        name: 'SendGrid',
                        description: 'Email delivery service',
                        isConnected: true,
                        icon: Icons.email_rounded,
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _IntegrationTile(
                        name: 'Twilio',
                        description: 'SMS messaging',
                        isConnected: false,
                        icon: Icons.sms_rounded,
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      _IntegrationTile(
                        name: 'Webhooks API',
                        description: 'Custom event notifications',
                        isConnected: false,
                        icon: Icons.webhook,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ApiAccessSection(),
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
          // Save button
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings saved successfully'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      width: 280,
                    ),
                  );
                },
                child: const Text('Save Changes'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {},
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

class _SettingsField extends StatelessWidget {
  final String label;
  final String value;

  const _SettingsField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            controller: TextEditingController(text: value),
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
              value: value,
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
  final bool isConnected;
  final IconData icon;

  const _IntegrationTile({
    required this.name,
    required this.description,
    required this.isConnected,
    required this.icon,
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
          isConnected
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.success.withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Connect',
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

class _ApiAccessSection extends StatefulWidget {
  @override
  State<_ApiAccessSection> createState() => _ApiAccessSectionState();
}

class _ApiAccessSectionState extends State<_ApiAccessSection> {
  String _apiKey = 'az_live_••••••••••••••••••••••••••••';
  bool _revealed = false;
  bool _sandbox = false;

  static const String _baseUrl =
      'https://api.courier.applizonecentralja.com/v1';

  String _generateKey() {
    final rand = DateTime.now().microsecondsSinceEpoch.toString();
    final suffix = rand.substring(rand.length - 8);
    return 'az_live_${base64Url.encode(utf8.encode(rand)).substring(0, 24)}$suffix';
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

  @override
  Widget build(BuildContext context) {
    final displayKey = _revealed ? _apiKey : 'az_live_${'•' * 28}';

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
        _CodeRow(value: _baseUrl, onCopy: () => _copy(_baseUrl, 'Base URL')),
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
                onCopy: _revealed ? () => _copy(_apiKey, 'API key') : null,
              ),
            ),
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
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
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
                if (confirm == true) {
                  setState(() {
                    _apiKey = _generateKey();
                    _revealed = true;
                  });
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerate', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _copy(_apiKey, 'API key'),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ToggleSetting(
          label: 'Sandbox mode',
          subtitle: 'Route vendor requests to test data',
          value: _sandbox,
          onChanged: (v) => setState(() => _sandbox = v),
        ),

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
          child: const SelectableText(
            'curl $_baseUrl/packages \\\n'
            '  -H "Authorization: Bearer YOUR_API_KEY" \\\n'
            '  -H "Content-Type: application/json"',
            style: TextStyle(
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
          onTap: () {},
        ),
      ],
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
              color: _methodColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _methodColor.withOpacity(0.3)),
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
