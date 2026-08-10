import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../services/database_service.dart';
import '../widgets/adaptive_image.dart';

/// Public marketing home page for One Village Shipping & Freight.
/// All copy, numbers, icons, and images below are the *defaults* — an
/// admin can override any of them from the Site Content editor in the
/// admin dashboard (site_content_screen.dart). This screen always renders
/// defaults immediately (so the page is never blank/loading), then swaps
/// in any saved overrides once fetched.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  static const navy = Color(0xFF071B33);
  static const secondaryNavy = Color(0xFF123A68);
  static const yellow = Color(0xFFFFC400);
  static const gold = Color(0xFFD9A514);
  static const white = Color(0xFFFFFFFF);
  static const iceGray = Color(0xFFF5F7FA);
  static const borderGray = Color(0xFFDCE3EA);
  static const charcoal = Color(0xFF263442);
  static const green = Color(0xFF16845B);
  static const red = Color(0xFFB83A3A);
  static const charcoalSoft = Color(0xFF5B6B7A);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  final _servicesKey = GlobalKey();
  final _ctaKey = GlobalKey();
  LandingContent _content = LandingContent.merged(null);

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final overrides = await DatabaseService().getSiteContent('landing');
      if (!mounted || overrides == null) return;
      setState(() => _content = LandingContent.merged(overrides));
    } catch (_) {
      // Keep showing defaults — the public landing page must never fail
      // to render just because the content-override fetch failed.
    }
  }

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          title,
          style: const TextStyle(color: LandingScreen.navy, fontWeight: FontWeight.w800),
        ),
        content: Text(
          body,
          style: const TextStyle(color: LandingScreen.charcoal, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: LandingScreen.secondaryNavy)),
          ),
        ],
      ),
    );
  }

  void _goToCustomerSignUp() {
    Navigator.of(context).pushNamed('/customer-login', arguments: {'signup': true});
  }

  void _goToCustomerSignIn() {
    Navigator.of(context).pushNamed('/customer-login');
  }

  void _goToPartnerSignUp() {
    Navigator.of(context).pushNamed('/partner-login', arguments: {'signup': true});
  }

  void _goToPartnerSignIn() {
    Navigator.of(context).pushNamed('/partner-login');
  }

  void _showServiceDialog(String title) {
    final match = _content
        .list('services', 'items')
        .where((s) => s['title'] == title)
        .toList();
    final detail = match.isNotEmpty ? (match.first['detail'] as String?) : null;
    _showInfoDialog(title, detail ?? '');
  }

  void _showKnutsfordDialog() {
    _showInfoDialog(
      'Knutsford Express Partnership',
      _content.str('knutsford', 'dialogBody'),
    );
  }

  String _contactBody() {
    final phone = _content.str('contact', 'phone');
    final address = _content.str('contact', 'address');
    final email = _content.str('contact', 'email');
    return 'Phone: $phone\n$address\n$email';
  }

  void _showSocialComingSoon(String platform) {
    _showInfoDialog(
      platform,
      'Our $platform page is launching soon. Check back shortly to follow One Village Shipping & Freight!',
    );
  }

  /// A social icon with a real URL set opens it in a new tab; one left
  /// blank (the default, until an admin fills it in on the Site Content
  /// page) falls back to the "coming soon" popup instead of a dead link.
  void _handleSocialTap(String label, String url) {
    if (url.trim().isEmpty) {
      _showSocialComingSoon(label.isEmpty ? 'Social' : label);
      return;
    }
    html.window.open(url, '_blank');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _Header(
              onHome: _scrollToTop,
              onServices: () => _scrollToKey(_servicesKey),
              onRates: () => _showInfoDialog('Rates', _content.str('rates', 'body')),
              onAbout: () => _showInfoDialog(
                'About One Village Shipping & Freight',
                _content.str('about', 'body'),
              ),
              onContact: () => _showInfoDialog('Contact Us', _contactBody()),
              onGetStarted: () => _scrollToKey(_ctaKey),
              onCustomerSignIn: _goToCustomerSignIn,
              onPartnerSignIn: _goToPartnerSignIn,
            ),
            _Hero(
              content: _content,
              onGetStarted: () => _scrollToKey(_ctaKey),
              onTrackShipment: _goToCustomerSignIn,
              onKnutsfordTap: _showKnutsfordDialog,
            ),
            _Services(key: _servicesKey, content: _content, onLearnMore: _showServiceDialog),
            _WhyChooseUs(content: _content),
            _StatsBar(content: _content),
            _CtaSignup(
              key: _ctaKey,
              content: _content,
              onCourierSignUp: _goToPartnerSignUp,
              onCustomerSignUp: _goToCustomerSignUp,
            ),
            _Footer(
              content: _content,
              onHome: _scrollToTop,
              onServices: () => _scrollToKey(_servicesKey),
              onContact: () => _showInfoDialog('Contact Us', _contactBody()),
              onServiceTap: _showServiceDialog,
              onSocialTap: _handleSocialTap,
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

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onServices;
  final VoidCallback onRates;
  final VoidCallback onAbout;
  final VoidCallback onContact;
  final VoidCallback onGetStarted;
  final VoidCallback onCustomerSignIn;
  final VoidCallback onPartnerSignIn;

  const _Header({
    required this.onHome,
    required this.onServices,
    required this.onRates,
    required this.onAbout,
    required this.onContact,
    required this.onGetStarted,
    required this.onCustomerSignIn,
    required this.onPartnerSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: LandingScreen.borderGray)),
      ),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            InkWell(
              onTap: onHome,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/one_village_logo.png', height: 52),
                ],
              ),
            ),
            const Spacer(),
            if (wide) ...[
              _NavLink('Home', onHome, active: true),
              const SizedBox(width: 26),
              _NavLink('About Us', onAbout),
              const SizedBox(width: 26),
              _NavLink('Services', onServices),
              const SizedBox(width: 26),
              _NavLink('Rates', onRates),
              const SizedBox(width: 26),
              _NavLink('Contact', onContact),
              const SizedBox(width: 26),
            ],
            _SignInMenu(
              onCustomer: onCustomerSignIn,
              onPartner: onPartnerSignIn,
            ),
            const SizedBox(width: 14),
            ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: LandingScreen.yellow,
                foregroundColor: LandingScreen.navy,
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
              color: active ? LandingScreen.gold : LandingScreen.charcoal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          if (active) ...[
            const SizedBox(height: 4),
            Container(width: 18, height: 2, color: LandingScreen.gold),
          ],
        ],
      ),
    );
  }
}

