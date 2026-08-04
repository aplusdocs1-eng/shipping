import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Public marketing home page for the admin host, styled after a dark
/// navy / teal SaaS landing page: hero with a live-data mockup, stats bar,
/// platform-highlights bento grid, feature dashboard mockup, pricing, and
/// footer. All navigation and CTAs are wired to real actions.
class LandingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  const LandingScreen({super.key, required this.onGetStarted});

  static const bg = Color(0xFF0B1120);
  static const bgAlt = Color(0xFF0F172A);
  static const card = Color(0xFF111B2E);
  static const cardAlt = Color(0xFF15213A);
  static const teal = Color(0xFF2DD4BF);
  static const tealDark = Color(0xFF14B8A6);
  static const purple = Color(0xFFA78BFA);
  static const amber = Color(0xFFFBBF24);
  static const green = Color(0xFF34D399);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const border = Color(0xFF1E293B);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0,
    );
  }

  void _showInfoDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LandingScreen.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(color: LandingScreen.textPrimary)),
        content: Text(
          body,
          style: const TextStyle(color: LandingScreen.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: LandingScreen.teal)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandingScreen.bg,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _Header(
              onGetStarted: widget.onGetStarted,
              onHome: _scrollToTop,
              onFeatures: () => _scrollToKey(_featuresKey),
              onPricing: () => _scrollToKey(_pricingKey),
              onContact: () => _showInfoDialog(
                'Contact us',
                'Reach the Applizone Central Jamaica team at '
                    'applizonecentralja@gmail.com.',
              ),
            ),
            _Hero(onGetStarted: widget.onGetStarted),
            const _StatsBar(),
            const _Highlights(),
            _Features(key: _featuresKey, onGetStarted: widget.onGetStarted),
            _Pricing(key: _pricingKey, onGetStarted: widget.onGetStarted),
            _CtaBanner(onGetStarted: widget.onGetStarted),
            _Footer(
              onHome: _scrollToTop,
              onFeatures: () => _scrollToKey(_featuresKey),
              onPricing: () => _scrollToKey(_pricingKey),
              onAbout: () => _showInfoDialog(
                'About Applizone',
                'Applizone Central Jamaica builds the software that powers '
                    'courier and warehouse operations for shipping partners '
                    'across Jamaica — package tracking, invoicing, manifests, '
                    'and multi-tenant partner portals in one platform.',
              ),
              onContact: () => _showInfoDialog(
                'Contact us',
                'Reach the Applizone Central Jamaica team at '
                    'applizonecentralja@gmail.com.',
              ),
              onPrivacy: () => _showInfoDialog(
                'Privacy Policy',
                'Applizone Central Jamaica\'s full privacy policy will be '
                    'published here. Tenant data is isolated per shipping '
                    'partner and never shared across accounts.',
              ),
              onTerms: () => _showInfoDialog(
                'Terms of Service',
                'Applizone Central Jamaica\'s full terms of service will be '
                    'published here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaxWidth extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;
  const _MaxWidth({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.maxWidth = 1120,
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

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onHome;
  final VoidCallback onFeatures;
  final VoidCallback onPricing;
  final VoidCallback onContact;
  const _Header({
    required this.onGetStarted,
    required this.onHome,
    required this.onFeatures,
    required this.onPricing,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 760;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LandingScreen.border)),
      ),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            InkWell(
              onTap: onHome,
              child: const Row(
                children: [
                  _LogoMark(),
                  SizedBox(width: 10),
                  Text(
                    'Applizone',
                    style: TextStyle(
                      color: LandingScreen.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (wide) ...[
              _NavLink('Home', onHome),
              const SizedBox(width: 28),
              _NavLink('Pricing', onPricing),
              const SizedBox(width: 28),
              _NavLink('Contact', onContact),
              const SizedBox(width: 28),
            ],
            ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: LandingScreen.teal,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          colors: [LandingScreen.teal, LandingScreen.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.local_shipping_rounded, size: 17, color: Colors.black),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 14),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _Hero({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 980;
    final copy = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: LandingScreen.cardAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: LandingScreen.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: LandingScreen.teal),
              SizedBox(width: 8),
              Text(
                'Courier & Warehouse SaaS Platform',
                style: TextStyle(
                  color: LandingScreen.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Reliable Courier &',
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: LandingScreen.textPrimary,
            fontSize: 46,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -1,
          ),
        ),
        Wrap(
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [LandingScreen.teal, LandingScreen.tealDark],
              ).createShader(bounds),
              child: const Text(
                'Warehousing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -1,
                ),
              ),
            ),
            const Text(
              ' Software',
              style: TextStyle(
                color: LandingScreen.textPrimary,
                fontSize: 46,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'The all-in-one platform to manage packages, shipments, invoices, '
            'and customers. Built for couriers and warehouses that move fast.',
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: LandingScreen.textSecondary,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: onGetStarted,
          style: ElevatedButton.styleFrom(
            backgroundColor: LandingScreen.teal,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Get Started'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AvatarStack(),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star, size: 13, color: LandingScreen.amber),
                    Icon(Icons.star, size: 13, color: LandingScreen.amber),
                    Icon(Icons.star, size: 13, color: LandingScreen.amber),
                    Icon(Icons.star, size: 13, color: LandingScreen.amber),
                    Icon(Icons.star, size: 13, color: LandingScreen.amber),
                  ],
                ),
                const SizedBox(height: 2),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: LandingScreen.textSecondary),
                    children: [
                      TextSpan(text: 'Trusted by '),
                      TextSpan(
                        text: '50+',
                        style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' shipping partners'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final mockup = const _HeroMockup();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [LandingScreen.bg, LandingScreen.bgAlt],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: copy),
                  const SizedBox(width: 48),
                  Expanded(flex: 4, child: mockup),
                ],
              )
            : Column(
                children: [
                  copy,
                  const SizedBox(height: 48),
                  mockup,
                ],
              ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  static const _people = [
    ('JD', LandingScreen.teal),
    ('MK', LandingScreen.purple),
    ('AS', LandingScreen.amber),
    ('RL', LandingScreen.green),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26.0 * 3 + 28,
      height: 28,
      child: Stack(
        children: [
          for (var i = 0; i < _people.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _people[i].$2,
                  border: Border.all(color: LandingScreen.bg, width: 2),
                ),
                child: Text(
                  _people[i].$1,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroMockup extends StatelessWidget {
  const _HeroMockup();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: LandingScreen.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: LandingScreen.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: LandingScreen.teal, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Text('AZ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                  const SizedBox(width: 10),
                  const Text('Demo Courier Co.', style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  const Icon(Icons.notifications_none, size: 18, color: LandingScreen.textSecondary),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _MockStat('Credit', '\$420.00')),
                  const SizedBox(width: 10),
                  Expanded(child: _MockStat('Points', '1,240')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MockStat('Packages', '3 ready')),
                  const SizedBox(width: 10),
                  Expanded(child: _MockStat('This month', '\$1,180')),
                ],
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Text('Recent Packages', style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                  Spacer(),
                  Text('View all', style: TextStyle(color: LandingScreen.teal, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              const _MockPackageRow('AZ394894589', 'Shipped', LandingScreen.teal),
              const SizedBox(height: 8),
              const _MockPackageRow('AZ798767898', 'In transit', LandingScreen.amber),
              const SizedBox(height: 8),
              const _MockPackageRow('AZ356765435', 'Delivered', LandingScreen.green),
              const SizedBox(height: 28),
            ],
          ),
        ),
        Positioned(
          top: -16,
          right: -12,
          child: _FloatingChip(icon: Icons.inventory_2_outlined, label: '1,204', sub: 'Packages tracked'),
        ),
        Positioned(
          bottom: -14,
          left: -12,
          child: _FloatingChip(icon: Icons.trending_up, label: '99.9%', sub: 'Uptime'),
        ),
      ],
    );
  }
}

class _MockStat extends StatelessWidget {
  final String label;
  final String value;
  const _MockStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LandingScreen.cardAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: LandingScreen.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MockPackageRow extends StatelessWidget {
  final String tracking;
  final String status;
  final Color color;
  const _MockPackageRow(this.tracking, this.status, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LandingScreen.cardAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tracking,
              style: const TextStyle(color: LandingScreen.textPrimary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _FloatingChip({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LandingScreen.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LandingScreen.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: LandingScreen.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: LandingScreen.teal),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: LandingScreen.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
              Text(sub, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats bar
// ---------------------------------------------------------------------------

class _StatsBar extends StatelessWidget {
  const _StatsBar();

  static const _stats = [
    ('50+', 'Active Partners'),
    ('250K+', 'Packages Processed'),
    ('99.9%', 'Platform Uptime'),
    ('12+', 'Parishes Served'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LandingScreen.bgAlt,
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 48,
          runSpacing: 24,
          children: _stats
              .map(
                (s) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.$1,
                      style: const TextStyle(color: LandingScreen.textPrimary, fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(s.$2, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 12)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Platform highlights (bento grid)
// ---------------------------------------------------------------------------

class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 88),
      child: Column(
        children: [
          const Text(
            'PLATFORM HIGHLIGHTS',
            style: TextStyle(color: LandingScreen.teal, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          const Text(
            'Everything you need to scale',
            textAlign: TextAlign.center,
            style: TextStyle(color: LandingScreen.textPrimary, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 900;
              const chart = _AnalyticsCard();
              const security = _SecurityCard();
              const scalable = _ScalableCard();
              const trust = _TrustCard();
              const mobile = _MobileCard();
              if (!wide) {
                return const Column(
                  children: [chart, SizedBox(height: 16), security, SizedBox(height: 16), scalable, SizedBox(height: 16), trust, SizedBox(height: 16), mobile],
                );
              }
              return const Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: chart),
                        SizedBox(width: 16),
                        Expanded(child: security),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: scalable),
                        SizedBox(width: 16),
                        Expanded(child: trust),
                        SizedBox(width: 16),
                        Expanded(child: mobile),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final Widget child;
  const _HighlightCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: LandingScreen.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LandingScreen.border),
      ),
      child: child,
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard();

  @override
  Widget build(BuildContext context) {
    return _HighlightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: LandingScreen.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Icon(Icons.bar_chart_rounded, size: 16, color: LandingScreen.teal),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Realtime Analytics', style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Live tracking dashboard', style: TextStyle(color: LandingScreen.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(color: LandingScreen.teal, label: 'Packages'),
              _LegendDot(color: LandingScreen.purple, label: 'Deliveries'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                minY: 0,
                maxY: 300,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 190), FlSpot(1, 230), FlSpot(2, 205), FlSpot(3, 260),
                      FlSpot(4, 240), FlSpot(5, 270), FlSpot(6, 250), FlSpot(7, 225),
                      FlSpot(8, 255), FlSpot(9, 230), FlSpot(10, 200), FlSpot(11, 215),
                    ],
                    isCurved: true,
                    color: LandingScreen.teal,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: LandingScreen.teal.withValues(alpha: 0.08)),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 130), FlSpot(1, 150), FlSpot(2, 120), FlSpot(3, 160),
                      FlSpot(4, 110), FlSpot(5, 140), FlSpot(6, 125), FlSpot(7, 100),
                      FlSpot(8, 135), FlSpot(9, 105), FlSpot(10, 90), FlSpot(11, 115),
                    ],
                    isCurved: true,
                    color: LandingScreen.purple,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return _HighlightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: LandingScreen.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Icon(Icons.verified_user_outlined, size: 16, color: LandingScreen.purple),
          ),
          const SizedBox(height: 14),
          const Text('Enterprise-grade Security', style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            'Your data is protected with tenant isolation, encrypted transport, and automatic backups.',
            style: TextStyle(color: LandingScreen.textSecondary, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill('SSL/TLS', LandingScreen.purple),
              _Pill('RLS', LandingScreen.purple),
              _Pill('Encrypted', LandingScreen.purple),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ScalableCard extends StatelessWidget {
  const _ScalableCard();

  @override
  Widget build(BuildContext context) {
    return _HighlightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: LandingScreen.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Icon(Icons.bolt, size: 16, color: LandingScreen.amber),
              ),
              const Spacer(),
              const _Pill('15+ modules', LandingScreen.amber),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Infinitely Scalable', style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            'Multiple branches, unlimited staff accounts, and an API built for growth.',
            style: TextStyle(color: LandingScreen.textSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    return _HighlightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trusted by shipping partners', style: TextStyle(color: LandingScreen.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          const Text('50+', style: TextStyle(color: LandingScreen.textPrimary, fontSize: 30, fontWeight: FontWeight.w800)),
          const Text('partners across Jamaica', style: TextStyle(color: LandingScreen.textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.star, size: 13, color: LandingScreen.amber),
              Icon(Icons.star, size: 13, color: LandingScreen.amber),
              Icon(Icons.star, size: 13, color: LandingScreen.amber),
              Icon(Icons.star, size: 13, color: LandingScreen.amber),
              Icon(Icons.star_half, size: 13, color: LandingScreen.amber),
              SizedBox(width: 6),
              Text('4.8/5 average rating', style: TextStyle(color: LandingScreen.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileCard extends StatelessWidget {
  const _MobileCard();

  @override
  Widget build(BuildContext context) {
    return _HighlightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: LandingScreen.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: const Icon(Icons.devices_outlined, size: 16, color: LandingScreen.green),
          ),
          const SizedBox(height: 14),
          const Text('Mobile-first Design', style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            'Built to work great on any device — warehouse floor, front desk, or on the road.',
            style: TextStyle(color: LandingScreen.textSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Features + dashboard mockup
// ---------------------------------------------------------------------------

class _Features extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _Features({super.key, required this.onGetStarted});

  static const _items = [
    (Icons.location_on_outlined, 'Advanced Tracking', 'Live status timeline from pre-alert through delivery.'),
    (Icons.dashboard_outlined, 'Dashboard Portals', 'Separate portals for admins, partners, and customers.'),
    (Icons.mark_email_read_outlined, 'Email Notifications', 'Automated updates keep customers informed at every step.'),
    (Icons.receipt_long_outlined, 'Invoice Management', 'Generate and track invoices tied to every shipment.'),
    (Icons.api_outlined, 'Powerful API', 'Integrate pre-alerts and tracking with 3rd-party systems.'),
    (Icons.insights_outlined, 'Advanced Reporting', 'Operational reports across branches, staff, and warehouses.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LandingScreen.bgAlt,
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 88),
        child: Column(
          children: [
            const Text(
              'The ultimate courier & warehouse platform',
              textAlign: TextAlign.center,
              style: TextStyle(color: LandingScreen.textPrimary, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: const Text(
                'Keep everything in one place — efficiently and securely. Built to manage '
                'every part of your courier or warehouse operation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LandingScreen.textSecondary, fontSize: 15, height: 1.6),
              ),
            ),
            const SizedBox(height: 48),
            const _DashboardMockup(),
            const SizedBox(height: 56),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 28,
                  crossAxisSpacing: 28,
                  childAspectRatio: cols == 1 ? 3.2 : 2.3,
                  children: _items.map((f) => _FeatureRow(icon: f.$1, title: f.$2, desc: f.$3)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureRow({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: LandingScreen.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: LandingScreen.teal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 12, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardMockup extends StatelessWidget {
  const _DashboardMockup();

  static const _nav = [
    (Icons.dashboard_outlined, 'Dashboard', true),
    (Icons.point_of_sale_outlined, 'Point of Sale', false),
    (Icons.people_outline, 'Customers', false),
    (Icons.inventory_2_outlined, 'Packages', false),
    (Icons.local_shipping_outlined, 'Shipments', false),
    (Icons.notifications_active_outlined, 'Pre-Alerts', false),
    (Icons.insights_outlined, 'Reports', false),
    (Icons.settings_outlined, 'Settings', false),
  ];

  static const _stats = [
    ('Total Customers', '58', LandingScreen.teal, Icons.people_outline),
    ('Registered Users', '219', LandingScreen.purple, Icons.person_outline),
    ('Packages Processed', '14', LandingScreen.green, Icons.inventory_2_outlined),
    ('Revenue (30d)', '\$8,240', LandingScreen.amber, Icons.attach_money),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final showSidebar = c.maxWidth > 700;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: LandingScreen.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: LandingScreen.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSidebar)
                  Container(
                    width: 170,
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: LandingScreen.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            _LogoMark(),
                            SizedBox(width: 8),
                            Text('Applizone', style: TextStyle(color: LandingScreen.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        for (final n in _nav)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              decoration: BoxDecoration(
                                color: n.$3 ? LandingScreen.teal.withValues(alpha: 0.12) : null,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(n.$1, size: 13, color: n.$3 ? LandingScreen.teal : LandingScreen.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(n.$2, style: TextStyle(fontSize: 10, color: n.$3 ? LandingScreen.textPrimary : LandingScreen.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dashboard  ›  Overview', style: TextStyle(color: LandingScreen.textSecondary, fontSize: 11)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _stats
                              .map(
                                (s) => Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: LandingScreen.cardAlt, borderRadius: BorderRadius.circular(10)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(s.$4, size: 14, color: s.$3),
                                      const SizedBox(height: 8),
                                      Text(s.$2, style: const TextStyle(color: LandingScreen.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                                      Text(s.$1, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 9)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: LandingScreen.cardAlt, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Package & Customer Growth', style: TextStyle(color: LandingScreen.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 110,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: const FlTitlesData(show: false),
                                    borderData: FlBorderData(show: false),
                                    lineTouchData: const LineTouchData(enabled: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: const [
                                          FlSpot(0, 30), FlSpot(1, 55), FlSpot(2, 40), FlSpot(3, 70),
                                          FlSpot(4, 50), FlSpot(5, 90), FlSpot(6, 60), FlSpot(7, 75),
                                        ],
                                        isCurved: true,
                                        color: LandingScreen.teal,
                                        barWidth: 2,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(show: true, color: LandingScreen.teal.withValues(alpha: 0.08)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pricing
// ---------------------------------------------------------------------------

class _Pricing extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _Pricing({super.key, required this.onGetStarted});

  static const _courierFeatures = [
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
  ];

  static const _warehouseFeatures = [
    'Courier Portal',
    'Advanced Package Tracking',
    'Invoice Management',
    'Shipment Management',
    'API for 3rd-Party Vendors',
    'Manifest Generation',
    'Label Generation',
    'Cloud Printing',
    'Advanced Reporting',
    'No Setup Fee',
    'Staff Mobile Access',
    'White Label',
  ];

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 88),
      child: Column(
        children: [
          const Text('PRICING', style: TextStyle(color: LandingScreen.teal, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          const Text(
            'Plans that grow with you',
            textAlign: TextAlign.center,
            style: TextStyle(color: LandingScreen.textPrimary, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Transparent pricing with no hidden fees. Start with what you need and scale as you grow.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LandingScreen.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: LandingScreen.cardAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: LandingScreen.border),
            ),
            child: const Text(
              'Illustrative pricing — contact us for a plan tailored to your operation',
              style: TextStyle(color: LandingScreen.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 820;
              final courier = _PricingCard(
                badge: 'MOST POPULAR',
                title: 'Courier Platform',
                subtitle: 'Manage all your customers and packages in one place',
                price: '\$29',
                perPackage: '+ \$0.15 per package',
                callout: 'iOS & Android apps included at no extra cost',
                buttonFilled: true,
                features: _courierFeatures,
                onGetStarted: onGetStarted,
              );
              final warehouse = _PricingCard(
                badge: null,
                title: 'Warehouse Platform',
                subtitle: 'End-to-end warehouse management for large operations',
                price: '\$199',
                perPackage: '+ \$0.12 per package',
                callout: null,
                buttonFilled: false,
                features: _warehouseFeatures,
                onGetStarted: onGetStarted,
              );
              if (!wide) {
                return Column(children: [courier, const SizedBox(height: 20), warehouse]);
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: courier),
                    const SizedBox(width: 20),
                    Expanded(child: warehouse),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String? badge;
  final String title;
  final String subtitle;
  final String price;
  final String perPackage;
  final String? callout;
  final bool buttonFilled;
  final List<String> features;
  final VoidCallback onGetStarted;

  const _PricingCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.perPackage,
    required this.callout,
    required this.buttonFilled,
    required this.features,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: LandingScreen.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: badge != null ? LandingScreen.teal.withValues(alpha: 0.5) : LandingScreen.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: LandingScreen.teal, borderRadius: BorderRadius.circular(999)),
              child: Text(badge!, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 14),
          ],
          Text(title, style: const TextStyle(color: LandingScreen.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(color: LandingScreen.textPrimary, fontSize: 34, fontWeight: FontWeight.w800)),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text('/mo', style: TextStyle(color: LandingScreen.textSecondary, fontSize: 13)),
              ),
            ],
          ),
          Text(perPackage, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 11)),
          if (callout != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: LandingScreen.cardAlt, borderRadius: BorderRadius.circular(8)),
              child: Text(callout!, textAlign: TextAlign.center, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 11)),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: buttonFilled
                ? ElevatedButton(
                    onPressed: onGetStarted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LandingScreen.teal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    child: const Text('Get Started'),
                  )
                : OutlinedButton(
                    onPressed: onGetStarted,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LandingScreen.textPrimary,
                      side: const BorderSide(color: LandingScreen.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    child: const Text('Get Started'),
                  ),
          ),
          const SizedBox(height: 20),
          const Divider(color: LandingScreen.border, height: 1),
          const SizedBox(height: 16),
          Text('WHAT\'S INCLUDED', style: TextStyle(color: LandingScreen.textSecondary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: LandingScreen.teal),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA + footer
// ---------------------------------------------------------------------------

class _CtaBanner extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CtaBanner({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 88),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [LandingScreen.teal.withValues(alpha: 0.15), LandingScreen.bgAlt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: LandingScreen.border),
        ),
        child: Column(
          children: [
            const Text(
              'Ready to streamline your operations?',
              textAlign: TextAlign.center,
              style: TextStyle(color: LandingScreen.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Join 50+ shipping partners that trust Applizone to power their courier and warehouse operations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LandingScreen.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: LandingScreen.teal,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Get Started'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onFeatures;
  final VoidCallback onPricing;
  final VoidCallback onAbout;
  final VoidCallback onContact;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  const _Footer({
    required this.onHome,
    required this.onFeatures,
    required this.onPricing,
    required this.onAbout,
    required this.onContact,
    required this.onPrivacy,
    required this.onTerms,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 760;
    final columns = [
      _FooterColumn('PRODUCT', [('Features', onFeatures), ('Pricing', onPricing)]),
      _FooterColumn('COMPANY', [('About', onAbout), ('Contact', onContact)]),
      _FooterColumn('LEGAL', [('Privacy', onPrivacy), ('Terms', onTerms)]),
    ];

    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: LandingScreen.border))),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: wide ? 2 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onHome,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LogoMark(),
                            SizedBox(width: 10),
                            Text('Applizone', style: TextStyle(color: LandingScreen.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: const Text(
                          'Reliable courier and warehousing software for businesses that move fast.',
                          style: TextStyle(color: LandingScreen.textSecondary, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!wide) const SizedBox(height: 28),
                Expanded(
                  flex: wide ? 3 : 0,
                  child: Wrap(
                    spacing: 40,
                    runSpacing: 24,
                    children: columns,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            const Divider(color: LandingScreen.border, height: 1),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '© ${DateTime.now().year} Applizone Central Jamaica. All rights reserved.',
                  style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
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
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 12),
          for (final l in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: l.$2,
                child: Text(l.$1, style: const TextStyle(color: LandingScreen.textSecondary, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
