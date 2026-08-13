import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../services/database_service.dart';
import '../theme/public_colors.dart';
import '../widgets/adaptive_image.dart';
import '../widgets/site_chrome.dart';
import '../widgets/video_backdrop.dart';

/// Public marketing home page for One Village Shipping & Freight.
/// All copy, numbers, icons, and images below are the *defaults* — an
/// admin can override any of them from the Site Content editor in the
/// admin dashboard (site_content_screen.dart). This screen always renders
/// defaults immediately (so the page is never blank/loading), then swaps
/// in any saved overrides once fetched.
///
/// The header/footer nav (SiteHeader/SiteFooter, lib/widgets/site_chrome.dart)
/// is shared with the dedicated About/Services/Rates/Contact pages so the
/// whole public site reads as one continuous site, not this page plus four
/// bolted-on ones.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  // Thin aliases — every other reference to LandingScreen.xxx in this file
  // (there are many) keeps working unchanged; PublicColors is the actual
  // source of truth, shared with site_chrome.dart and the dedicated pages.
  static const navy = PublicColors.navy;
  static const secondaryNavy = PublicColors.secondaryNavy;
  static const yellow = PublicColors.yellow;
  static const gold = PublicColors.gold;
  static const white = PublicColors.white;
  static const iceGray = PublicColors.iceGray;
  static const borderGray = PublicColors.borderGray;
  static const charcoal = PublicColors.charcoal;
  static const green = PublicColors.green;
  static const red = PublicColors.red;
  static const charcoalSoft = PublicColors.charcoalSoft;

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

  void _showKnutsfordDialog() {
    _showInfoDialog(
      'Knutsford Express Partnership',
      _content.str('knutsford', 'dialogBody'),
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
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            SiteHeader(
              content: _content,
              onHome: _scrollToTop,
              onGetStarted: () => _scrollToKey(_ctaKey),
            ),
            _RevealOnScroll(
              scrollController: _scrollController,
              child: _Hero(
                content: _content,
                onGetStarted: () => _scrollToKey(_ctaKey),
                onTrackShipment: _goToCustomerSignIn,
                onKnutsfordTap: _showKnutsfordDialog,
              ),
            ),
            _Services(
              key: _servicesKey,
              content: _content,
              scrollController: _scrollController,
              onLearnMore: () => Navigator.of(context).pushNamed('/services'),
            ),
            _WhyChooseUs(content: _content, scrollController: _scrollController),
            _StatsBar(content: _content, scrollController: _scrollController),
            _RevealOnScroll(
              key: _ctaKey,
              scrollController: _scrollController,
              child: _CtaSignup(
                content: _content,
                onCourierSignUp: _goToPartnerSignUp,
                onCustomerSignUp: _goToCustomerSignUp,
              ),
            ),
            SiteFooter(content: _content),
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
// Scroll animation helpers
// ---------------------------------------------------------------------------

/// Fades and slides its child up once the child has scrolled into (or
/// already starts in) view, then never animates again. Shared across the
/// page's sections and individual cards via the same ScrollController the
/// page's own SingleChildScrollView uses — each instance listens for
/// itself and unsubscribes the moment it fires, so scrolling doesn't
/// trigger a rebuild of anything already revealed.
class _RevealOnScroll extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final Duration delay;
  const _RevealOnScroll({
    required this.child,
    required this.scrollController,
    this.delay = Duration.zero,
    super.key,
  });

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    widget.scrollController.addListener(_checkVisibility);
    // Catches content that's already on screen at first frame (the hero,
    // on a tall viewport) without needing a scroll event to fire first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (_triggered || !mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final position = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    if (position.dy < screenHeight * 0.88) {
      _triggered = true;
      widget.scrollController.removeListener(_checkVisibility);
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Counts up from 0 to the numeric value baked into a stat string like
/// "50,000+" the moment it scrolls into view, then re-appends whatever
/// wasn't a digit or comma ("+", "%", etc.) unchanged.
class _AnimatedStatValue extends StatefulWidget {
  final String value;
  final TextStyle style;
  final ScrollController scrollController;
  const _AnimatedStatValue({
    required this.value,
    required this.style,
    required this.scrollController,
  });

  @override
  State<_AnimatedStatValue> createState() => _AnimatedStatValueState();
}

class _AnimatedStatValueState extends State<_AnimatedStatValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _triggered = false;
  int _target = 0;
  String _suffix = '';

  static final _leadingNumber = RegExp(r'^([\d,]+)(.*)$');

  @override
  void initState() {
    super.initState();
    final match = _leadingNumber.firstMatch(widget.value);
    if (match != null) {
      _target = int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
      _suffix = match.group(2)!;
    } else {
      _suffix = widget.value;
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    widget.scrollController.addListener(_checkVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (_triggered || !mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final position = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    if (position.dy < screenHeight * 0.92) {
      _triggered = true;
      widget.scrollController.removeListener(_checkVisibility);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  static String _withCommas(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_target == 0) return Text(widget.value, style: widget.style);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = (_target * _animation.value).round();
        return Text('${_withCommas(current)}$_suffix', style: widget.style);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

/// Fallback painted immediately behind the hero's VideoBackdrop, and
/// permanently if the video never loads — the same navy gradient the
/// section used before any video background existed.
const _heroVideoFallback = DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [LandingScreen.navy, LandingScreen.secondaryNavy],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
);

// Footage: "Dynamic aerial footage of cargo ship operations in a bustling
// port" by Tom Fisk, via Pexels (videos.pexels.com/video/3840442) — free
// for commercial use, no attribution required under the Pexels License
// (pexels.com/license). Bundled at assets/videos/hero_background.mp4.
const _heroVideoAsset = 'assets/videos/hero_background.mp4';

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
          children: content
              .list('hero', 'features')
              .map(
                (f) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LandingContent.iconFor((f['icon'] as String?) ?? '', Icons.verified_user_outlined),
                      color: LandingScreen.yellow,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (f['line1'] as String?) ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      (f['line2'] as String?) ?? '',
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
              Text(content.str('hero', 'originFlag'), style: const TextStyle(fontSize: 18)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(content.str('hero', 'originLabel'), style: const TextStyle(color: Color(0xFFC7D2E0), fontSize: 9, fontWeight: FontWeight.w700)),
                  Text(content.str('hero', 'originText'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              const Icon(Icons.double_arrow, color: LandingScreen.yellow, size: 16),
              Text(content.str('hero', 'destFlag'), style: const TextStyle(fontSize: 18)),
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

    // Stack, not Container-with-decoration: the video + scrim are
    // Positioned.fill so they never dictate this section's size — the
    // non-positioned _MaxWidth content below still does that, exactly as
    // the plain gradient Container did before. Only non-positioned children
    // participate in a Stack's own sizing, so this is a drop-in swap.
    return Stack(
      children: [
        // Belt-and-suspenders ClipRect: the platform-view <video> inside
        // VideoBackdrop has already been caught once rendering outside its
        // intended bounds (see that widget's own doc comment), so don't
        // rely solely on Stack's own default clip to contain it.
        Positioned.fill(
          child: ClipRect(
            child: VideoBackdrop(
              enabled: wide,
              assetPath: _heroVideoAsset,
              networkUrl: content.str('hero', 'backgroundVideoUrl'),
              fallback: _heroVideoFallback,
            ),
          ),
        ),
        // Scrim over the video so white text stays readable regardless of
        // the footage underneath — darkest on the left where the text
        // column sits, lighter on the right where the image card already
        // has its own opaque background doing that job.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LandingScreen.navy.withValues(alpha: 0.88),
                  LandingScreen.secondaryNavy.withValues(alpha: 0.62),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
        _MaxWidth(
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
      ],
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
  final VoidCallback onLearnMore;
  final ScrollController scrollController;
  const _Services({
    super.key,
    required this.content,
    required this.onLearnMore,
    required this.scrollController,
  });

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
                      _RevealOnScroll(
                        scrollController: scrollController,
                        delay: Duration(milliseconds: 80 * (i % 5)),
                        child: _ServiceCard(
                          imageUrl: (items[i]['imageUrl'] as String?) ?? '',
                          fallbackAsset: _fallbackAssets[i % _fallbackAssets.length],
                          icon: LandingContent.iconFor(
                            (items[i]['icon'] as String?) ?? '',
                            Icons.local_shipping_outlined,
                          ),
                          title: (items[i]['title'] as String?) ?? '',
                          desc: (items[i]['description'] as String?) ?? '',
                          onTap: onLearnMore,
                        ),
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

class _ServiceCard extends StatefulWidget {
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
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -6 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: LandingScreen.navy.withValues(alpha: 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ]
              : const [],
        ),
        child: Material(
      color: LandingScreen.iceGray,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
      onTap: widget.onTap,
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
                  child: AdaptiveImage(url: widget.imageUrl, assetPath: widget.fallbackAsset, fit: BoxFit.cover),
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
                  child: Icon(widget.icon, color: LandingScreen.navy, size: 22),
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
                  widget.title,
                  style: const TextStyle(color: LandingScreen.navy, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.desc,
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
  final ScrollController scrollController;
  const _WhyChooseUs({required this.content, required this.scrollController});

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
                    for (var i = 0; i < items.length; i++)
                      _RevealOnScroll(
                        scrollController: scrollController,
                        delay: Duration(milliseconds: 80 * i),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              LandingContent.iconFor((items[i]['icon'] as String?) ?? '', Icons.star_outline),
                              color: LandingScreen.yellow,
                              size: 28,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (items[i]['title'] as String?) ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (items[i]['description'] as String?) ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFA9B8CC), fontSize: 11.5, height: 1.4),
                            ),
                          ],
                        ),
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
  final ScrollController scrollController;
  const _StatsBar({required this.content, required this.scrollController});

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
                          _AnimatedStatValue(
                            value: (stats[i]['value'] as String?) ?? '',
                            style: const TextStyle(color: LandingScreen.navy, fontSize: 20, fontWeight: FontWeight.w900),
                            scrollController: scrollController,
                          ),
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
  const _CtaSignup({required this.content, required this.onCourierSignUp, required this.onCustomerSignUp});

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

