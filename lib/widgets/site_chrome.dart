import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../theme/public_colors.dart';

/// Shared chrome for every public-facing page (the landing page itself,
/// plus the dedicated About/Services/Rates/Contact pages): a consistent
/// top nav + footer so a visitor moving between them sees one continuous
/// site, not four different pages bolted together. Extracted out of
/// landing_screen.dart, which was the only place this used to live.

/// Centers content with a max width — the same simple wrapper
/// landing_screen.dart keeps privately (as `_MaxWidth`) for its own
/// sections; duplicated here rather than shared across files for a
/// one-screen-sized widget, to avoid coupling this file to that one.
class MaxWidth extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;
  const MaxWidth({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.maxWidth = 1180,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// The navy title strip at the top of every dedicated content page
/// (About/Services/Rates/Contact) — gives each one the same "real page,
/// not an afterthought" opening treatment the landing page's hero has.
class SitePageBanner extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  const SitePageBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: PublicColors.navy,
      child: MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: const TextStyle(
                color: PublicColors.yellow,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  subtitle!,
                  style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 15, height: 1.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Pushes a named route unless we're already there, so clicking the nav
// link for the page you're already on is a no-op instead of a pointless
// reload+re-stack.
void _goTo(BuildContext context, String route) {
  if (ModalRoute.of(context)?.settings.name == route) return;
  Navigator.of(context).pushNamed(route);
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Site-wide top nav. About/Services/Rates/Contact always navigate to their
/// dedicated routes — every page that shows this header gets the exact same
/// four links behaving the exact same way. Home and Get Started take
/// optional overrides because the landing page itself wants them to scroll
/// to a section instead of navigating (there's nowhere else to go from
/// there); every other page falls back to real navigation.
class SiteHeader extends StatelessWidget {
  final LandingContent content;
  final String currentRoute;
  final VoidCallback? onHome;
  final VoidCallback? onGetStarted;
  const SiteHeader({
    super.key,
    required this.content,
    this.currentRoute = '/',
    this.onHome,
    this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: PublicColors.borderGray)),
      ),
      child: MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            InkWell(
              onTap: onHome ??
                  () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/one_village_logo.png', height: 52),
                  // The logo itself is a busy illustrated badge — its own
                  // lettering reads fine full-size but is illegible at
                  // header height, so the company name is spelled out here
                  // in real, crisp text instead of relying on the artwork.
                  // Hidden below the `wide` breakpoint, same as the nav
                  // links below — at mobile widths there's no room left
                  // for it once Sign In and Get Started are accounted for.
                  if (wide) ...[
                    const SizedBox(width: 10),
                    Text(
                      content.str('header', 'companyName'),
                      style: const TextStyle(
                        color: PublicColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            if (wide) ...[
              _NavLink(
                'Home',
                onHome ??
                    () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false),
                active: currentRoute == '/',
              ),
              const SizedBox(width: 26),
              _NavLink(
                'About Us',
                () => _goTo(context, '/about'),
                active: currentRoute == '/about',
              ),
              const SizedBox(width: 26),
              _NavLink(
                'Services',
                () => _goTo(context, '/services'),
                active: currentRoute == '/services',
              ),
              const SizedBox(width: 26),
              _NavLink(
                'Rates',
                () => _goTo(context, '/rates'),
                active: currentRoute == '/rates',
              ),
              const SizedBox(width: 26),
              _NavLink(
                'Contact',
                () => _goTo(context, '/contact'),
                active: currentRoute == '/contact',
              ),
              const SizedBox(width: 26),
            ],
            const _SignInMenu(),
            const SizedBox(width: 14),
            ElevatedButton(
              onPressed: onGetStarted ??
                  () => Navigator.of(context).pushNamed(
                        '/customer-login',
                        arguments: {'signup': true},
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PublicColors.yellow,
                foregroundColor: PublicColors.navy,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              child: const Text('GET STARTED'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _NavLink(this.label, this.onTap, {this.active = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: active ? PublicColors.gold : PublicColors.charcoal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          if (active) ...[
            const SizedBox(height: 4),
            Container(width: 18, height: 2, color: PublicColors.gold),
          ],
        ],
      ),
    );
  }
}

class _SignInMenu extends StatelessWidget {
  const _SignInMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: PublicColors.borderGray),
      ),
      offset: const Offset(0, 40),
      onSelected: (v) {
        switch (v) {
          case 'customer':
            Navigator.of(context).pushNamed('/customer-login');
            break;
          case 'partner':
            Navigator.of(context).pushNamed('/partner-login');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'customer',
          child: _SignInMenuItem(
            icon: Icons.person_outline,
            title: 'Customer',
            subtitle: 'Track your shipments',
          ),
        ),
        PopupMenuItem(
          value: 'partner',
          child: _SignInMenuItem(
            icon: Icons.local_shipping_outlined,
            title: 'Courier',
            subtitle: 'Manage your shipments',
          ),
        ),
      ],
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SIGN IN',
            style: TextStyle(
              color: PublicColors.charcoal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down, size: 18, color: PublicColors.charcoal),
        ],
      ),
    );
  }
}

class _SignInMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SignInMenuItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PublicColors.secondaryNavy),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: PublicColors.navy, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(subtitle, style: const TextStyle(color: PublicColors.charcoalSoft, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

/// Site-wide footer. Needs `content` (the same LandingContent every public
/// page already loads for its own copy) for the tagline, services list,
/// contact details, and social links — everything else is handled
/// internally so no page needs to wire up callbacks just to show a footer.
class SiteFooter extends StatelessWidget {
  final LandingContent content;
  const SiteFooter({super.key, required this.content});

  void _showComingSoon(BuildContext context, String platform) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          platform,
          style: const TextStyle(color: PublicColors.navy, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Our $platform page is launching soon. Check back shortly to follow '
          'One Village Shipping & Freight!',
          style: const TextStyle(color: PublicColors.charcoal, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: PublicColors.secondaryNavy)),
          ),
        ],
      ),
    );
  }

  // A social icon with a real URL set opens it in a new tab; one left
  // blank (the default, until an admin fills it in on the Site Content
  // page) falls back to the "coming soon" popup instead of a dead link.
  void _handleSocialTap(BuildContext context, String label, String url) {
    if (url.trim().isEmpty) {
      _showComingSoon(context, label.isEmpty ? 'Social' : label);
      return;
    }
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Container(
      color: PublicColors.navy,
      child: Column(
        children: [
          MaxWidth(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: wide ? 3 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/images/one_village_logo.png', height: 44),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          content.str('footer', 'tagline'),
                          style: const TextStyle(color: Color(0xFFA9B8CC), fontSize: 12.5, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!wide) const SizedBox(height: 32),
                Expanded(
                  flex: wide ? 2 : 0,
                  child: _FooterColumn(
                    'QUICK LINKS',
                    [
                      ('Home', () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false)),
                      ('About Us', () => _goTo(context, '/about')),
                      ('Services', () => _goTo(context, '/services')),
                      ('Rates', () => _goTo(context, '/rates')),
                      ('Contact', () => _goTo(context, '/contact')),
                    ],
                  ),
                ),
                if (!wide) const SizedBox(height: 32),
                Expanded(
                  flex: 2,
                  child: _FooterColumn(
                    'SERVICES',
                    [
                      for (final s in content.list('services', 'items'))
                        ((s['title'] as String?) ?? '', () => _goTo(context, '/services')),
                    ],
                  ),
                ),
                if (!wide) const SizedBox(height: 32),
                Expanded(
                  flex: wide ? 3 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONTACT US',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 14),
                      _FooterContactRow(Icons.phone_outlined, content.str('contact', 'phone')),
                      const SizedBox(height: 10),
                      _FooterContactRow(Icons.location_on_outlined, content.str('contact', 'address')),
                      const SizedBox(height: 10),
                      _FooterContactRow(Icons.email_outlined, content.str('contact', 'email')),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final s in content.list('social', 'items'))
                            _SocialIcon(
                              LandingContent.iconFor((s['icon'] as String?) ?? '', Icons.public),
                              label: (s['label'] as String?) ?? '',
                              onTap: () => _handleSocialTap(
                                context,
                                (s['label'] as String?) ?? '',
                                (s['url'] as String?) ?? '',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (wide) const SizedBox(width: 24),
                if (wide)
                  const Expanded(
                    flex: 3,
                    child: Align(alignment: Alignment.centerRight, child: _FooterRouteMap()),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E3556), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              '© ${DateTime.now().year} ${content.str('footer', 'copyrightName')}. All Rights Reserved.',
              style: const TextStyle(color: Color(0xFFA9B8CC), fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterRouteMap extends StatelessWidget {
  const _FooterRouteMap();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 150,
      child: CustomPaint(painter: _RouteMapPainter()),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const spacing = 11.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final n = math.sin(x * 0.19) * math.cos(y * 0.24) + math.sin((x + y) * 0.06);
        if (n > 0.15) {
          canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
        }
      }
    }

    final points = [
      Offset(size.width * 0.10, size.height * 0.30),
      Offset(size.width * 0.52, size.height * 0.68),
      Offset(size.width * 0.88, size.height * 0.38),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    path.quadraticBezierTo(
      size.width * 0.30, size.height * 0.85,
      points[1].dx, points[1].dy,
    );
    path.quadraticBezierTo(
      size.width * 0.70, size.height * 0.90,
      points[2].dx, points[2].dy,
    );

    final routePaint = Paint()
      ..color = PublicColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    _drawDashedPath(canvas, path, routePaint);

    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = PublicColors.gold.withValues(alpha: 0.22));
      canvas.drawCircle(p, 3, Paint()..color = PublicColors.yellow);
      canvas.drawCircle(p, 1.2, Paint()..color = PublicColors.navy);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) => false;
}

class _FooterContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FooterContactRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: PublicColors.yellow, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFFA9B8CC), fontSize: 12.5)),
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialIcon(this.icon, {this.label = '', required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: PublicColors.yellow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: PublicColors.navy),
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<(String, VoidCallback)> links;
  const _FooterColumn(this.title, this.links);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        const SizedBox(height: 14),
        for (final l in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: l.$2,
              child: Text(l.$1, style: const TextStyle(color: Color(0xFFA9B8CC), fontSize: 12.5)),
            ),
          ),
      ],
    );
  }
}