class _SignInMenu extends StatelessWidget {
  final VoidCallback onCustomer;
  final VoidCallback onPartner;
  const _SignInMenu({required this.onCustomer, required this.onPartner});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: LandingScreen.borderGray),
      ),
      offset: const Offset(0, 40),
      onSelected: (v) {
        switch (v) {
          case 'customer':
            onCustomer();
            break;
          case 'partner':
            onPartner();
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
              color: LandingScreen.charcoal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down, size: 18, color: LandingScreen.charcoal),
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
        Icon(icon, size: 18, color: LandingScreen.secondaryNavy),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: LandingScreen.navy, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(subtitle, style: const TextStyle(color: LandingScreen.charcoalSoft, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  final LandingContent content;
  final VoidCallback onGetStarted;
  final VoidCallback onTrackShipment;
  final VoidCallback onKnutsfordTap;
  const _Hero({
    required this.content,
    required this.onGetStarted,
    required this.onTrackShipment,
    required this.onKnutsfordTap,
  });

  static const _features = [
    (Icons.verified_user_outlined, 'SECURE', 'SHIPPING'),
    (Icons.schedule_outlined, 'ON-TIME', 'DELIVERY'),
    (Icons.public, 'GLOBAL', 'NETWORK'),
    (Icons.headset_mic_outlined, '24/7', 'SUPPORT'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 980;
    final copy = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          content.str('hero', 'titleLine1'),
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          content.str('hero', 'titleLine2'),
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: LandingScreen.yellow,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            content.str('hero', 'subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 16, height: 1.5),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 28,
          runSpacing: 16,
          children: _features
              .map(
                (f) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.$1, color: LandingScreen.yellow, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      f.$2,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      f.$3,
                      style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 30),
        Wrap(
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: LandingScreen.yellow,
                foregroundColor: LandingScreen.navy,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(content.str('hero', 'primaryButtonText')),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onTrackShipment,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.4),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              child: Text(content.str('hero', 'secondaryButtonText')),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Text('🇺🇸', style: TextStyle(fontSize: 18)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(content.str('hero', 'originLabel'), style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 9, fontWeight: FontWeight.w700)),
                  Text(content.str('hero', 'originText'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              const Icon(Icons.double_arrow, color: LandingScreen.yellow, size: 16),
              const Text('🇯🇲', style: TextStyle(fontSize: 18)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(content.str('hero', 'destLabel'), style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 9, fontWeight: FontWeight.w700)),
                  Text(content.str('hero', 'destText'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final visual = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 16)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.15,
              child: AdaptiveImage(
                url: content.img('hero', 'backgroundImageUrl'),
                assetPath: 'assets/images/hero_port.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        if (content.data['knutsford']?['enabled'] != false)
          Positioned(
            right: 14,
            bottom: 14,
            child: _KnutsfordCard(content: content, onTap: onKnutsfordTap),
          ),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [LandingScreen.navy, LandingScreen.secondaryNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: copy),
                  const SizedBox(width: 40),
                  Expanded(flex: 5, child: visual),
                ],
              )
            : Column(
                children: [
                  copy,
                  const SizedBox(height: 40),
                  visual,
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

class _KnutsfordCard extends StatelessWidget {
  final LandingContent content;
  final VoidCallback onTap;
  const _KnutsfordCard({required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: content.str('knutsford', 'titlePrefix'),
                  style: const TextStyle(
                    color: Color(0xFFD6006E),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextSpan(
                  text: content.str('knutsford', 'titleSuffix'),
                  style: const TextStyle(
                    color: LandingScreen.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.str('knutsford', 'subtitle'),
            style: const TextStyle(color: LandingScreen.charcoal, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: LandingScreen.yellow, borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Text(
              content.str('knutsford', 'badge'),
              style: const TextStyle(color: LandingScreen.navy, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

class _Services extends StatelessWidget {
  final LandingContent content;
  final ValueChanged<String> onLearnMore;
  const _Services({super.key, required this.content, required this.onLearnMore});

  static const _fallbackAssets = [
    'assets/images/sea_freight.jpg',
    'assets/images/air_freight.jpg',
    'assets/images/warehousing.jpg',
    'assets/images/door_to_door.jpg',
    'assets/images/customs_clearance.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final items = content.list('services', 'items');
    return Container(
      color: Colors.white,
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 88),
        child: Column(
          children: [
            Text(
              content.str('services', 'eyebrow'),
              style: const TextStyle(color: LandingScreen.gold, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              content.str('services', 'heading'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: LandingScreen.navy, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 44),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 1000 ? 5 : (c.maxWidth > 700 ? 3 : (c.maxWidth > 420 ? 2 : 1));
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.72,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _ServiceCard(
                        imageUrl: (items[i]['imageUrl'] as String?) ?? '',
                        fallbackAsset: _fallbackAssets[i % _fallbackAssets.length],
                        icon: LandingContent.iconFor(
                          (items[i]['icon'] as String?) ?? '',
                          Icons.local_shipping_outlined,
                        ),
                        title: (items[i]['title'] as String?) ?? '',
                        desc: (items[i]['description'] as String?) ?? '',
                        onTap: () => onLearnMore((items[i]['title'] as String?) ?? ''),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String imageUrl;
  final String fallbackAsset;
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _ServiceCard({
    required this.imageUrl,
    required this.fallbackAsset,
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LandingScreen.iceGray,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LandingScreen.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: AdaptiveImage(url: imageUrl, assetPath: fallbackAsset, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                bottom: -23,
                left: 16,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: LandingScreen.yellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: LandingScreen.iceGray, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: LandingScreen.navy, size: 22),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: LandingScreen.navy, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: const TextStyle(color: LandingScreen.charcoalSoft, fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('LEARN MORE', style: TextStyle(color: LandingScreen.secondaryNavy, fontSize: 11, fontWeight: FontWeight.w800)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 12, color: LandingScreen.secondaryNavy),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Why choose us
// ---------------------------------------------------------------------------

class _WhyChooseUs extends StatelessWidget {
  final LandingContent content;
  const _WhyChooseUs({required this.content});

  @override
  Widget build(BuildContext context) {
    final items = content.list('whyChooseUs', 'items');
    return Container(
      color: LandingScreen.navy,
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
        child: Column(
          children: [
            Text(
              content.str('whyChooseUs', 'eyebrow'),
              style: const TextStyle(color: LandingScreen.gold, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              content.str('whyChooseUs', 'heading'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
            const SizedBox(height: 44),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900 ? 5 : (c.maxWidth > 560 ? 3 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 28,
                  crossAxisSpacing: 20,
                  childAspectRatio: cols == 1 ? 3.4 : 1.0,
                  children: [
                    for (final w in items)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            LandingContent.iconFor((w['icon'] as String?) ?? '', Icons.star_outline),
                            color: LandingScreen.yellow,
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (w['title'] as String?) ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (w['description'] as String?) ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFA9B8CC), fontSize: 11.5, height: 1.4),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats bar
// ---------------------------------------------------------------------------

class _StatsBar extends StatelessWidget {
  final LandingContent content;
  const _StatsBar({required this.content});

  static const _icons = [
    Icons.directions_boat_filled_outlined,
    Icons.inventory_2_outlined,
    Icons.public,
    Icons.groups_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final stats = content.list('stats', 'items');
    return Container(
      color: LandingScreen.yellow,
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 700 ? 4 : (c.maxWidth > 420 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: cols == 1 ? 4.5 : 2.4,
              children: [
                for (var i = 0; i < stats.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_icons[i % _icons.length], color: LandingScreen.navy, size: 26),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text((stats[i]['value'] as String?) ?? '', style: const TextStyle(color: LandingScreen.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                          Text((stats[i]['label'] as String?) ?? '', style: const TextStyle(color: LandingScreen.navy, fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ready to ship CTA + dual sign up
// ---------------------------------------------------------------------------

class _CtaSignup extends StatelessWidget {
  final LandingContent content;
  final VoidCallback onCourierSignUp;
  final VoidCallback onCustomerSignUp;
  const _CtaSignup({super.key, required this.content, required this.onCourierSignUp, required this.onCustomerSignUp});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final intro = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          content.str('cta', 'eyebrow'),
          style: const TextStyle(color: LandingScreen.gold, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          content.str('cta', 'heading'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: LandingScreen.navy, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        const SizedBox(height: 10),
        Text(
          content.str('cta', 'subtitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: LandingScreen.charcoalSoft, fontSize: 14),
        ),
      ],
    );

    final cards = Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _SignupCard(
          icon: Icons.local_shipping_outlined,
          title: content.str('cta', 'courierCardTitle'),
          desc: content.str('cta', 'courierCardDesc'),
          filled: true,
          onTap: onCourierSignUp,
        ),
        _SignupCard(
          icon: Icons.person_outline,
          title: content.str('cta', 'customerCardTitle'),
          desc: content.str('cta', 'customerCardDesc'),
          filled: false,
          onTap: onCustomerSignUp,
        ),
      ],
    );

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: AdaptiveImage(
          url: content.img('cta', 'imageUrl'),
          assetPath: 'assets/images/forklift_warehouse.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );

    return Container(
      color: LandingScreen.iceGray,
      child: _MaxWidth(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: intro),
                  const SizedBox(width: 28),
                  Expanded(flex: 4, child: cards),
                  const SizedBox(width: 28),
                  Expanded(flex: 3, child: image),
                ],
              )
            : Column(
                children: [
                  intro,
                  const SizedBox(height: 32),
                  cards,
                  const SizedBox(height: 32),
                  image,
                ],
              ),
      ),
    );
  }
}

class _SignupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool filled;
  final VoidCallback onTap;
  const _SignupCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: filled ? LandingScreen.navy : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: filled ? LandingScreen.navy : LandingScreen.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: filled ? LandingScreen.yellow : LandingScreen.navy, size: 28),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: filled ? Colors.white : LandingScreen.navy,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              color: filled ? const Color(0xFFC7D2E0) : LandingScreen.charcoalSoft,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: filled ? LandingScreen.yellow : LandingScreen.navy,
                foregroundColor: filled ? LandingScreen.navy : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SIGN UP NOW'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  final LandingContent content;
  final VoidCallback onHome;
  final VoidCallback onServices;
  final VoidCallback onContact;
  final ValueChanged<String> onServiceTap;
  final void Function(String label, String url) onSocialTap;
  const _Footer({
    required this.content,
    required this.onHome,
    required this.onServices,
    required this.onContact,
    required this.onServiceTap,
    required this.onSocialTap,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Container(
      color: LandingScreen.navy,
      child: Column(
        children: [
          _MaxWidth(
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
                    [('Home', onHome), ('Services', onServices), ('Contact', onContact)],
                  ),
                ),
                if (!wide) const SizedBox(height: 32),
                Expanded(
                  flex: 2,
                  child: _FooterColumn(
                    'SERVICES',
                    [
                      for (final s in content.list('services', 'items'))
                        (
                          (s['title'] as String?) ?? '',
                          () => onServiceTap((s['title'] as String?) ?? ''),
                        ),
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
                              onTap: () => onSocialTap(
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
      ..color = LandingScreen.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    _drawDashedPath(canvas, path, routePaint);

    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = LandingScreen.gold.withValues(alpha: 0.22));
      canvas.drawCircle(p, 3, Paint()..color = LandingScreen.yellow);
      canvas.drawCircle(p, 1.2, Paint()..color = LandingScreen.navy);
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
        Icon(icon, color: LandingScreen.yellow, size: 15),
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
      color: LandingScreen.yellow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: LandingScreen.navy),
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
