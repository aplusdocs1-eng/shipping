import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../services/database_service.dart';
import '../theme/public_colors.dart';
import '../widgets/adaptive_image.dart';
import '../widgets/site_chrome.dart';

/// Dedicated "Services" page — was a scroll-to-section on the landing page
/// (with a "Learn more" popup per card); now a real page listing every
/// service in full detail. Content comes from the same
/// site_content('landing').services fields the homepage section and the
/// old popups read, so it stays admin-editable from Site Content.
class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
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
      // Defaults are already showing.
    }
  }

  static const _fallbackAssets = [
    'assets/images/sea_freight.jpg',
    'assets/images/air_freight.jpg',
    'assets/images/warehousing.jpg',
    'assets/images/door_to_door.jpg',
    'assets/images/customs_clearance.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final items = _content.list('services', 'items');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SiteHeader(content: _content, currentRoute: '/services'),
            SitePageBanner(
              eyebrow: _content.str('services', 'eyebrow'),
              title: _content.str('services', 'heading'),
              subtitle: _content.str('services', 'bannerSubtitle'),
            ),
            MaxWidth(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'Service details coming soon.',
                        style: TextStyle(color: PublicColors.charcoalSoft),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        final cols = c.maxWidth > 900 ? 2 : 1;
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: cols == 2 ? 1.55 : 1.9,
                          children: [
                            for (var i = 0; i < items.length; i++)
                              _ServiceDetailCard(
                                imageUrl: (items[i]['imageUrl'] as String?) ?? '',
                                fallbackAsset: _fallbackAssets[i % _fallbackAssets.length],
                                icon: LandingContent.iconFor(
                                  (items[i]['icon'] as String?) ?? '',
                                  Icons.local_shipping_outlined,
                                ),
                                title: (items[i]['title'] as String?) ?? '',
                                detail: (items[i]['detail'] as String?)?.trim().isNotEmpty == true
                                    ? items[i]['detail'] as String
                                    : (items[i]['description'] as String?) ?? '',
                              ),
                          ],
                        );
                      },
                    ),
            ),
            Container(
              width: double.infinity,
              color: PublicColors.iceGray,
              child: MaxWidth(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  children: [
                    const Text(
                      "Not sure which service fits your shipment?",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PublicColors.navy, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a free account and get a personalized quote in minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PublicColors.charcoalSoft, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
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
                  ],
                ),
              ),
            ),
            SiteFooter(content: _content),
          ],
        ),
      ),
    );
  }
}

class _ServiceDetailCard extends StatelessWidget {
  final String imageUrl;
  final String fallbackAsset;
  final IconData icon;
  final String title;
  final String detail;
  const _ServiceDetailCard({
    required this.imageUrl,
    required this.fallbackAsset,
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PublicColors.iceGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PublicColors.borderGray),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: SizedBox(
              width: 140,
              child: AdaptiveImage(url: imageUrl, assetPath: fallbackAsset, fit: BoxFit.cover),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: PublicColors.secondaryNavy, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: PublicColors.navy, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    detail,
                    style: const TextStyle(color: PublicColors.charcoalSoft, fontSize: 13, height: 1.6),
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
