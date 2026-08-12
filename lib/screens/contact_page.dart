import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/landing_content.dart';
import '../services/database_service.dart';
import '../theme/public_colors.dart';
import '../widgets/site_chrome.dart';

/// Dedicated "Contact Us" page — was a popup dialog off the top nav; now a
/// real page. Phone/address/email come from the same
/// site_content('landing').contact fields the old dialog and the footer
/// already read, so it stays admin-editable from Site Content.
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
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
    final phone = _content.str('contact', 'phone');
    final address = _content.str('contact', 'address');
    final email = _content.str('contact', 'email');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SiteHeader(content: _content, currentRoute: '/contact'),
            SitePageBanner(
              eyebrow: _content.str('contact', 'bannerEyebrow'),
              title: _content.str('contact', 'bannerTitle'),
              subtitle: _content.str('contact', 'bannerSubtitle'),
            ),
            MaxWidth(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              maxWidth: 860,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 640;
                  final cards = [
                    _ContactCard(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone,
                      actionLabel: 'CALL NOW',
                      onTap: phone.trim().isEmpty
                          ? null
                          : () => html.window.open('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}', '_blank'),
                    ),
                    _ContactCard(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email,
                      actionLabel: 'SEND EMAIL',
                      onTap: email.trim().isEmpty
                          ? null
                          : () => html.window.open('mailto:$email', '_blank'),
                    ),
                    _ContactCard(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: address,
                    ),
                  ];
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final c in cards)
                        SizedBox(width: wide ? (860 - 32) / 3 : double.infinity, child: c),
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
                      'Prefer to just get moving?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PublicColors.navy, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a free account and start shipping today — no need to wait on a reply.',
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

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? actionLabel;
  final VoidCallback? onTap;
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PublicColors.iceGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PublicColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: PublicColors.yellow, shape: BoxShape.circle),
            child: Icon(icon, color: PublicColors.navy, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: PublicColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            value.trim().isEmpty ? 'Not set yet' : value,
            style: const TextStyle(color: PublicColors.navy, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel ?? '',
                    style: const TextStyle(color: PublicColors.secondaryNavy, fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 12, color: PublicColors.secondaryNavy),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
