import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../services/database_service.dart';
import '../theme/public_colors.dart';
import '../widgets/site_chrome.dart';

/// Dedicated "Rates" page — was a popup dialog off the top nav; now a real
/// page. Copy comes from the same site_content('landing').rates.body field
/// the old dialog read, so it stays admin-editable from Site Content.
class RatesPage extends StatefulWidget {
  const RatesPage({super.key});

  @override
  State<RatesPage> createState() => _RatesPageState();
}

class _RatesPageState extends State<RatesPage> {
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

  @override
  Widget build(BuildContext context) {
    final services = _content.list('services', 'items');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SiteHeader(content: _content, currentRoute: '/rates'),
            SitePageBanner(
              eyebrow: _content.str('rates', 'bannerEyebrow'),
              title: _content.str('rates', 'bannerTitle'),
            ),
            MaxWidth(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              maxWidth: 860,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _content.str('rates', 'body'),
                    style: const TextStyle(
                      color: PublicColors.charcoal,
                      fontSize: 17,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (services.isNotEmpty) ...[
                    const Text(
                      'RATES DEPEND ON SERVICE TYPE',
                      style: TextStyle(color: PublicColors.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 16),
                    for (final s in services)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PublicColors.iceGray,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PublicColors.borderGray),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LandingContent.iconFor((s['icon'] as String?) ?? '', Icons.local_shipping_outlined),
                              color: PublicColors.secondaryNavy,
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (s['title'] as String?) ?? '',
                                    style: const TextStyle(color: PublicColors.navy, fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  Text(
                                    (s['description'] as String?) ?? '',
                                    style: const TextStyle(color: PublicColors.charcoalSoft, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'GET A QUOTE',
                              style: TextStyle(color: PublicColors.secondaryNavy, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 22),
                  ],
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
                    child: const Text('CREATE FREE ACCOUNT FOR RATES'),
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
