import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../services/database_service.dart';
import '../theme/public_colors.dart';
import '../widgets/site_chrome.dart';

/// Dedicated "About Us" page — was a popup dialog off the top nav; now a
/// real page like the rest of the site. Copy comes from the same
/// site_content('landing').about.body field the old dialog read, so
/// nothing an admin already customized is lost, and it stays editable from
/// the same Site Content screen (site_content_screen.dart).
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  LandingContent _content = LandingContent.merged(null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final overrides = await DatabaseService().getSiteContent('landing');
      if (!mounted || overrides == null) return;
      setState(() => _content = LandingContent.merged(overrides));
    } catch (_) {
      // Defaults are already showing — a failed override fetch shouldn't
      // block the page from rendering.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SiteHeader(content: _content, currentRoute: '/about'),
            const SitePageBanner(
              eyebrow: 'Our Story',
              title: 'About One Village Shipping & Freight',
            ),
            MaxWidth(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              maxWidth: 860,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _content.str('about', 'body'),
                    style: const TextStyle(
                      color: PublicColors.charcoal,
                      fontSize: 17,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _WhyChooseUsRecap(content: _content),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pushNamed(
                          '/customer-login',
                          arguments: {'signup': true},
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PublicColors.yellow,
                          foregroundColor: PublicColors.navy,
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        child: const Text('GET STARTED'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pushNamed('/services'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PublicColors.navy,
                          side: const BorderSide(color: PublicColors.borderGray, width: 1.4),
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        child: const Text('VIEW OUR SERVICES'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SiteFooter(content: _content),
          ],
        ),
      ),
    );
  }
}

class _WhyChooseUsRecap extends StatelessWidget {
  final LandingContent content;
  const _WhyChooseUsRecap({required this.content});

  @override
  Widget build(BuildContext context) {
    final items = content.list('whyChooseUs', 'items');
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PublicColors.iceGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PublicColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHY SHIP WITH US',
            style: TextStyle(color: PublicColors.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0),
          ),
          const SizedBox(height: 16),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LandingContent.iconFor((item['icon'] as String?) ?? '', Icons.check_circle_outline),
                    color: PublicColors.secondaryNavy,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['title'] as String?) ?? '',
                          style: const TextStyle(color: PublicColors.navy, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          (item['description'] as String?) ?? '',
                          style: const TextStyle(color: PublicColors.charcoalSoft, fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
