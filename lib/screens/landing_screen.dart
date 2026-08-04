import 'package:flutter/material.dart';

/// Public marketing home page for the admin host, styled after a dark
/// navy / teal SaaS landing page (hero, highlights, features, CTA, footer).
class LandingScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  const LandingScreen({super.key, required this.onGetStarted});

  static const _bg = Color(0xFF0B1120);
  static const _bgAlt = Color(0xFF0F172A);
  static const _card = Color(0xFF111B2E);
  static const _teal = Color(0xFF2DD4BF);
  static const _tealDark = Color(0xFF14B8A6);
  static const _textPrimary = Color(0xFFF8FAFC);
  static const _textSecondary = Color(0xFF94A3B8);
  static const _border = Color(0xFF1E293B);

  static const _features = [
    (
      Icons.local_shipping_outlined,
      'Package & Shipment Tracking',
      'Track every package from pre-alert through delivery with a live status timeline.',
    ),
    (
      Icons.notifications_active_outlined,
      'Pre-Alerts',
      'Customers submit pre-alerts ahead of arrival so your team is never working blind.',
    ),
    (
      Icons.receipt_long_outlined,
      'Invoicing & POS',
      'Generate invoices and take payments at the counter, all tied back to the shipment record.',
    ),
    (
      Icons.qr_code_2_outlined,
      'Labels & Manifest',
      'Print shipping labels and build manifests for outbound freight in a few clicks.',
    ),
    (
      Icons.people_outline,
      'Customer & Partner Portals',
      'Give customers and shipping partners their own branded, tenant-scoped portal.',
    ),
    (
      Icons.insights_outlined,
      'Reporting',
      'Operational reports across branches, staff, and warehouses in one dashboard.',
    ),
  ];

  static const _highlights = [
    (Icons.bolt_outlined, 'Real-time updates'),
    (Icons.lock_outline, 'Tenant-isolated data'),
    (Icons.store_outlined, 'Multi-branch ready'),
    (Icons.devices_outlined, 'Works on any device'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(onGetStarted: onGetStarted),
            _Hero(onGetStarted: onGetStarted),
            _Highlights(highlights: _highlights),
            _Features(features: _features),
            _CtaBanner(onGetStarted: onGetStarted),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _MaxWidth extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _MaxWidth({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: child,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _Header({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LandingScreen._border)),
      ),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
                  colors: [LandingScreen._teal, LandingScreen._tealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'A',
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Applizone',
              style: TextStyle(
                color: LandingScreen._textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Courier Cloud',
              style: TextStyle(color: LandingScreen._textSecondary, fontSize: 13),
            ),
            const Spacer(),
            if (wide) ...[
              _NavLink('Features'),
              const SizedBox(width: 28),
              _NavLink('Contact'),
              const SizedBox(width: 28),
            ],
            OutlinedButton(
              onPressed: onGetStarted,
              style: OutlinedButton.styleFrom(
                foregroundColor: LandingScreen._textPrimary,
                side: const BorderSide(color: LandingScreen._border),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  const _NavLink(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: LandingScreen._textSecondary, fontSize: 14),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _Hero({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [LandingScreen._bg, LandingScreen._bgAlt],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: LandingScreen._teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: LandingScreen._teal.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'APPLIZONE CENTRAL JAMAICA',
                style: TextStyle(
                  color: LandingScreen._teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Reliable courier &\nwarehousing software',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LandingScreen._textPrimary,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: const Text(
                'The all-in-one platform to manage packages, shipments, invoices, '
                'and customers — built for Applizone\'s warehouse and courier operations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LandingScreen._textSecondary,
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onGetStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LandingScreen._teal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  child: const Text('Sign in to your account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  final List<(IconData, String)> highlights;
  const _Highlights({required this.highlights});

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 36,
        runSpacing: 20,
        children: highlights
            .map(
              (h) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(h.$1, color: LandingScreen._teal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    h.$2,
                    style: const TextStyle(
                      color: LandingScreen._textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  final List<(IconData, String, String)> features;
  const _Features({required this.features});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LandingScreen._bgAlt,
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 88),
        child: Column(
          children: [
            const Text(
              'Everything you need to run the operation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LandingScreen._textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'From the first pre-alert to the final invoice, one platform covers it all.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LandingScreen._textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 48),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 600
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: cols == 1 ? 2.6 : 1.5,
                  children: features
                      .map((f) => _FeatureCard(icon: f.$1, title: f.$2, desc: f.$3))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureCard({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LandingScreen._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LandingScreen._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: LandingScreen._teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: LandingScreen._teal, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: LandingScreen._textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              color: LandingScreen._textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaBanner extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CtaBanner({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              LandingScreen._teal.withValues(alpha: 0.15),
              LandingScreen._bgAlt,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: LandingScreen._border),
        ),
        child: Column(
          children: [
            const Text(
              'Ready to sign in?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LandingScreen._textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Warehouse staff and admins — access the portal below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LandingScreen._textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: LandingScreen._teal,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LandingScreen._border)),
      ),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              '© $_year Applizone Central Jamaica. All rights reserved.',
              style: const TextStyle(color: LandingScreen._textSecondary, fontSize: 13),
            ),
            if (wide) const Spacer() else const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              children: const [
                _FooterLink('Sign in'),
                _FooterLink('Contact'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final int _year = DateTime.now().year;

class _FooterLink extends StatelessWidget {
  final String label;
  const _FooterLink(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: LandingScreen._textSecondary, fontSize: 13),
    );
  }
}
